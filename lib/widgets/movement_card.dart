import 'package:flutter/material.dart';
import '../models/unified_movement.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';

class MovementCard extends StatelessWidget {
  final UnifiedMovement movement;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const MovementCard({
    super.key,
    required this.movement,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final isTransfer = m.expense?.isTransfer == true;
    final color = isTransfer
        ? Theme.of(context).colorScheme.tertiary
        : (m.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor);

    return Dismissible(
      key: Key(m.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTransfer
                      ? Icons.swap_horiz
                      : (m.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),

              // Label + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isTransfer && m.expense?.transferTo != null
                                ? 'Transferencia → ${m.expense!.transferTo}'
                                : m.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (m.isRecurring) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.repeat_rounded, size: 10,
                                    color: Theme.of(context).colorScheme.tertiary),
                                const SizedBox(width: 2),
                                Text(
                                  'Recurrente',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.tertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (m.subtitle?.isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(
                        m.subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          m.isCash ? Icons.money_rounded : Icons.account_balance_rounded,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          m.isCash ? 'Efectivo' : 'Banco',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        if (m.expense?.tags.isNotEmpty == true) ...[
                          const SizedBox(width: 8),
                          ...m.expense!.tags.take(3).map((tag) => Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(tag, style: TextStyle(fontSize: 8, color: Theme.of(context).colorScheme.primary)),
                          )),
                          if (m.expense!.tags.length > 3)
                            Text('+${m.expense!.tags.length - 3}', style: TextStyle(fontSize: 8, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Amount
              Text(
                '${m.isIncome ? '+' : '-'}${Formatters.formatCurrency(m.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
