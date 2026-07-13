// dart:js_interop wrapper around the tesseract.js UMD bundle loaded via a
// <script> tag in web/index.html.
//
// OCR runs entirely inside the browser tab — the raw image bytes passed to
// TesseractOcrService.recognizeBytes never leave the practitioner's
// machine and are never sent to the Resolara server or to Claude. Only the
// recognized TEXT is returned to the caller, which is what the upload
// screen then POSTs to the server. This mirrors the mobile app's
// on-device ML Kit OCR for the web surface (see CLAUDE.md: "OCR must run
// on-device").

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('Tesseract.createWorker')
external JSPromise<_TesseractWorker> _createWorker(JSString lang);

extension type _TesseractWorker(JSObject _) implements JSObject {
  external JSPromise<_RecognizeResult> recognize(JSString image);
  external JSPromise<JSAny?> terminate();
}

extension type _RecognizeResult(JSObject _) implements JSObject {
  external _RecognizeData get data;
}

extension type _RecognizeData(JSObject _) implements JSObject {
  external JSString get text;
}

class TesseractOcrService {
  TesseractOcrService._();

  /// True once the tesseract.js UMD script (loaded in `web/index.html`) has
  /// attached `window.Tesseract`. If the CDN script failed to load (offline,
  /// blocked by a network policy, etc.) this is false and callers must show
  /// a clear error — never silently fall back to uploading the raw image.
  static bool get isAvailable => globalContext.has('Tesseract');

  /// Runs OCR on raw image bytes entirely in-browser and returns the
  /// recognized text. [bytes] never leaves this tab: it is base64-encoded
  /// into a `data:` URL and handed directly to a local tesseract.js worker,
  /// which does its own recognition in a Web Worker inside the same origin.
  ///
  /// Throws [StateError] if tesseract.js did not load, and rethrows any
  /// interop failure — callers must surface these clearly and must NOT fall
  /// back to uploading the raw image bytes as a workaround.
  static Future<String> recognizeBytes(
    Uint8List bytes, {
    String mime = 'image/png',
  }) async {
    if (!isAvailable) {
      throw StateError(
        'In-browser OCR engine (tesseract.js) failed to load. '
        'Check your internet connection and reload the page.',
      );
    }

    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    final worker = await _createWorker('eng'.toJS).toDart;
    try {
      final result = await worker.recognize(dataUrl.toJS).toDart;
      return result.data.text.toDart;
    } finally {
      // Best-effort cleanup — a terminate() failure must not mask a
      // successful OCR result already captured above.
      try {
        await worker.terminate().toDart;
      } catch (_) {
        // ignore
      }
    }
  }
}
