import 'package:dio/dio.dart';
import '../auth/auth_service.dart';
import '../config/app_config.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  final AuthService _auth = AuthService();

  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _auth.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  static ApiClient get instance => _instance ??= ApiClient._();

  Dio get dio => _dio;
}
