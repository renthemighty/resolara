import 'dart:io';

enum CaptureSource { camera, photos, import }

class CapturedReport {
  final File file;
  final DateTime capturedAt;
  final CaptureSource source;

  const CapturedReport({
    required this.file,
    required this.capturedAt,
    required this.source,
  });

  bool get isPdf => file.path.toLowerCase().endsWith('.pdf');
}

class CapturedBatch {
  final List<CapturedReport> reports;
  const CapturedBatch(this.reports);
  int get length => reports.length;
  bool get isSingle => reports.length == 1;
  CapturedReport get first => reports.first;
}
