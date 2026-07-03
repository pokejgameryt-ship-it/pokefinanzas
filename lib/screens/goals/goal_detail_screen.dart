import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/goal.dart';
import '../../services/database_service.dart';
import '../../utils/formatters.dart';
import '../../utils/theme.dart';

class GoalDetailScreen extends StatefulWidget {
  final Goal goal;

  const GoalDetailScreen({super.key, required this.goal});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  late Goal _goal;
  final _db = DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _goal = widget.goal;
  }

  String _getFrequencyLabel(String? freq) {
    switch (freq) {
      case 'daily': return 'Diario';
      case 'weekly': return 'Semanal';
      case 'monthly': return 'Mensual';
      case 'quarterly': return 'Trimestral';
      case 'annual': return 'Anual';
      default: return freq ?? '';
    }
  }

  Future<void> _recordPayment() async {
    final amountCtl = TextEditingController(text: (_goal.nextPaymentAmount ?? 0).toStringAsFixed(2));
    final noteCtl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pago ${_goal.completedPayments + 1} de ${_goal.totalPayments ?? "?"}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Importe',
                prefixText: '\u20ac ',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtl,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );

    if (confirmed != true) return;

    final amount = double.tryParse(amountCtl.text) ?? 0;
    if (amount <= 0) return;

    final payment = PaymentRecord(
      date: DateTime.now(),
      amount: amount,
      note: noteCtl.text.isNotEmpty ? noteCtl.text : null,
    );

    final updatedGoal = _goal.copyWith(
      savedAmount: _goal.savedAmount + amount,
      completedPayments: _goal.completedPayments + 1,
      paymentHistory: [..._goal.paymentHistory, payment],
    );

    await _db.updateGoal(updatedGoal);
    setState(() => _goal = updatedGoal);
  }

  Future<void> _addManualSavings() async {
    final amountCtl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir Ahorro'),
        content: TextField(
          controller: amountCtl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Importe',
            prefixText: '\u20ac ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Añadir')),
        ],
      ),
    );

    if (confirmed != true) return;
    final amount = double.tryParse(amountCtl.text) ?? 0;
    if (amount <= 0) return;

    final updatedGoal = _goal.copyWith(savedAmount: _goal.savedAmount + amount);
    await _db.updateGoal(updatedGoal);
    setState(() => _goal = updatedGoal);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_goal.name),
        actions: [
          if (_goal.isCompleted)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(Icons.check_circle, color: AppTheme.savingsColor),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Progress card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.flag, size: 48, color: colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    _goal.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _goal.progressPercentage / 100,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(6),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: _goal.isCompleted ? AppTheme.savingsColor : colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Formatters.formatCurrency(_goal.savedAmount),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.savingsColor,
                        ),
                      ),
                      Text(
                        '${_goal.progressPercentage.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      Text(
                        Formatters.formatCurrency(_goal.targetAmount),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  if (_goal.deadline != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Fecha límite: ${dateFormat.format(_goal.deadline!)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Fixed payment info
          if (_goal.hasFixedPayment) ...[
            Card(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Plan de Pagos',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _infoRow('Frecuencia', _getFrequencyLabel(_goal.paymentFrequency)),
                    _infoRow('Importe por pago', Formatters.formatCurrency(_goal.paymentAmount ?? 0)),
                    _infoRow('Total de pagos', '${_goal.totalPayments ?? 0}'),
                    _infoRow('Pagos realizados', '${_goal.completedPayments}'),
                    _infoRow('Pagos restantes', '${_goal.remainingPayments}'),
                    _infoRow('Total pagado', Formatters.formatCurrency(_goal.completedPayments * (_goal.paymentAmount ?? 0))),
                    if (_goal.nextPaymentDate != null && !_goal.isCompleted) ...[
                      const Divider(),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 18, color: colorScheme.tertiary),
                          const SizedBox(width: 8),
                          Text(
                            'Próximo pago: ${dateFormat.format(_goal.nextPaymentDate!)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action buttons
          if (!_goal.isCompleted)
            Row(
              children: [
                if (_goal.hasFixedPayment)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _goal.remainingPayments > 0 ? _recordPayment : null,
                      icon: const Icon(Icons.payment),
                      label: const Text('Registrar Pago'),
                    ),
                  ),
                if (_goal.hasFixedPayment) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addManualSavings,
                    icon: const Icon(Icons.savings),
                    label: const Text('Añadir Ahorro'),
                  ),
                ),
              ],
            ),

          if (_goal.isCompleted)
            Card(
              color: AppTheme.savingsColor.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.savingsColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '¡Meta alcanzada! Has conseguido tu objetivo.',
                        style: TextStyle(
                          color: AppTheme.savingsColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Payment history
          if (_goal.paymentHistory.isNotEmpty) ...[
            Text(
              'Historial de Pagos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _goal.paymentHistory.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final payment = _goal.paymentHistory[_goal.paymentHistory.length - 1 - i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.savingsColor.withValues(alpha: 0.1),
                      child: Icon(Icons.check, color: AppTheme.savingsColor, size: 18),
                    ),
                    title: Text(Formatters.formatCurrency(payment.amount)),
                    subtitle: Text(dateFormat.format(payment.date)),
                    trailing: payment.note != null
                        ? Text(payment.note!, style: Theme.of(context).textTheme.bodySmall)
                        : null,
                  );
                },
              ),
            ),
          ],

          if (_goal.paymentHistory.isEmpty && _goal.hasFixedPayment)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'Aún no hay pagos registrados',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
