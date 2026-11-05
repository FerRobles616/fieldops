import 'package:dio/dio.dart';
import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/core/network/dio_error_mapper.dart';
import 'package:fieldops_app/features/auth/domain/auth_models.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException('The server returned an empty response.');
      }
      return AuthSession.fromLoginResponse(data);
    } on DioException catch (error) {
      throw mapDioException(
        error,
        unauthorizedMessage: 'Invalid email or password.',
      );
    }
  }
}
