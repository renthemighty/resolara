import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

const _pdfTextChannel = MethodChannel('resolara.ai/pdf_text');

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
    // ── Strategy 1: native PDFKit text extraction (iOS) ───────────────────
    // Instant and perfect for text-based PDFs (hospital-generated reports).
    try {
      final native = await _pdfTextChannel.invokeMethod<String>(
        'extractText',
        {'path': pdfFile.path},
      );
      if (native != null && native.trim().isNotEmpty) {
        return native;
      }
    } catch (_) {
      // Channel not available (Android / old build) — fall through to OCR.
    }

    // ── Strategy 2: render pages + ML Kit OCR ─────────────────────────────
    // Fallback for scanned PDFs where native extraction returns nothing.
    final document = await PdfDocument.openFile(pdfFile.path);
    final pageCount = document.pagesCount;
    final buffer = StringBuffer();
    final tempDir = await getTemporaryDirectory();

    try {
      for (int i = 1; i <= pageCount; i++) {
        onPageProgress?.call(i, pageCount);

        final page = await document.getPage(i);
        // Render at ~300 DPI equivalent (PDF points are at 72 DPI).
        // Cap at 2480px wide to keep memory reasonable on older devices.
        final scale = (2480 / page.width).clamp(3.0, 6.0);
        final pageImage = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: PdfPageImageFormat.png,
          backgroundColor: '#ffffff',
          forPrint: true,
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
