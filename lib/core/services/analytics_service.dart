import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class Analytics {
  Analytics._();

  static bool get _ready {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (!_ready) return;
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  static Future<void> practitionerActivated() => _log('practitioner_activated');
  static Future<void> patientSignedUp()        => _log('patient_signed_up');
  static Future<void> practitionerLoggedOut()  => _log('practitioner_logged_out');
  static Future<void> patientLoggedOut()       => _log('patient_logged_out');
  static Future<void> appReset()               => _log('app_reset');

  // ── Capture flow ─────────────────────────────────────────────────────────

  /// source: 'camera' | 'library' | 'file' | 'describe'
  static Future<void> captureStarted(String source) =>
      _log('capture_started', {'source': source});

  static Future<void> ocrCompleted({required int pageCount, required int charCount}) =>
      _log('ocr_completed', {'page_count': pageCount, 'char_count': charCount});

  static Future<void> findingsReviewed({required int findingCount}) =>
      _log('findings_reviewed', {'finding_count': findingCount});

  static Future<void> generationRequested() => _log('generation_requested');

  // No clinical value (e.g. body region) may ever be attached to this event.
  static Future<void> generationCompleted() => _log('generation_completed');

  // `reason` is intentionally NOT forwarded to Analytics — callers pass
  // server-derived / job-error text (see GenerationJob.error) which can
  // contain report or finding content. Only the coarse failure event fires;
  // no freeform string ever reaches Firebase. Keep the parameter for call-site
  // compatibility but ignore its value at this boundary.
  static Future<void> generationFailed({String? reason}) => _log('generation_failed');

  static Future<void> sessionSaved() => _log('session_saved');

  // ── Sessions ─────────────────────────────────────────────────────────────

  static Future<void> sessionOpened()   => _log('session_opened');
  static Future<void> sessionDeleted()  => _log('session_deleted');
  static Future<void> sessionsCleared() => _log('sessions_cleared');
  static Future<void> shareCreated()    => _log('share_created');
  static Future<void> imageShared()     => _log('image_shared');

  // ── Patient ──────────────────────────────────────────────────────────────

  static Future<void> qrScanStarted()      => _log('qr_scan_started');
  static Future<void> qrScanned()          => _log('qr_scanned');
  static Future<void> shareCodeSubmitted() => _log('share_code_submitted');
  static Future<void> resultsLoaded()      => _log('results_loaded');

  /// tab: 'image' | 'knowledge' | 'exercises' | 'medications'
  static Future<void> resultsTabViewed(String tab) =>
      _log('results_tab_viewed', {'tab': tab});

  // ── Settings ─────────────────────────────────────────────────────────────

  /// mode: 'light' | 'dark' | 'system'
  static Future<void> themeChanged(String mode) =>
      _log('theme_changed', {'mode': mode});

  static Future<void> historyOpened() => _log('history_opened');

  // ── Crashlytics helpers ──────────────────────────────────────────────────
  //
  // No exception object may reach Crashlytics with its interpolated message
  // intact — server responses, report/finding text, and prompts can end up
  // inside `Exception.toString()` (e.g. services that build messages like
  // 'Could not load explanations: $e' from a DioException). Only the
  // exception's runtime TYPE and a static description are shipped; the
  // original object never leaves the device.

  /// Wraps [error] so only its type name reaches Crashlytics — never its
  /// interpolated message, which may embed server responses, report text,
  /// findings, or prompts.
  static Object sanitizeForCrashlytics(Object error) => _SanitizedError(error);

  static void recordError(Object error, StackTrace? stack, {String? reason}) {
    if (!_ready) return;
    try {
      FirebaseCrashlytics.instance.recordError(
        sanitizeForCrashlytics(error),
        stack,
        reason: reason,
      );
    } catch (_) {}
  }

  static void log(String message) {
    if (!_ready) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }
}

/// Exception wrapper that preserves only the original error's runtime type,
/// never its message. Used at every Crashlytics boundary so a DioException
/// (or any exception built with server-response / report-derived text) can
/// never ship clinical content to Firebase.
class _SanitizedError implements Exception {
  _SanitizedError(Object error) : typeName = error.runtimeType.toString();

  final String typeName;

  @override
  String toString() => 'SanitizedError(type: $typeName)';
}
