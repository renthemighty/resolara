import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

/// Dio client for the clinic web app.
///
/// Key configuration:
///   - `withCredentials: true`: browser sends `resolara_session` +
///     `resolara_csrf` cookies (scoped to `.resolara.ai`) on every request
///     to the cross-origin `resolara.ai/api` backend.
///   - Before each mutating request (POST/PUT/DELETE/PATCH), an interceptor
///     reads the `resolara_csrf` cookie via `document.cookie` and sets the
///     `X-CSRF-Token` header the backend checks via `hash_equals`.
///   - Fixed base URL — the PHP backend lives on a different origin than
///     the Flutter Web build, so a relative path would fail.
class ClinicApiClient {
  ClinicApiClient._(this._dio);

  static ClinicApiClient? _instance;

  static ClinicApiClient get instance {
    _instance ??= ClinicApiClient._(_build());
    return _instance!;
  }

  final Dio _dio;

  Dio get raw => _dio;

  static Dio _build() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        // Do not throw on non-2xx — handlers inspect status + body
        validateStatus: (status) => status != null && status < 500,
        extra: {'withCredentials': true},
      ),
    );
    dio.interceptors.add(_CsrfInterceptor());
    return dio;
  }

  /// Backend base URL. In dev, set RESOLARA_API_BASE at build time via:
  ///   flutter run -d chrome --dart-define=RESOLARA_API_BASE=https://resolara.ai/api
  static const _baseUrl = String.fromEnvironment(
    'RESOLARA_API_BASE',
    defaultValue: 'https://resolara.ai/api',
  );
}

/// Reads the resolara_csrf cookie and sets X-CSRF-Token on mutating requests.
///
/// In dev against the real backend (different subdomain), browsers only
/// expose cookies that were Set-Cookie'd with Domain=.resolara.ai — which
/// the PHP SessionService does. Non-web platforms never instantiate this
/// client, so dart:html access is safe.
class _CsrfInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final method = options.method.toUpperCase();
    if (method == 'POST' || method == 'PUT' || method == 'DELETE' || method == 'PATCH') {
      if (kIsWeb) {
        final csrf = _readCookie('resolara_csrf');
        if (csrf != null && csrf.isNotEmpty) {
          options.headers['X-CSRF-Token'] = csrf;
        }
      }
    }
    handler.next(options);
  }

  static String? _readCookie(String name) {
    final raw = web.document.cookie;
    for (final entry in raw.split(';')) {
      final eq = entry.indexOf('=');
      if (eq < 0) continue;
      final key = entry.substring(0, eq).trim();
      if (key == name) {
        return Uri.decodeComponent(entry.substring(eq + 1).trim());
      }
    }
    return null;
  }
}
