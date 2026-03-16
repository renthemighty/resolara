import 'dart:io';

enum CaptureSource { camera, import }

class CapturedReport {
  final File file;
  final DateTime capturedAt;
  final CaptureSource source;

  const CapturedReport({
    required this.file,
    required this.capturedAt,
    required this.source,
  });
}
