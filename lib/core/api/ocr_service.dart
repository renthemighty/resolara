import 'dart:io';
import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../config/app_config.dart';
import '../models/ocr_job.dart';

class OcrServiceException implements Exception {
  final String message;
  const OcrServiceException(this.message);
  @override
  String toString() => message;
}

class OcrService {
  final _dio = ApiClient.instance.dio;

  /// Uploads the image and returns a job ID.
  Future<String> submitJob(
    File imageFile, {
    void Function(double progress)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'report': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'report.jpg',
      ),
    });

    final response = await _dio.post(
      '/v1/jobs',
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const OcrServiceException('Upload failed. Please try again.');
    }

    final jobId = response.data['job_id'] as String?;
    if (jobId == null) {
      throw const OcrServiceException('Invalid response from server.');
    }
    return jobId;
  }

  /// Polls the job until complete, failed, or [maxAttempts] is reached.
  /// Yields each [OcrJob] status update.
  Stream<OcrJob> pollJob(String jobId) async* {
    for (int attempt = 0; attempt < AppConfig.jobPollMaxAttempts; attempt++) {
      await Future.delayed(AppConfig.jobPollInterval);

      final Response response;
      try {
        response = await _dio.get('/v1/jobs/$jobId');
      } on DioException {
        continue; // transient network error — keep polling
      }

      final job = OcrJob.fromJson(response.data as Map<String, dynamic>);
      yield job;

      if (job.isDone) return;
    }

    throw const OcrServiceException(
      'Processing is taking longer than expected. Please try again.',
    );
  }
}
