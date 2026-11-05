import 'package:fieldops_app/core/network/api_exception.dart';
import 'package:fieldops_app/features/orders/application/photo_picker.dart';
import 'package:fieldops_app/features/orders/application/report_sharer.dart';
import 'package:fieldops_app/features/orders/application/sync_controller.dart';
import 'package:fieldops_app/features/orders/application/work_orders_controller.dart';
import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:fieldops_app/features/orders/domain/work_order_photo.dart';
import 'package:fieldops_app/features/orders/presentation/widgets/work_order_chips.dart';
import 'package:fieldops_app/features/orders/presentation/work_order_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WorkOrderDetailScreen extends ConsumerStatefulWidget {
  const WorkOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<WorkOrderDetailScreen> createState() =>
      _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends ConsumerState<WorkOrderDetailScreen> {
  bool _isUpdating = false;
  bool _isDownloadingReport = false;

  Future<void> _sync({bool full = false}) async {
    await ref.read(syncControllerProvider.notifier).sync(full: full);
  }

  Future<void> _downloadReport(WorkOrder order) async {
    if (_isDownloadingReport) {
      return;
    }

    setState(() => _isDownloadingReport = true);

    try {
      final bytes = await ref
          .read(workOrdersRepositoryProvider)
          .downloadReport(order.id);
      await ref
          .read(reportSharerProvider)
          .share(bytes: bytes, filename: '${order.code}.pdf');
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate the PDF report.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingReport = false);
      }
    }
  }

  Future<void> _updateStatus(WorkOrder order, WorkOrderStatus status) async {
    if (_isUpdating) {
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final result = await ref
          .read(syncControllerProvider.notifier)
          .updateStatus(order, status);

      if (!mounted) {
        return;
      }

      final message = result.conflict
          ? 'This work order changed on the server. It was refreshed.'
          : result.error != null
          ? 'Saved locally. Sync failed: ${result.error}'
          : result.queued
          ? 'Saved offline. It will sync when you are back online.'
          : 'Status updated to ${status.label}.';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the work order.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(workOrderProvider(widget.orderId));
    final syncStatus = ref.watch(syncControllerProvider);
    final photos =
        ref.watch(photosProvider(widget.orderId)).value ??
        const <WorkOrderPhoto>[];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work order'),
        actions: [
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
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _DetailError(
          message: error is ApiException
              ? error.message
              : 'Could not load this work order.',
          onRetry: () => _sync(full: true),
        ),
        data: (order) {
          if (order == null) {
            return _DetailError(
              message: 'This work order is not available offline yet. Sync to load it.',
              onRetry: () => _sync(full: true),
            );
          }

          final scheme = theme.colorScheme;

          return RefreshIndicator(
            onRefresh: () => _sync(full: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Text(
                      order.code,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (order.pendingSync) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Waiting to sync',
                        child: Icon(
                          Icons.cloud_upload_outlined,
                          size: 18,
                          color: scheme.tertiary,
                        ),
                      ),
                    ],
                    const Spacer(),
                    WorkOrderStatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  order.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    WorkOrderPriorityChip(priority: order.priority),
                    const SizedBox(width: 12),
                    Text(
                      'Version ${order.version}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionCard(
                  icon: Icons.business_outlined,
                  title: 'Customer',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customer.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (order.customer.address != null) ...[
                        const SizedBox(height: 4),
                        Text(order.customer.address!),
                      ],
                      if (order.customer.phone != null) ...[
                        const SizedBox(height: 4),
                        Text(order.customer.phone!),
                      ],
                    ],
                  ),
                ),
                if (order.description != null &&
                    order.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    icon: Icons.notes_rounded,
                    title: 'Description',
                    child: Text(order.description!),
                  ),
                ],
                const SizedBox(height: 16),
                _PhotosSection(order: order, photos: photos),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.info_outline_rounded,
                  title: 'Details',
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Scheduled',
                        value: formatScheduled(order.scheduledAt),
                      ),
                      _DetailRow(
                        label: 'Assigned to',
                        value: order.assignedTo?.name ?? 'Unassigned',
                      ),
                      _DetailRow(
                        label: 'Updated',
                        value: formatUpdated(order.updatedAt),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (order.status == WorkOrderStatus.pending)
                  _ActionButton(
                    label: 'Start work',
                    icon: Icons.play_arrow_rounded,
                    isLoading: _isUpdating,
                    onPressed: () {
                      _updateStatus(order, WorkOrderStatus.inProgress);
                    },
                  ),
                if (order.status == WorkOrderStatus.inProgress)
                  _ActionButton(
                    label: 'Mark as done',
                    icon: Icons.check_rounded,
                    isLoading: _isUpdating,
                    onPressed: () {
                      _updateStatus(order, WorkOrderStatus.done);
                    },
                  ),
                if (!order.status.isOpen) ...[
                  Text(
                    'This work order is closed.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isDownloadingReport
                      ? null
                      : () => _downloadReport(order),
                  icon: _isDownloadingReport
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Report PDF'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PhotosSection extends ConsumerStatefulWidget {
  const _PhotosSection({required this.order, required this.photos});

  final WorkOrder order;
  final List<WorkOrderPhoto> photos;

  @override
  ConsumerState<_PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends ConsumerState<_PhotosSection> {
  bool _isAdding = false;

  Future<void> _addPhoto() async {
    if (_isAdding) {
      return;
    }

    final picked = await ref.read(photoPickerProvider).pick();
    if (picked == null) {
      return;
    }

    setState(() => _isAdding = true);

    try {
      final result = await ref
          .read(syncControllerProvider.notifier)
          .addPhoto(widget.order, picked);

      if (!mounted) {
        return;
      }

      final message = result.error != null
          ? 'Photo saved locally. Sync failed: ${result.error}'
          : result.queued
          ? 'Photo saved offline. It will upload when you sync.'
          : 'Photo uploaded.';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add the photo.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _SectionCard(
      icon: Icons.photo_library_outlined,
      title: 'Photos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.photos.isEmpty)
            Text(
              'No photos yet. Add one before or after the repair.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final photo in widget.photos)
                  _PhotoThumbnail(photo: photo),
              ],
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isAdding ? null : _addPhoto,
            icon: _isAdding
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add photo'),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.photo});

  final WorkOrderPhoto photo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Image.memory(
            photo.bytes,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 96,
                height: 96,
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              );
            },
          ),
          if (photo.isPending)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 14,
                  color: scheme.tertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onPrimary,
              ),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              'Could not load this work order',
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
        ),
      ),
    );
  }
}
