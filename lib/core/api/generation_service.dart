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
  /// [patientName] is accepted for call-site compatibility (it is used
  /// on-device to stamp the approved image) but is deliberately NOT sent
  /// to the server: the generation endpoint forwards findings to a
  /// third-party AI vendor with no BAA, and a patient name has no use in
  /// an image-generation prompt. Do not add it back to this payload.
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
  /// [patientName] is accepted for call-site compatibility (it is used
  /// on-device to stamp the approved image) but is deliberately NOT sent
  /// to the server — see the note on [submitGeneration] above.
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
  ///
  /// The first poll fires almost immediately (a short delay, not the full
  /// [AppConfig.jobPollInterval]) so the server claims the job and starts
  /// calling OpenAI right away instead of sitting idle for 3s. Subsequent
  /// polls fall back to the normal interval.
  Stream<GenerationJob> pollJob(String jobId) async* {
    for (int attempt = 0; attempt < AppConfig.jobPollMaxAttempts; attempt++) {
      await Future.delayed(attempt == 0
          ? const Duration(milliseconds: 300)
          : AppConfig.jobPollInterval);

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
