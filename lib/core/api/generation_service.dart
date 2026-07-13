import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../config/app_config.dart';
import '../models/extraction_result.dart';
import '../models/generation_job.dart';
import '../services/device_info_service.dart';

class GenerationServiceException implements Exception {
  final String message;
  const GenerationServiceException(this.message);
  @override
  String toString() => message;
}

class GenerationService {
  final _dio = ApiClient.instance.dio;

  /// Submits confirmed findings to the backend for visualization.
  ///
  /// [patientName] is accepted for call-site compatibility but is deliberately
  /// NOT transmitted: it is a direct HIPAA identifier, the image model cannot
  /// use it, and the name is stamped on-device after generation instead.
  Future<String> submitGeneration(List<Finding> findings, {String patientName = ''}) async {
    final payload = {
      'findings': findings
          .map((f) => {
                'id': f.id,
                'body_region': f.bodyRegion,
                'finding': f.text,
              })
          .toList(),
      'device_meta': DeviceInfoService.collect(),
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

  /// Submits a free-form text/voice description directly for visualization.
  ///
  /// [patientName] is accepted for call-site compatibility but is deliberately
  /// NOT transmitted — see [submitGeneration].
  Future<String> submitDirectPrompt(String prompt, {String patientName = ''}) async {
    final payload = {
      'prompt': prompt,
      'device_meta': DeviceInfoService.collect(),
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
