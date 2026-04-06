import 'package:dio/dio.dart';

/// Dio client for the clinic web app.
///
/// Uses Authorization: Bearer token (stored in memory after login).
/// The ADC adds wildcard CORS globally, which is incompatible with
/// cookie-based credentials. Bearer tokens work fine with wildcard CORS.
class ClinicApiClient {
  ClinicApiClient._(this._dio);

  static ClinicApiClient? _instance;

  static ClinicApiClient get instance {
    _instance ??= ClinicApiClient._(_build());
    return _instance!;
  }

  final Dio _dio;

  Dio get raw => _dio;

  /// Current bearer token, set after successful login.
  static String? _token;

  static void setToken(String? token) => _token = token;
  static String? get token => _token;

  static Dio _build() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    dio.interceptors.add(_AuthInterceptor());
    return dio;
  }

  static const _baseUrl = String.fromEnvironment(
    'RESOLARA_API_BASE',
    defaultValue: 'https://resolara.ai/api',
  );
}

/// Adds Authorization: Bearer header when a token is stored.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ClinicApiClient.token;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
