import 'dart:html' as html;

import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

class ClinicApiClient {
  ClinicApiClient._(this._dio);

  static ClinicApiClient? _instance;

  static ClinicApiClient get instance {
    _instance ??= ClinicApiClient._(_build());
    return _instance!;
  }

  final Dio _dio;
  Dio get raw => _dio;

  static const _storageKey = 'resolara_token';
  static String? _token;

  static void setToken(String? token, {bool persist = false}) {
    _token = token;
    if (persist && token != null) {
      html.window.localStorage[_storageKey] = token;
    } else if (token == null) {
      html.window.localStorage.remove(_storageKey);
    }
  }

  static String? get token {
    _token ??= html.window.localStorage[_storageKey];
    return _token;
  }

  static void clearToken() {
    _token = null;
    html.window.localStorage.remove(_storageKey);
  }

  static Dio _build() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        // Do NOT set connectTimeout or sendTimeout on web — they cause Dio's
        // BrowserHttpClientAdapter to register xhr.upload event listeners,
        // which forces CORS preflight on every request with a body.
        // receiveTimeout uses a Dart Timer and doesn't affect CORS.
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // withCredentials must be false when server uses Access-Control-Allow-Origin: *
    // (wildcard + credentials is illegal per CORS spec).
    dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: false);

    dio.interceptors.add(_AuthInterceptor());
    return dio;
  }

  static const _baseUrl = String.fromEnvironment(
    'RESOLARA_API_BASE',
    defaultValue: 'https://resolara.ai/api',
  );
}

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
