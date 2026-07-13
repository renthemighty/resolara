import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../config/app_config.dart';
import '../models/ocr_job.dart';
import '../services/device_info_service.dart';

class OcrServiceException implements Exception {
  final String message;
  const OcrServiceException(this.message);
  @override
  String toString() => message;
}

class OcrService {
  final _dio = ApiClient.instance.dio;

  /// Submits cleaned report text to the server and returns a job ID.
  /// Raw images and PDFs are never uploaded — OCR and redaction run on-device.
  Future<String> submitJob({
    required String cleanedReportText,
    required String redactionSummary,
    required String documentType,
    required int pageCount,
  }) async {
    final response = await _dio.post(
      '/v1/jobs',
      data: {
        'cleaned_report_text': cleanedReportText,
        'redaction_summary': redactionSummary,
        'document_type': documentType,
        'page_count': pageCount,
        'client_timestamp': DateTime.now().toIso8601String(),
        'app_version': AppConfig.appVersion,
        'device_meta': DeviceInfoService.collect(),
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const OcrServiceException('Submission failed. Please try again.');
    }

    final jobId = response.data['job_id'] as String?;
    if (jobId == null) {
      throw const OcrServiceException('Invalid response from server.');
    }
    return jobId;
  }

  /// Polls the job until complete, failed, or [maxAttempts] is reached.
  ///
  /// The first poll fires almost immediately (a short delay, not the full
  /// [AppConfig.jobPollInterval]) so the server claims the job and starts
  /// processing right away instead of sitting idle for 3s. Subsequent polls
  /// fall back to the normal interval.
  Stream<OcrJob> pollJob(String jobId) async* {
    for (int attempt = 0; attempt < AppConfig.jobPollMaxAttempts; attempt++) {
      await Future.delayed(attempt == 0
          ? const Duration(milliseconds: 300)
          : AppConfig.jobPollInterval);

      final Response response;
      try {
        response = await _dio.get('/v1/jobs/$jobId');
      } on DioException {
        continue;
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
