import 'package:flutter/material.dart';
import '../../models/goal.dart';
import '../../models/savings_distribution.dart';
import '../../providers/app_state.dart';
import '../../services/database_service.dart';
import '../../services/payment_reminder_service.dart';
import '../../utils/formatters.dart';
import '../../utils/theme.dart';
import '../../widgets/shimmer_loading.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseService.instance;
  double _totalIncome = 0;
  double _totalExpenses = 0;
  double _totalBalance = 0;
  double _weeklyIncome = 0;
  double _weeklyExpenses = 0;
  int _incomeCount = 0;
  int _expenseCount = 0;
  Goal? _activeGoal;
  SavingsDistribution? _currentDistribution;
  double _totalSavings = 0;
  double _cashIncome = 0;
  double _cashExpense = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    AppState.instance.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      final results = await Future.wait([
        _db.getTotalIncomeByMonth(now.month, now.year),
        _db.getTotalExpensesByMonth(now.month, now.year),
        _db.getIncomesByMonth(now.month, now.year),
        _db.getExpensesByMonth(now.month, now.year),
        _db.getTotalBalance(),
        _db.getIncomesByDateRange(startOfWeekDay, now),
        _db.getExpensesByDateRange(startOfWeekDay, now),
        _db.getActiveGoal(),
        _db.getDistribution(now.month, now.year),
        _db.getTotalSavings(),
        _db.getCashIncomeByMonth(now.month, now.year),
        _db.getCashExpenseByMonth(now.month, now.year),
      ]);

      if (mounted) {
        setState(() {
          _totalIncome = results[0] as double;
          _totalExpenses = results[1] as double;
          _incomeCount = (results[2] as List).length;
          _expenseCount = (results[3] as List).length;
          _totalBalance = results[4] as double;
          _weeklyIncome = results[5] as double;
          _weeklyExpenses = results[6] as double;
          _activeGoal = results[7] as Goal?;
          _currentDistribution = results[8] as SavingsDistribution?;
          _totalSavings = results[9] as double;
          _cashIncome = results[10] as double;
          _cashExpense = results[11] as double;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final monthlyBalance = _totalIncome - _totalExpenses;
    final weeklyBalance = _weeklyIncome - _weeklyExpenses;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const ShimmerDashboard()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Total card
                    Card(
                      color: colorScheme.primary,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Text(
                                'Balance Total',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onPrimary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                Formatters.formatCurrency(_totalBalance),
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Todos los tiempos',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onPrimary.withValues(alpha: 0.7),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mensual + Semanal row
                    Row(
                      children: [
                        Expanded(
                          child: _BalanceMiniCard(
                            title: 'Mensual',
                            amount: monthlyBalance,
                            subtitle: Formatters.formatMonthYear(now),
                            isPositive: monthlyBalance >= 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BalanceMiniCard(
                            title: 'Semanal',
                            amount: weeklyBalance,
                            subtitle: 'Esta semana',
                            isPositive: weeklyBalance >= 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Ingresos / Gastos row
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Ingresos',
                            amount: _totalIncome,
                            count: _incomeCount,
                            color: AppTheme.incomeColor,
                            icon: Icons.trending_up,
                            cashAmount: _cashIncome,
                            bankAmount: _totalIncome - _cashIncome,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Gastos',
                            amount: _totalExpenses,
                            count: _expenseCount,
                            color: AppTheme.expenseColor,
                            icon: Icons.trending_down,
                            cashAmount: _cashExpense,
                            bankAmount: _totalExpenses - _cashExpense,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Ahorro card
                    Card(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.savings, color: const Color(0xFF4CAF50), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Ahorro',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                    const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _SavingsStat(
                                    label: 'Total',
                                    amount: _totalSavings,
                                    highlight: true,
                                  ),
                                ),
                                Expanded(
                                  child: _SavingsStat(
                                    label: 'Este mes',
                                    amount: _currentDistribution?.savings ?? 0,
                                  ),
                                ),
                                if (_currentDistribution != null)
                                  Expanded(
                                    child: _SavingsStat(
                                      label: 'Presupuesto',
                                      amount: _currentDistribution!.savingsBudget,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Active Goal card
                    if (_activeGoal != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.flag, color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _activeGoal!.name,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    '${_activeGoal!.progressPercentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _activeGoal!.isCompleted ? Colors.green : colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: _activeGoal!.progressPercentage / 100,
                                minHeight: 8,
                                backgroundColor: colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation(
                                  _activeGoal!.isCompleted ? Colors.green : colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${Formatters.formatCurrency(_activeGoal!.savedAmount)} / ${Formatters.formatCurrency(_activeGoal!.targetAmount)}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  if (_activeGoal!.deadline != null)
                                    Text(
                                      'Fecha límite: ${Formatters.formatDate(_activeGoal!.deadline!)}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Upcoming payments
                    const _UpcomingPaymentsWidget(),
                    const SizedBox(height: 16),

                    Text(
                      'Actividad Reciente',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_incomeCount == 0 && _expenseCount == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sin actividad este mes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Registra ingresos o gastos para ver tu resumen aquí',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              )
            else ...[
              _ActivityTile(
                icon: Icons.attach_money,
                title: 'Ingresos este mes',
                subtitle: '$_incomeCount registros',
                amount: _totalIncome,
                color: AppTheme.incomeColor,
              ),
              const Divider(),
              _ActivityTile(
                icon: Icons.receipt,
                title: 'Gastos este mes',
                subtitle: '$_expenseCount registros',
                amount: _totalExpenses,
                color: AppTheme.expenseColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BalanceMiniCard extends StatelessWidget {
  final String title;
  final double amount;
  final String subtitle;
  final bool isPositive;

  const _BalanceMiniCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              Formatters.formatCurrency(amount),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isPositive ? const Color(0xFF4CAF50) : colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final double amount;
  final int count;
  final Color color;
  final IconData icon;
  final double? cashAmount;
  final double? bankAmount;

  const _StatCard({
    required this.title,
    required this.amount,
    required this.count,
    required this.color,
    required this.icon,
    this.cashAmount,
    this.bankAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              Formatters.formatCurrency(amount),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count registros',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
            ),
            if (cashAmount != null || bankAmount != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (cashAmount != null) ...[
                    Icon(Icons.money_rounded, size: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text(
                      Formatters.formatCurrency(cashAmount!),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const Spacer(),
                  if (bankAmount != null) ...[
                    Icon(Icons.account_balance_rounded, size: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text(
                      Formatters.formatCurrency(bankAmount!),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double amount;
  final Color color;

  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        Formatters.formatCurrency(amount),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _SavingsStat extends StatelessWidget {
  final String label;
  final double amount;
  final bool highlight;

  const _SavingsStat({
    required this.label,
    required this.amount,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          Formatters.formatCurrency(amount),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: highlight ? const Color(0xFF4CAF50) : null,
              ),
        ),
      ],
    );
  }
}

class _UpcomingPaymentsWidget extends StatefulWidget {
  const _UpcomingPaymentsWidget();

  @override
  State<_UpcomingPaymentsWidget> createState() => _UpcomingPaymentsWidgetState();
}

class _UpcomingPaymentsWidgetState extends State<_UpcomingPaymentsWidget> {
  List<UpcomingPayment> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final payments = await PaymentReminderService.instance.getUpcomingPayments();
    if (mounted) {
      setState(() {
        _payments = payments.take(5).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_payments.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upcoming, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Próximos Pagos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._payments.map((p) {
              final now = DateTime.now();
              final daysUntil = p.date.difference(now).inDays;
              final color = p.isExpense ? Colors.red : Colors.green;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                          Text(
                            daysUntil == 0 ? 'Hoy' : daysUntil == 1 ? 'Mañana' : 'En $daysUntil días',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${p.isExpense ? "-" : "+"}${Formatters.formatCurrency(p.amount)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
