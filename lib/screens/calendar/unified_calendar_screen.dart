import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/daily_income.dart';
import '../../models/expense.dart';
import '../../services/database_service.dart';
import '../../utils/formatters.dart';
import '../../utils/theme.dart';

class UnifiedCalendarScreen extends StatefulWidget {
  final DateTime? initialDate;

  const UnifiedCalendarScreen({super.key, this.initialDate});

  @override
  State<UnifiedCalendarScreen> createState() => _UnifiedCalendarScreenState();
}

class _UnifiedCalendarScreenState extends State<UnifiedCalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  final _db = DatabaseService.instance;
  Map<DateTime, List<DailyIncome>> _incomesByDay = {};
  Map<DateTime, List<Expense>> _expensesByDay = {};
  List<DailyIncome> _recurringIncomes = [];
  List<Expense> _recurringExpenses = [];
  double _monthIncome = 0;
  double _monthExpenses = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate ?? DateTime.now();
    _selectedDay = _focusedDay;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final month = _focusedDay.month;
    final year = _focusedDay.year;

    final incomes = await _db.getIncomesByMonth(month, year);
    final expenses = await _db.getExpensesByMonth(month, year);
    final recurringIncomes = await _db.getRecurringIncomes();
    final recurringExpenses = await _db.getRecurringExpenses();

    final Map<DateTime, List<DailyIncome>> incomeMap = {};
    final Map<DateTime, List<Expense>> expenseMap = {};

    double monthIncome = 0;
    for (final inc in incomes) {
      final day = DateTime(inc.date.year, inc.date.month, inc.date.day);
      incomeMap.putIfAbsent(day, () => []).add(inc);
      monthIncome += inc.totalAmount;
    }

    double monthExpenses = 0;
    for (final exp in expenses) {
      final day = DateTime(exp.date.year, exp.date.month, exp.date.day);
      expenseMap.putIfAbsent(day, () => []).add(exp);
      monthExpenses += exp.amount;
    }

    // Add recurring transactions to their respective days
    for (final inc in recurringIncomes) {
      final dayOfMonth = inc.date.day.clamp(1, _daysInMonth(year, month));
      final day = DateTime(year, month, dayOfMonth);
      if (!incomeMap.containsKey(day)) {
        incomeMap[day] = [];
      }
    }
    for (final exp in recurringExpenses) {
      final dayOfMonth = exp.date.day.clamp(1, _daysInMonth(year, month));
      final day = DateTime(year, month, dayOfMonth);
      if (!expenseMap.containsKey(day)) {
        expenseMap[day] = [];
      }
    }

    if (mounted) {
      setState(() {
        _incomesByDay = incomeMap;
        _expensesByDay = expenseMap;
        _recurringIncomes = recurringIncomes;
        _recurringExpenses = recurringExpenses;
        _monthIncome = monthIncome;
        _monthExpenses = monthExpenses;
        _isLoading = false;
      });
    }
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  List<DailyIncome> _getIncomesForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _incomesByDay[key] ?? [];
  }

  List<Expense> _getExpensesForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _expensesByDay[key] ?? [];
  }

  bool _hasRecurringOnDay(DateTime day, {required bool isIncome}) {
    if (isIncome) {
      for (final item in _recurringIncomes) {
        if (item.date.day == day.day) return true;
      }
    } else {
      for (final item in _recurringExpenses) {
        if (item.date.day == day.day) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final balance = _monthIncome - _monthExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Month summary ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryItem(
                          label: 'Ingresos',
                          amount: _monthIncome,
                          color: AppTheme.incomeColor,
                          icon: Icons.arrow_downward_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryItem(
                          label: 'Gastos',
                          amount: _monthExpenses,
                          color: AppTheme.expenseColor,
                          icon: Icons.arrow_upward_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryItem(
                          label: 'Balance',
                          amount: balance,
                          color: balance >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor,
                          icon: balance >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Calendar ──
                TableCalendar(
                  locale: 'es_ES',
                  firstDay: DateTime(2020),
                  lastDay: DateTime.now(),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() => _calendarFormat = format);
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                    _loadData();
                  },
                  eventLoader: (day) {
                    final key = DateTime(day.year, day.month, day.day);
                    final hasIncome = _incomesByDay.containsKey(key);
                    final hasExpense = _expensesByDay.containsKey(key);
                    final hasRecurringIncome = _hasRecurringOnDay(day, isIncome: true);
                    final hasRecurringExpense = _hasRecurringOnDay(day, isIncome: false);
                    if (hasIncome || hasExpense || hasRecurringIncome || hasRecurringExpense) return [true];
                    return [];
                  },
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    todayDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 0,
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      final key = DateTime(day.year, day.month, day.day);
                      final hasIncome = _incomesByDay.containsKey(key);
                      final hasExpense = _expensesByDay.containsKey(key);
                      final hasRecurringIncome = _hasRecurringOnDay(day, isIncome: true);
                      final hasRecurringExpense = _hasRecurringOnDay(day, isIncome: false);

                      if (!hasIncome && !hasExpense && !hasRecurringIncome && !hasRecurringExpense) return null;

                      return Positioned(
                        bottom: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasIncome)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.incomeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (hasRecurringIncome && !hasIncome)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.incomeColor.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (hasExpense)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.expenseColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (hasRecurringExpense && !hasExpense)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.expenseColor.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const Divider(height: 1),

                // ── Day movements ──
                Expanded(
                  child: _selectedDay == null
                      ? const Center(child: Text('Selecciona un día'))
                      : _buildDayMovements(),
                ),
              ],
            ),
    );
  }

  Widget _buildDayMovements() {
    final incomes = _getIncomesForDay(_selectedDay!);
    final expenses = _getExpensesForDay(_selectedDay!);

    // Check for recurring items on this day
    final recurringIncomeItems = _recurringIncomes.where((i) => i.date.day == _selectedDay!.day).toList();
    final recurringExpenseItems = _recurringExpenses.where((e) => e.date.day == _selectedDay!.day).toList();

    if (incomes.isEmpty && expenses.isEmpty && recurringIncomeItems.isEmpty && recurringExpenseItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'Sin movimientos este día',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final allItems = <_DayMovement>[];
    for (final inc in incomes) {
      allItems.add(_DayMovement(
        label: inc.recurringName ?? _getIncomeTypeLabel(inc.type),
        amount: inc.totalAmount,
        isIncome: true,
        subtitle: inc.notes,
      ));
    }
    for (final exp in expenses) {
      allItems.add(_DayMovement(
        label: exp.category.isNotEmpty ? exp.category : 'Sin categoría',
        amount: exp.amount,
        isIncome: false,
        subtitle: exp.description,
      ));
    }
    // Add recurring items (shown as "expected")
    for (final inc in recurringIncomeItems) {
      final alreadyListed = incomes.any((i) => i.id == inc.id);
      if (!alreadyListed) {
        allItems.add(_DayMovement(
          label: '${inc.recurringName ?? _getIncomeTypeLabel(inc.type)} (fijo)',
          amount: inc.totalAmount,
          isIncome: true,
          subtitle: inc.notes,
        ));
      }
    }
    for (final exp in recurringExpenseItems) {
      final alreadyListed = expenses.any((e) => e.id == exp.id);
      if (!alreadyListed) {
        allItems.add(_DayMovement(
          label: '${exp.recurringName ?? (exp.category.isNotEmpty ? exp.category : 'Sin categoría')} (fijo)',
          amount: exp.amount,
          isIncome: false,
          subtitle: exp.description,
        ));
      }
    }
    allItems.sort((a, b) => b.amount.compareTo(a.amount));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        final color = item.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (item.subtitle?.isNotEmpty == true)
                      Text(
                        item.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Text(
                '${item.isIncome ? '+' : '-'}${Formatters.formatCurrency(item.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getIncomeTypeLabel(String type) {
    switch (type) {
      case 'hourly':
        return 'Por horas';
      case 'recurring':
        return 'Recurrente';
      default:
        return 'Fijo';
    }
  }
}

class _DayMovement {
  final String label;
  final double amount;
  final bool isIncome;
  final String? subtitle;

  const _DayMovement({
    required this.label,
    required this.amount,
    required this.isIncome,
    this.subtitle,
  });
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Formatters.formatCurrency(amount),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
