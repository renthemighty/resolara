import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

class AppConfig {
  final Map<String, String> bodyRegions;
  final int retentionDays;
  final int maxFindings;
  final String supportEmail;
  final String? appMessage;
  final bool maintenanceMode;

  const AppConfig({
    required this.bodyRegions,
    required this.retentionDays,
    required this.maxFindings,
    required this.supportEmail,
    this.appMessage,
    required this.maintenanceMode,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final regions = (json['body_regions'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, v.toString()));
    return AppConfig(
      bodyRegions: regions,
      retentionDays: json['retention_days'] as int? ?? 90,
      maxFindings: json['max_findings'] as int? ?? 20,
      supportEmail: json['support_email'] as String? ?? 'support@resolara.ai',
      appMessage: json['app_message'] as String?,
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
    );
  }

  static AppConfig get fallback => const AppConfig(
        bodyRegions: {
          'lumbar_spine': 'Lumbar Spine',
          'cervical_spine': 'Cervical Spine',
          'thoracic_spine': 'Thoracic Spine',
          'knee_left': 'Left Knee',
          'knee_right': 'Right Knee',
          'shoulder_left': 'Left Shoulder',
          'shoulder_right': 'Right Shoulder',
        },
        retentionDays: 90,
        maxFindings: 20,
        supportEmail: 'support@resolara.ai',
        maintenanceMode: false,
      );
}

class ConfigService {
  static Future<AppConfig> fetch() async {
    try {
      final dio = ApiClient.instance;
      final response = await dio.get('/v1/config');
      return AppConfig.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return AppConfig.fallback;
    }
  }
}

// Provider — fetched once at startup, cached for the session
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  return ConfigService.fetch();
});
