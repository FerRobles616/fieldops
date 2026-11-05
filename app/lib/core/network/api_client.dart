import 'package:dio/dio.dart';
import 'package:fieldops_app/core/storage/token_storage.dart';

class ApiClient {
  ApiClient({required String baseUrl, required this.tokenStorage})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = await tokenStorage.readSession();
          final token = session?.token;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final TokenStorage tokenStorage;
}
