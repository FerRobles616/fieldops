import 'package:fieldops_app/features/admin/presentation/admin_new_order_screen.dart';
import 'package:fieldops_app/features/admin/presentation/admin_screen.dart';
import 'package:fieldops_app/features/auth/application/auth_controller.dart';
import 'package:fieldops_app/features/auth/domain/auth_models.dart';
import 'package:fieldops_app/features/auth/presentation/login_screen.dart';
import 'package:fieldops_app/features/orders/presentation/orders_screen.dart';
import 'package:fieldops_app/features/orders/presentation/work_order_detail_screen.dart';
import 'package:fieldops_app/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (auth.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      final isAuthenticated = auth.value is AuthAuthenticated;
      if (!isAuthenticated) {
        return location == '/login' ? null : '/login';
      }

      final session = switch (auth.value) {
        AuthAuthenticated(:final session) => session,
        _ => null,
      };
      if (location.startsWith('/admin') &&
          session?.user.role != UserRole.admin) {
        return '/orders';
      }

      if (location == '/login' || location == '/splash') {
        return '/orders';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
      GoRoute(
        path: '/admin/new-order',
        builder: (context, state) => const AdminNewOrderScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) =>
            WorkOrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
    ],
  );
});

class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen<AsyncValue<AuthState>>(authControllerProvider, (previous, next) {
      notifyListeners();
    });
  }
}
