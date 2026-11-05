import 'package:fieldops_app/features/orders/domain/work_order_models.dart';
import 'package:fieldops_app/features/orders/presentation/work_order_ui.dart';
import 'package:flutter/material.dart';

class WorkOrderStatusChip extends StatelessWidget {
  const WorkOrderStatusChip({super.key, required this.status});

  final WorkOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color(Theme.of(context).colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkOrderPriorityChip extends StatelessWidget {
  const WorkOrderPriorityChip({super.key, required this.priority});

  final WorkOrderPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = priority.color(Theme.of(context).colorScheme);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(priority.icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          priority.label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
