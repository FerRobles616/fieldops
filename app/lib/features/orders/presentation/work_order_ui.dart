import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension WorkOrderStatusUi on WorkOrderStatus {
  Color color(ColorScheme scheme) {
    return switch (this) {
      WorkOrderStatus.pending => scheme.tertiary,
      WorkOrderStatus.inProgress => scheme.primary,
      WorkOrderStatus.done => scheme.secondary,
      WorkOrderStatus.cancelled => scheme.error,
    };
  }

  IconData get icon {
    return switch (this) {
      WorkOrderStatus.pending => Icons.schedule_rounded,
      WorkOrderStatus.inProgress => Icons.play_circle_outline_rounded,
      WorkOrderStatus.done => Icons.check_circle_outline_rounded,
      WorkOrderStatus.cancelled => Icons.cancel_outlined,
    };
  }
}

extension WorkOrderPriorityUi on WorkOrderPriority {
  Color color(ColorScheme scheme) {
    return switch (this) {
      WorkOrderPriority.low => scheme.outline,
      WorkOrderPriority.medium => scheme.tertiary,
      WorkOrderPriority.high => Colors.orange.shade800,
      WorkOrderPriority.urgent => scheme.error,
    };
  }

  IconData get icon {
    return switch (this) {
      WorkOrderPriority.low => Icons.arrow_downward_rounded,
      WorkOrderPriority.medium => Icons.remove_rounded,
      WorkOrderPriority.high => Icons.arrow_upward_rounded,
      WorkOrderPriority.urgent => Icons.priority_high_rounded,
    };
  }
}

String formatScheduled(DateTime? date) {
  if (date == null) {
    return 'Not scheduled';
  }
  return DateFormat('EEE, MMM d · HH:mm').format(date);
}

String formatUpdated(DateTime date) {
  return DateFormat('MMM d, yyyy · HH:mm').format(date);
}
