import 'package:fieldops_app/core/sync/connectivity_provider.dart';
import 'package:fieldops_app/features/orders/application/sync_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncListener extends ConsumerWidget {
  const SyncListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      final online = next.value ?? false;
      if (online && previous?.value != true) {
        ref.read(syncControllerProvider.notifier).sync();
      }
    });

    return child;
  }
}
