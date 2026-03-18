import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

class LocalOcrException implements Exception {
  final String message;
  const LocalOcrException(this.message);
  @override
  String toString() => message;
}

class LocalOcrService {
  /// Extract text from an image file using on-device ML Kit OCR.
  Future<String> extractTextFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(inputImage);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  /// Render each PDF page to an image on-device, then OCR each page.
  /// Returns concatenated text from all pages.
  Future<String> extractTextFromPdf(
    File pdfFile, {
    void Function(int page, int total)? onPageProgress,
  }) async {
    final document = await PdfDocument.openFile(pdfFile.path);
    final pageCount = document.pagesCount;
    final buffer = StringBuffer();
    final tempDir = await getTemporaryDirectory();

    try {
      for (int i = 1; i <= pageCount; i++) {
        onPageProgress?.call(i, pageCount);

        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        await page.close();

        if (pageImage == null) continue;

        final tempFile = File('${tempDir.path}/resolara_ocr_page_$i.png');
        await tempFile.writeAsBytes(pageImage.bytes);

        try {
          final pageText = await extractTextFromImage(tempFile);
          if (pageText.isNotEmpty) {
            if (buffer.isNotEmpty) buffer.writeln();
            buffer.write(pageText);
          }
        } finally {
          await tempFile.delete();
        }
      }
    } finally {
      await document.close();
    }

    return buffer.toString();
  }
}
