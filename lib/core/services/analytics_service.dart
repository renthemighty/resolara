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

  static Future<void> generationCompleted({String? bodyRegion}) =>
      _log('generation_completed', {if (bodyRegion != null) 'body_region': bodyRegion});

  static Future<void> generationFailed({String? reason}) =>
      _log('generation_failed', {if (reason != null) 'reason': reason});

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

  static void recordError(Object error, StackTrace? stack, {String? reason}) {
    if (!_ready) return;
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, reason: reason);
    } catch (_) {}
  }

  static void log(String message) {
    if (!_ready) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }
}
