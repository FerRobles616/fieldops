class AppConfig {
  const AppConfig._();

  /// Override at build time:
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
