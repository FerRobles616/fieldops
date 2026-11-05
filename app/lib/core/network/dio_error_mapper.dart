import 'package:dio/dio.dart';
import 'package:fieldops_app/core/network/api_exception.dart';

ApiException mapDioException(
  DioException error, {
  String? unauthorizedMessage,
}) {
  final statusCode = error.response?.statusCode;

  if (statusCode == 401) {
    return ApiException(
      unauthorizedMessage ?? 'Your session expired. Please sign in again.',
      statusCode: 401,
    );
  }
  if (statusCode == 403) {
    return const ApiException(
      "You don't have permission to do that.",
      statusCode: 403,
    );
  }
  if (statusCode == 404) {
    return const ApiException('Not found.', statusCode: 404);
  }
  if (statusCode == 409) {
    return const ApiException(
      'This record changed on the server. Refresh and try again.',
      statusCode: 409,
    );
  }
  if (statusCode == 422) {
    return const ApiException(
      'Check the submitted data and try again.',
      statusCode: 422,
    );
  }
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      (error.type == DioExceptionType.unknown && error.response == null)) {
    return const ApiException(
      'Could not reach the server. Is the API running?',
      isNetworkError: true,
    );
  }

  final data = error.response?.data;
  if (data is Map<String, dynamic> && data['detail'] is String) {
    return ApiException(data['detail'] as String, statusCode: statusCode);
  }
  return ApiException(
    'Request failed. Please try again.',
    statusCode: statusCode,
  );
}
