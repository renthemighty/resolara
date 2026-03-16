import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../config/app_config.dart';
import '../models/extraction_result.dart';
import '../models/generation_job.dart';

class GenerationServiceException implements Exception {
  final String message;
  const GenerationServiceException(this.message);
  @override
  String toString() => message;
}

class GenerationService {
  final _dio = ApiClient.instance.dio;

  /// Submits confirmed findings to the backend for visualization.
  /// The backend handles prompt construction and AI provider routing
  /// (Claude or OpenAI) — the mobile never needs to know which is used.
  Future<String> submitGeneration(List<Finding> findings) async {
    final payload = {
      'findings': findings
          .map((f) => {
                'id': f.id,
                'body_region': f.bodyRegion,
                'finding': f.text,
              })
          .toList(),
    };

    final response = await _dio.post('/v1/visualizations', data: payload);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const GenerationServiceException(
          'Failed to start visualization. Please try again.');
    }

    final jobId = response.data['job_id'] as String?;
    if (jobId == null) {
      throw const GenerationServiceException('Invalid response from server.');
    }
    return jobId;
  }

  /// Polls until the visualization is ready, failed, or times out.
  Stream<GenerationJob> pollJob(String jobId) async* {
    for (int attempt = 0; attempt < AppConfig.jobPollMaxAttempts; attempt++) {
      await Future.delayed(AppConfig.jobPollInterval);

      final Response response;
      try {
        response = await _dio.get('/v1/visualizations/$jobId');
      } on DioException {
        continue;
      }

      final job =
          GenerationJob.fromJson(response.data as Map<String, dynamic>);
      yield job;

      if (job.isDone) return;
    }

    throw const GenerationServiceException(
        'Visualization is taking longer than expected. Please try again.');
  }
}
