import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppConfig {
  AppConfig._();

  static const String appName = 'Resolara';
  // Kept in sync with pubspec.yaml manually — see Primer.md version bump rule.
  static const String appVersion = '1.4.1';

  // Compile-time override: flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8099
  static const String _compiledApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://resolara.ai/api',
  );

  // Runtime override file: <documents>/resolara_server.txt
  // Contains a single line with the base URL, e.g. http://127.0.0.1:8099
  // Delete the file to revert to production. Useful when migrating servers.
  static String _runtimeApiBaseUrl = _compiledApiBaseUrl;
  static bool _urlLoaded = false;

  static Future<void> loadServerOverride() async {
    if (_urlLoaded) return;
    _urlLoaded = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/resolara_server.txt');
      if (await file.exists()) {
        final override = (await file.readAsString()).trim();
        if (override.isNotEmpty) {
          _runtimeApiBaseUrl = override;
        }
      }
    } catch (_) {}
  }

  static String get apiBaseUrl => _runtimeApiBaseUrl;

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 180);

  // Polling
  static const Duration jobPollInterval = Duration(seconds: 3);
  static const int jobPollMaxAttempts = 40;
}
