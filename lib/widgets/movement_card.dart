import 'package:flutter/material.dart';
import '../models/unified_movement.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';

class MovementCard extends StatefulWidget {
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
  State<MovementCard> createState() => _MovementCardState();
}

class _MovementCardState extends State<MovementCard> {
  final GlobalKey _cardKey = GlobalKey();

  void _showContextMenu(LongPressStartDetails details) {
    final RenderBox? renderBox = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
      Rect.fromLTWH(0, 0, renderBox.size.width, renderBox.size.height),
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20),
              SizedBox(width: 12),
              Text('Editar'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('Eliminar', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        widget.onTap();
      } else if (value == 'delete') {
        widget.onDelete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movement;
    final isTransfer = m.expense?.isTransfer == true;
    final isCajero = (m.isIncome && m.income?.type == 'cajero') ||
        (!isTransfer && m.expense?.category == 'Cajero');
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
        widget.onDelete();
        return false;
      },
      child: GestureDetector(
        key: _cardKey,
        onTap: widget.onTap,
        onLongPressStart: _showContextMenu,
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
                      : isCajero
                          ? Icons.local_atm
                          : (m.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isCajero
                                ? (m.income?.notes?.contains('Efectivo a Banco') == true
                                    ? 'Cajero: Efectivo \u2192 Banco'
                                    : m.expense?.description?.contains('Banco a Efectivo') == true
                                        ? 'Cajero: Banco \u2192 Efectivo'
                                        : m.income?.notes?.contains('Banco a Efectivo') == true
                                            ? 'Cajero: Banco \u2192 Efectivo'
                                            : 'Cajero ATM')
                                : isTransfer && m.expense?.transferTo != null
                                    ? 'Transferencia \u2192 ${m.expense!.transferTo}'
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
