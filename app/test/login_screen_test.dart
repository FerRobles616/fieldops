import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/core/theme/app_theme.dart';
import 'package:fieldops_app/features/auth/application/auth_controller.dart';
import 'package:fieldops_app/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

Widget _buildApp(FakeAuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
  );
}

void main() {
  testWidgets('shows validation errors for empty fields', (tester) async {
    final repository = FakeAuthRepository();

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(repository.loginCalls, 0);
  });

  testWidgets('submits credentials', (tester) async {
    final repository = FakeAuthRepository();

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'tech@fieldops.dev',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'tech1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
    expect(repository.lastEmail, 'tech@fieldops.dev');
    expect(repository.lastPassword, 'tech1234');
  });

  testWidgets('shows API error messages', (tester) async {
    final repository = FakeAuthRepository(
      onLogin: (email, password) async {
        throw const ApiException('Invalid email or password.', statusCode: 401);
      },
    );

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'tech@fieldops.dev',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
  });

  testWidgets('demo button fills the form', (tester) async {
    final repository = FakeAuthRepository();

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use technician demo'));
    await tester.pump();

    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();

    expect(fields[0].controller?.text, 'tech@fieldops.dev');
    expect(fields[1].controller?.text, 'tech1234');
  });

  testWidgets('admin demo button fills the admin form', (tester) async {
    final repository = FakeAuthRepository();

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use admin demo'));
    await tester.pump();

    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();

    expect(fields[0].controller?.text, 'admin@fieldops.dev');
    expect(fields[1].controller?.text, 'admin1234');
  });
}
