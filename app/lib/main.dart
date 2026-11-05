import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fieldops_app/app.dart';
import 'package:fieldops_app/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(_warmUpApi());
  runApp(const ProviderScope(child: FieldOpsApp()));
}

/// Render's free tier sleeps after inactivity. Start the wake-up as soon as
/// the app loads so the login request is less likely to wait for a cold start.
Future<void> _warmUpApi() async {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  try {
    await dio.get<void>('/health');
  } catch (_) {
    // The login screen will surface connectivity errors.
  } finally {
    dio.close();
  }
}
