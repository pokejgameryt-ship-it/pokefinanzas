import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/daily_income.dart';
import '../../models/expense.dart';
import '../../services/database_service.dart';
import '../../utils/formatters.dart';
import '../../utils/theme.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final _db = DatabaseService.instance;
  List<DailyIncome> _recurringIncomes = [];
  List<Expense> _recurringExpenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _db.getRecurringIncomes(),
      _db.getRecurringExpenses(),
    ]);
    if (mounted) {
      setState(() {
        _recurringIncomes = results[0] as List<DailyIncome>;
        _recurringExpenses = results[1] as List<Expense>;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRecurringIncome(DailyIncome income) async {
    await _db.deleteIncome(income.id);
    _loadData();
  }

  Future<void> _deleteRecurringExpense(Expense expense) async {
    await _db.deleteExpense(expense.id);
    _loadData();
  }

  void _showEditIncomeDialog(DailyIncome income) {
    final amountCtl = TextEditingController(text: income.totalAmount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar: ${income.recurringName ?? income.type}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cantidad (\u20ac)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtl.text) ?? 0;
              if (amount <= 0) return;
              final updated = DailyIncome(
                id: income.id,
                date: income.date,
                totalAmount: amount,
                notes: income.notes,
                type: income.type,
                isRecurring: true,
                recurringName: income.recurringName,
              );
              await _db.updateIncome(updated);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditExpenseDialog(Expense expense) {
    final amountCtl = TextEditingController(text: expense.amount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar: ${expense.recurringName ?? expense.category}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cantidad (\u20ac)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtl.text) ?? 0;
              if (amount <= 0) return;
              final updated = Expense(
                id: expense.id,
                amount: amount,
                category: expense.category,
                subcategory: expense.subcategory,
                date: expense.date,
                description: expense.description,
                isRecurring: true,
                recurringName: expense.recurringName,
              );
              await _db.updateExpense(updated);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos Recurrentes')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_recurringIncomes.isNotEmpty) ...[
                    Text('Ingresos recurrentes',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._recurringIncomes.map((inc) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.incomeColor.withValues(alpha: 0.1),
                          child: Icon(Icons.trending_up, color: AppTheme.incomeColor, size: 20),
                        ),
                        title: Text(inc.recurringName ?? inc.type),
                        subtitle: Text('Día ${inc.date.day} · ${Formatters.formatCurrency(inc.totalAmount)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _showEditIncomeDialog(inc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () => _deleteRecurringIncome(inc),
                            ),
                          ],
                        ),
                      ),
                    )),
                    const SizedBox(height: 16),
                  ],
                  if (_recurringExpenses.isNotEmpty) ...[
                    Text('Gastos recurrentes',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._recurringExpenses.map((exp) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.expenseColor.withValues(alpha: 0.1),
                          child: Icon(Icons.trending_down, color: AppTheme.expenseColor, size: 20),
                        ),
                        title: Text(exp.recurringName ?? exp.category),
                        subtitle: Text('${exp.category} · Día ${exp.date.day} · ${Formatters.formatCurrency(exp.amount)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _showEditExpenseDialog(exp),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () => _deleteRecurringExpense(exp),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],
                  if (_recurringIncomes.isEmpty && _recurringExpenses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            Icon(Icons.repeat, size: 64, color: colorScheme.primary.withValues(alpha: 0.25)),
                            const SizedBox(height: 16),
                            Text('No hay movimientos recurrentes',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            Text('Los movimientos recurrentes se generan automáticamente cada mes',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
