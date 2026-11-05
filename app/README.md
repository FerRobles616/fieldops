# FieldOps app

Flutter client for FieldOps. See the [root README](../README.md) for setup, demo credentials, and architecture.

## Run

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

For the Android emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Quality

```bash
flutter analyze
flutter test
```
