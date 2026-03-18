enum OcrJobStatus { pending, processing, completed, failed }

class OcrJob {
  final String jobId;
  final OcrJobStatus status;
  final Map<String, dynamic>? result;
  final String? error;
  final int tokensIn;
  final int tokensOut;

  const OcrJob({
    required this.jobId,
    required this.status,
    this.result,
    this.error,
    this.tokensIn = 0,
    this.tokensOut = 0,
  });

  factory OcrJob.fromJson(Map<String, dynamic> json) {
    return OcrJob(
      jobId: json['job_id'] as String,
      status: _parseStatus(json['status'] as String? ?? ''),
      result: json['result'] as Map<String, dynamic>?,
      error: json['error'] as String?,
      tokensIn: (json['tokens_in'] as num?)?.toInt() ?? 0,
      tokensOut: (json['tokens_out'] as num?)?.toInt() ?? 0,
    );
  }

  static OcrJobStatus _parseStatus(String s) {
    switch (s) {
      case 'processing':
        return OcrJobStatus.processing;
      case 'completed':
        return OcrJobStatus.completed;
      case 'failed':
        return OcrJobStatus.failed;
      default:
        return OcrJobStatus.pending;
    }
  }

  bool get isDone =>
      status == OcrJobStatus.completed || status == OcrJobStatus.failed;
}
