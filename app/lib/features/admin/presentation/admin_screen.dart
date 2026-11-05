import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/features/admin/application/admin_providers.dart';
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

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(syncControllerProvider.notifier).sync(full: true);
    });
  }

  Future<void> _sync() async {
    await ref.read(syncControllerProvider.notifier).sync(full: true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openNewOrder() async {
    final created = await context.push<bool>('/admin/new-order');
    if (created == true) {
      await _sync();
      if (mounted) {
        _showMessage('Work order created.');
      }
    }
  }

  Future<void> _createCustomer() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const _CustomerDialog(),
    );
    if (created == true) {
      ref.invalidate(customersProvider);
      if (mounted) {
        _showMessage('Customer created.');
      }
    }
  }

  Future<void> _assign(WorkOrder order) async {
    final technicianId = await showDialog<String>(
      context: context,
      builder: (context) => _AssignDialog(order: order),
    );
    if (technicianId == null) {
      return;
    }

    try {
      await ref
          .read(adminRepositoryProvider)
          .assignWorkOrder(
            workOrderId: order.id,
            technicianId: technicianId,
            baseVersion: order.version,
          );
      await _sync();
      if (mounted) {
        _showMessage('Work order assigned.');
      }
    } on ApiException catch (error) {
      if (error.statusCode == 409) {
        await _sync();
      }
      if (mounted) {
        _showMessage(error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).value;
    final user = switch (authState) {
      AuthAuthenticated(:final session) => session.user,
      _ => null,
    };
    final syncStatus = ref.watch(syncControllerProvider);
    final ordersAsync = ref.watch(workOrdersProvider);
    final theme = Theme.of(context);

    if (user?.role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin console')),
        body: const Center(child: Text('Admins only.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin console',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed: syncStatus.isSyncing ? null : _sync,
            icon: syncStatus.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _sync,
        child: ordersAsync.when(
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
              _AdminError(
                message: error is ApiException
                    ? error.message
                    : 'Could not load work orders.',
                onRetry: _sync,
              ),
            ],
          ),
          data: (orders) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operations',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create work orders, assign technicians, and review the field workload.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _createCustomer,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('New customer'),
                      ),
                      FilledButton.icon(
                        onPressed: _openNewOrder,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('New work order'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(
                    label: 'Total orders',
                    value: orders.length,
                    icon: Icons.assignment_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  _StatCard(
                    label: 'Unassigned',
                    value: orders
                        .where((order) => order.assignedTo == null)
                        .length,
                    icon: Icons.person_off_outlined,
                    color: theme.colorScheme.tertiary,
                  ),
                  _StatCard(
                    label: 'Pending',
                    value: orders
                        .where(
                          (order) => order.status == WorkOrderStatus.pending,
                        )
                        .length,
                    icon: Icons.schedule_rounded,
                    color: theme.colorScheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (orders.isEmpty)
                _AdminEmpty(onCreate: _openNewOrder)
              else
                for (final order in orders)
                  _AdminOrderCard(
                    order: order,
                    onAssign: () => _assign(order),
                    onOpen: () => context.push('/orders/${order.id}'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  const _AdminOrderCard({
    required this.order,
    required this.onAssign,
    required this.onOpen,
  });

  final WorkOrder order;
  final VoidCallback onAssign;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final assignedTo = order.assignedTo;
    final assignedColor = assignedTo == null
        ? scheme.error
        : scheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 16,
                    color: scheme.tertiary,
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
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  assignedTo == null
                      ? Icons.person_off_outlined
                      : Icons.person_outline_rounded,
                  size: 16,
                  color: assignedColor,
                ),
                const SizedBox(width: 6),
                Text(
                  assignedTo?.name ?? 'Unassigned',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: assignedColor,
                    fontWeight: assignedTo == null
                        ? FontWeight.w600
                        : FontWeight.w400,
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
                WorkOrderPriorityChip(priority: order.priority),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onAssign,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: Text(assignedTo == null ? 'Assign' : 'Reassign'),
                ),
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminEmpty extends StatelessWidget {
  const _AdminEmpty({required this.onCreate});

  final VoidCallback onCreate;

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
            'No work orders yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create the first work order and assign it to a technician.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New work order'),
          ),
        ],
      ),
    );
  }
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.message, required this.onRetry});

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
          'Could not load the admin console',
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

class _AssignDialog extends ConsumerStatefulWidget {
  const _AssignDialog({required this.order});

  final WorkOrder order;

  @override
  ConsumerState<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<_AssignDialog> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.order.assignedTo?.id;
  }

  @override
  Widget build(BuildContext context) {
    final techniciansAsync = ref.watch(techniciansProvider);

    return AlertDialog(
      title: Text('Assign ${widget.order.code}'),
      content: techniciansAsync.when(
        loading: () => const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => const Text(
          'Could not load technicians. Try again from the admin console.',
        ),
        data: (technicians) {
          if (technicians.isEmpty) {
            return const Text('No technicians available.');
          }

          final selected =
              technicians.any((technician) => technician.id == _selectedId)
              ? _selectedId
              : null;

          return SizedBox(
            width: 360,
            child: DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Technician'),
              items: [
                for (final technician in technicians)
                  DropdownMenuItem(
                    value: technician.id,
                    child: Text(technician.name),
                  ),
              ],
              onChanged: (value) {
                setState(() => _selectedId = value);
              },
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedId == null
              ? null
              : () => Navigator.pop(context, _selectedId),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

class _CustomerDialog extends ConsumerStatefulWidget {
  const _CustomerDialog();

  @override
  ConsumerState<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends ConsumerState<_CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref
          .read(adminRepositoryProvider)
          .createCustomer(
            name: _nameController.text.trim(),
            address: _addressController.text.trim(),
            phone: _phoneController.text.trim(),
          );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New customer'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a customer name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
