import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/features/auth/application/auth_controller.dart';
import 'package:fieldops_app/features/auth/domain/auth_models.dart';
import 'package:fieldops_app/features/orders/application/sync_controller.dart';
import 'package:fieldops_app/features/orders/application/work_orders_controller.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:fieldops_app/features/orders/presentation/widgets/work_order_chips.dart';
import 'package:fieldops_app/features/orders/presentation/work_order_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  WorkOrderStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(syncControllerProvider.notifier).sync();
    });
  }

  Future<void> _sync({bool full = false}) async {
    await ref.read(syncControllerProvider.notifier).sync(full: full);
  }

  Future<void> _logout() async {
    await ref.read(localStoreProvider).clearAll();
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).value;
    final user = switch (authState) {
      AuthAuthenticated(:final session) => session.user,
      _ => null,
    };
    final orders = ref.watch(workOrdersProvider);
    final syncStatus = ref.watch(syncControllerProvider);
    final pendingCount = ref.watch(pendingOpsCountProvider).value ?? 0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FieldOps',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (user?.role == UserRole.admin)
            IconButton(
              tooltip: 'Admin console',
              onPressed: () => context.push('/admin'),
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          IconButton(
            tooltip: 'Sync now',
            onPressed: syncStatus.isSyncing ? null : () => _sync(full: true),
            icon: syncStatus.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _sync(full: true),
        child: orders.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 180),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 64),
              _ErrorState(
                message: error is ApiException
                    ? error.message
                    : 'Could not load work orders.',
                onRetry: () => _sync(full: true),
              ),
            ],
          ),
          data: (allOrders) {
            if (allOrders.isEmpty && syncStatus.isSyncing) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }

            if (allOrders.isEmpty && syncStatus.lastError != null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 64),
                  _ErrorState(
                    message: syncStatus.lastError!,
                    onRetry: () => _sync(full: true),
                  ),
                ],
              );
            }

            final filtered = _statusFilter == null
                ? allOrders
                : allOrders
                      .where((order) => order.status == _statusFilter)
                      .toList();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                if (user != null) _UserHeader(user: user),
                const SizedBox(height: 16),
                _SyncBanner(
                  status: syncStatus,
                  pendingCount: pendingCount,
                  onSync: () => _sync(full: true),
                ),
                _FilterChips(
                  selected: _statusFilter,
                  onSelected: (value) {
                    setState(() => _statusFilter = value);
                  },
                ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  _EmptyState(filtered: _statusFilter != null)
                else
                  ...filtered.map((order) => _WorkOrderCard(order: order)),
                const SizedBox(height: 16),
                Text(
                  '${filtered.length} of ${allOrders.length} work orders',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            user.initials,
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${user.role.label} · ${user.email}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({
    required this.status,
    required this.pendingCount,
    required this.onSync,
  });

  final SyncStatus status;
  final int pendingCount;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final offline = !status.isOnline;
    final hasError = status.lastError != null;
    final isSyncing = status.isSyncing;

    if (!offline && !hasError && !isSyncing && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final color = offline || hasError ? scheme.error : scheme.primary;
    final icon = offline
        ? Icons.cloud_off_rounded
        : hasError
        ? Icons.sync_problem_rounded
        : isSyncing
        ? Icons.sync_rounded
        : Icons.cloud_upload_outlined;
    final message = offline
        ? 'Offline — showing cached work orders. Changes will sync when you reconnect.'
        : hasError
        ? 'Sync failed: ${status.lastError}'
        : isSyncing
        ? 'Syncing changes...'
        : '$pendingCount change${pendingCount == 1 ? '' : 's'} waiting to sync.';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13)),
          ),
          if (!isSyncing)
            IconButton(
              tooltip: 'Sync now',
              onPressed: onSync,
              icon: Icon(Icons.refresh_rounded, color: color),
            ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  static const _options = <(String, WorkOrderStatus?)>[
    ('All', null),
    ('Pending', WorkOrderStatus.pending),
    ('In progress', WorkOrderStatus.inProgress),
    ('Done', WorkOrderStatus.done),
  ];

  final WorkOrderStatus? selected;
  final ValueChanged<WorkOrderStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in _options)
          ChoiceChip(
            label: Text(option.$1),
            selected: selected == option.$2,
            showCheckmark: false,
            onSelected: (_) => onSelected(option.$2),
          ),
      ],
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    order.code,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (order.pendingSync) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Waiting to sync',
                      child: Icon(
                        Icons.cloud_upload_outlined,
                        size: 16,
                        color: scheme.tertiary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  WorkOrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                order.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.customer.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      formatScheduled(order.scheduledAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  WorkOrderPriorityChip(priority: order.priority),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            filtered ? 'No orders in this status' : 'No work orders assigned',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filtered
                ? 'Try another filter.'
                : 'New assignments will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Icon(Icons.cloud_off_rounded, size: 48, color: scheme.error),
        const SizedBox(height: 16),
        Text(
          'Could not load work orders',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}
