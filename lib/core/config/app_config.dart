class AppConfig {
  AppConfig._();

  static const String appName = 'Resolara';
  static const String appVersion = '1.0.0';

  // Backend API base URL — set per environment
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.resolara.ai',
  );

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);

  // Polling
  static const Duration jobPollInterval = Duration(seconds: 3);
  static const int jobPollMaxAttempts = 40;
}
