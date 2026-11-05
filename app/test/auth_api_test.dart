import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/features/auth/data/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(ResponseBody Function(RequestOptions options) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  dio.httpClientAdapter = _FakeAdapter(handler);
  return dio;
}

ResponseBody _json(Object body, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  test('parses a successful login response', () async {
    final api = AuthApi(
      _dioReturning(
        (options) => _json({
          'access_token': 'token-123',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': 'user-1',
            'email': 'tech@fieldops.dev',
            'name': 'Tech Demo',
            'role': 'technician',
          },
        }, 200),
      ),
    );

    final session = await api.login(
      email: 'tech@fieldops.dev',
      password: 'tech1234',
    );

    expect(session.token, 'token-123');
    expect(session.user.email, 'tech@fieldops.dev');
    expect(session.isExpired, isFalse);
  });

  test('maps a 401 response to a friendly message', () async {
    final api = AuthApi(
      _dioReturning(
        (options) => _json({'detail': 'Invalid email or password'}, 401),
      ),
    );

    expect(
      () => api.login(email: 'tech@fieldops.dev', password: 'wrong'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having(
              (error) => error.message,
              'message',
              'Invalid email or password.',
            ),
      ),
    );
  });
}
