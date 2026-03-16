enum GenerationJobStatus { pending, processing, completed, failed }

class GenerationJob {
  final String jobId;
  final GenerationJobStatus status;
  final String? imageUrl;
  final String? localPath;
  final String? error;

  const GenerationJob({
    required this.jobId,
    required this.status,
    this.imageUrl,
    this.localPath,
    this.error,
  });

  factory GenerationJob.fromJson(Map<String, dynamic> json) {
    return GenerationJob(
      jobId: json['job_id'] as String,
      status: _parseStatus(json['status'] as String? ?? ''),
      imageUrl: json['image_url'] as String?,
      error: json['error'] as String?,
    );
  }

  static GenerationJobStatus _parseStatus(String s) {
    switch (s) {
      case 'processing':
        return GenerationJobStatus.processing;
      case 'completed':
        return GenerationJobStatus.completed;
      case 'failed':
        return GenerationJobStatus.failed;
      default:
        return GenerationJobStatus.pending;
    }
  }

  bool get isDone =>
      status == GenerationJobStatus.completed ||
      status == GenerationJobStatus.failed;
}
