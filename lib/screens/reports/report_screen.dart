import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/savings_distribution.dart';
import '../../services/database_service.dart';
import '../../utils/formatters.dart';
import '../../utils/theme.dart';

class ReportScreen extends StatefulWidget {
  final String reportType; // 'monthly', 'weekly', 'annual'
  final int? month;
  final int? year;
  final int? weekNumber;

  const ReportScreen({
    super.key,
    required this.reportType,
    this.month,
    this.year,
    this.weekNumber,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _db = DatabaseService.instance;
  bool _isLoading = true;

  // Shared data
  double _totalIncome = 0;
  double _totalExpenses = 0;
  double _totalCashIncome = 0;
  double _totalCashExpense = 0;
  double _totalBankIncome = 0;
  double _totalBankExpense = 0;
  Map<String, double> _expensesByCategory = {};
  Map<String, double> _incomeByType = {};

  // Monthly data
  double _totalRedistributed = 0;
  SavingsDistribution? _distribution;

  // Weekly data
  List<MapEntry<DateTime, double>> _weeklyIncome = [];
  List<MapEntry<DateTime, double>> _weeklyExpenses = [];
  List<double> _weeklyCumulativeBalance = [];

  // Annual data
  List<MapEntry<DateTime, double>> _annualIncome = [];
  List<MapEntry<DateTime, double>> _annualExpenses = [];
  List<double> _annualCumulativeBalance = [];

  late final int _month;
  late final int _year;

  static const Map<String, Color> _categoryColors = {
    'Alquiler': Color(0xFFE53935),
    'Comida': Color(0xFFFF9800),
    'Transporte': Color(0xFF2196F3),
    'Servicios': Color(0xFFFFC107),
    'Ocio': Color(0xFF9C27B0),
    'Salud': Color(0xFF4CAF50),
    'Ropa': Color(0xFF795548),
    'Otros': Color(0xFF607D8B),
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = widget.month ?? now.month;
    _year = widget.year ?? now.year;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      switch (widget.reportType) {
        case 'monthly':
          await _loadMonthlyData();
          break;
        case 'weekly':
          await _loadWeeklyData();
          break;
        case 'annual':
          await _loadAnnualData();
          break;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMonthlyData() async {
    _totalIncome = await _db.getTotalIncomeByMonth(_month, _year);
    _totalExpenses = await _db.getTotalExpensesByMonth(_month, _year);

    _distribution = await _db.getDistribution(_month, _year);

    // Category breakdown
    final expenses = await _db.getExpensesByMonth(_month, _year);
    for (final e in expenses) {
      if (e.isTransfer) continue;
      if (e.category == 'Cajero') continue;
      _expensesByCategory[e.category] = (_expensesByCategory[e.category] ?? 0) + e.amount;
    }

    // Income by type
    final incomes = await _db.getIncomesByMonth(_month, _year);
    for (final i in incomes) {
      if (i.type == 'cajero') continue;
      final type = i.isRecurring ? (i.recurringName ?? 'Recurrente') : _getIncomeTypeLabel(i.type);
      _incomeByType[type] = (_incomeByType[type] ?? 0) + i.totalAmount;
      _totalCashIncome += i.isCash ? i.totalAmount : 0;
      _totalBankIncome += !i.isCash ? i.totalAmount : 0;
    }

    // Cash/expense split
    for (final e in expenses) {
      if (e.isTransfer) continue;
      if (e.category == 'Cajero') continue;
      _totalCashExpense += e.isCash ? e.amount : 0;
      _totalBankExpense += !e.isCash ? e.amount : 0;
    }

    // Redistribution total
    if (_distribution != null) {
      for (final cat in _distribution!.userCategories) {
        final unspent = _distribution!.getCategoryUnspent(cat);
        if (unspent <= 0) continue;
        for (final entry in cat.redistributionPercentages.entries) {
          _totalRedistributed += unspent * entry.value / 100;
        }
      }
    }
  }

  Future<void> _loadWeeklyData() async {
    final now = DateTime.now();
    // Usar la semana anterior (lunes a domingo pasados), igual que la notificación
    final startOfCurrentWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final prevWeekEnd = startOfCurrentWeek.subtract(const Duration(days: 1));
    final weekStart = DateTime(prevWeekEnd.year, prevWeekEnd.month, prevWeekEnd.day).subtract(const Duration(days: 6));
    double cumulative = 0;

    for (int i = 0; i < 7; i++) {
      final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);

      double dayIncome = 0;
      double dayExpenses = 0;

      final dayIncomes = await _db.getIncomesByDate(day);
      for (final inc in dayIncomes) {
        if (inc.type == 'cajero') continue;
        dayIncome += inc.totalAmount;
        _totalCashIncome += inc.isCash ? inc.totalAmount : 0;
        _totalBankIncome += !inc.isCash ? inc.totalAmount : 0;
      }

      final dayExpensesList = await _db.getExpensesByDate(day);
      for (final exp in dayExpensesList) {
        if (exp.isTransfer) continue;
        if (exp.category == 'Cajero') continue;
        dayExpenses += exp.amount;
        _totalCashExpense += exp.isCash ? exp.amount : 0;
        _totalBankExpense += !exp.isCash ? exp.amount : 0;
        _expensesByCategory[exp.category] = (_expensesByCategory[exp.category] ?? 0) + exp.amount;
      }

      cumulative += dayIncome - dayExpenses;
      _weeklyIncome.add(MapEntry(day, dayIncome));
      _weeklyExpenses.add(MapEntry(day, dayExpenses));
      _weeklyCumulativeBalance.add(cumulative);
    }

    _totalIncome = _weeklyIncome.fold(0, (sum, e) => sum + e.value);
    _totalExpenses = _weeklyExpenses.fold(0, (sum, e) => sum + e.value);
  }

  Future<void> _loadAnnualData() async {
    double cumulative = 0;
    for (int m = 1; m <= 12; m++) {
      final date = DateTime(_year, m, 1);
      final inc = await _db.getTotalIncomeByMonth(m, _year);
      final exp = await _db.getTotalExpensesByMonth(m, _year);

      final monthIncomes = await _db.getIncomesByMonth(m, _year);
      for (final i in monthIncomes) {
        if (i.type == 'cajero') continue;
        _totalCashIncome += i.isCash ? i.totalAmount : 0;
        _totalBankIncome += !i.isCash ? i.totalAmount : 0;
      }

      final monthExpenses = await _db.getExpensesByMonth(m, _year);
      for (final e in monthExpenses) {
        if (e.isTransfer) continue;
        if (e.category == 'Cajero') continue;
        _totalCashExpense += e.isCash ? e.amount : 0;
        _totalBankExpense += !e.isCash ? e.amount : 0;
        _expensesByCategory[e.category] = (_expensesByCategory[e.category] ?? 0) + e.amount;
      }

      cumulative += inc - exp;
      _annualIncome.add(MapEntry(date, inc));
      _annualExpenses.add(MapEntry(date, exp));
      _annualCumulativeBalance.add(cumulative);
    }

    _totalIncome = _annualIncome.fold(0, (sum, e) => sum + e.value);
    _totalExpenses = _annualExpenses.fold(0, (sum, e) => sum + e.value);
  }

  String _getIncomeTypeLabel(String type) {
    switch (type) {
      case 'hourly': return 'Por horas';
      case 'recurring': return 'Recurrente';
      default: return 'Fijo';
    }
  }

  String _getMonthName(int month) {
    const months = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return months[month];
  }

  String _getTitle() {
    switch (widget.reportType) {
      case 'monthly':
        return 'Informe ${_getMonthName(_month)} $_year';
      case 'weekly':
        final now = DateTime.now();
        final startOfCurrentWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final prevWeekEnd = startOfCurrentWeek.subtract(const Duration(days: 1));
        final prevWeekStart = DateTime(prevWeekEnd.year, prevWeekEnd.month, prevWeekEnd.day).subtract(const Duration(days: 6));
        return 'Resumen Semanal\n${Formatters.formatDate(prevWeekStart)} - ${Formatters.formatDate(prevWeekEnd)}';
      case 'annual':
        return 'Informe Anual $_year';
      default:
        return 'Informe';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final balance = _totalIncome - _totalExpenses;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          IconButton(
            onPressed: () => _loadData(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Summary Cards ──
                    _buildSummaryCards(colorScheme, balance),
                    const SizedBox(height: 24),

                    // ── Balance Bar ──
                    _buildBalanceBar(colorScheme, balance),
                    const SizedBox(height: 24),

                    // ── Chart ──
                    if (widget.reportType == 'monthly') ...[
                      _buildMonthlyCharts(colorScheme),
                    ] else if (widget.reportType == 'weekly') ...[
                      _buildWeeklyChart(colorScheme),
                    ] else if (widget.reportType == 'annual') ...[
                      _buildAnnualChart(colorScheme),
                    ],
                    const SizedBox(height: 24),

                    // ── Category Breakdown (all types) ──
                    if (_expensesByCategory.isNotEmpty) ...[
                      _buildCategoryBreakdown(colorScheme),
                      const SizedBox(height: 24),
                    ],

                    // ── Income Breakdown (monthly only) ──
                    if (widget.reportType == 'monthly' && _incomeByType.isNotEmpty) ...[
                      _buildIncomeBreakdown(colorScheme),
                      const SizedBox(height: 24),
                    ],

                    // ── Cash/Bank Balance ──
                    _buildCashBankCard(colorScheme),
                    const SizedBox(height: 24),

                    // ── Balance Evolution Line Chart ──
                    if (widget.reportType == 'weekly' && _weeklyCumulativeBalance.isNotEmpty) ...[
                      _buildBalanceEvolutionChart(colorScheme, _weeklyCumulativeBalance, _weeklyIncome),
                      const SizedBox(height: 24),
                    ],
                    if (widget.reportType == 'annual' && _annualCumulativeBalance.isNotEmpty) ...[
                      _buildBalanceEvolutionChart(colorScheme, _annualCumulativeBalance, _annualIncome),
                      const SizedBox(height: 24),
                    ],

                    // ── Savings Info ──
                    if (widget.reportType == 'monthly' && _distribution != null) ...[
                      _buildSavingsInfo(colorScheme),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCards(ColorScheme colorScheme, double balance) {
    return Row(
      children: [
        Expanded(child: _SummaryCard(
          title: 'Ingresos',
          amount: _totalIncome,
          color: AppTheme.incomeColor,
          icon: Icons.arrow_downward_rounded,
        )),
        const SizedBox(width: 8),
        Expanded(child: _SummaryCard(
          title: 'Gastos',
          amount: _totalExpenses,
          color: AppTheme.expenseColor,
          icon: Icons.arrow_upward_rounded,
        )),
        const SizedBox(width: 8),
        Expanded(child: _SummaryCard(
          title: 'Balance',
          amount: balance,
          color: balance >= 0 ? const Color(0xFF4CAF50) : colorScheme.error,
          icon: Icons.account_balance_wallet,
        )),
      ],
    );
  }

  Widget _buildBalanceBar(ColorScheme colorScheme, double balance) {
    final total = _totalIncome + _totalExpenses;
    final incomeRatio = total > 0 ? _totalIncome / total : 0.5;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distribución',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Expanded(
                    flex: (incomeRatio * 1000).toInt().clamp(1, 999),
                    child: Container(
                      height: 24,
                      color: AppTheme.incomeColor,
                      child: Center(
                        child: Text(
                          _totalIncome > 0 ? '${(incomeRatio * 100).toStringAsFixed(0)}%' : '',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - incomeRatio) * 1000).toInt().clamp(1, 999),
                    child: Container(
                      height: 24,
                      color: AppTheme.expenseColor,
                      child: Center(
                        child: Text(
                          _totalExpenses > 0 ? '${((1 - incomeRatio) * 100).toStringAsFixed(0)}%' : '',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(width: 12, height: 12, color: AppTheme.incomeColor),
                  const SizedBox(width: 4),
                  Text('Ingresos: ${Formatters.formatCurrency(_totalIncome)}',
                    style: const TextStyle(fontSize: 12)),
                ]),
                Row(children: [
                  Container(width: 12, height: 12, color: AppTheme.expenseColor),
                  const SizedBox(width: 4),
                  Text('Gastos: ${Formatters.formatCurrency(_totalExpenses)}',
                    style: const TextStyle(fontSize: 12)),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCharts(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gastos por Categoría',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(height: 200, child: _buildExpensesPieChart(colorScheme)),
        const SizedBox(height: 16),
        ..._expensesByCategory.entries.map((entry) {
          final color = _categoryColors[entry.key] ?? _getColor(entry.key);
          final percentage = _totalExpenses > 0 ? (entry.value / _totalExpenses * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 16, height: 16,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.key)),
                Text(Formatters.formatCurrency(entry.value),
                  style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(width: 8),
                Text('${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWeeklyChart(ColorScheme colorScheme) {
    if (_weeklyIncome.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gastos Diarios',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _weeklyExpenses.fold(0.0, (max, e) => e.value > max ? e.value : max) * 1.2,
              barGroups: List.generate(_weeklyExpenses.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: _weeklyExpenses[i].value,
                      color: AppTheme.expenseColor,
                      width: 20,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < _weeklyExpenses.length) {
                        final day = _weeklyExpenses[idx].key;
                        const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
                        return Text(days[day.weekday - 1], style: const TextStyle(fontSize: 10));
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      return Text(Formatters.formatCurrency(value),
                        style: const TextStyle(fontSize: 9));
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnnualChart(ColorScheme colorScheme) {
    if (_annualIncome.isEmpty) return const SizedBox();

    const monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Evolución Anual',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: [
                ..._annualIncome.map((e) => e.value),
                ..._annualExpenses.map((e) => e.value),
              ].fold(0.0, (max, v) => v > max ? v : max) * 1.2,
              barGroups: List.generate(12, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: _annualIncome[i].value,
                      color: AppTheme.incomeColor,
                      width: 8,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                    BarChartRodData(
                      toY: _annualExpenses[i].value,
                      color: AppTheme.expenseColor,
                      width: 8,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                  ],
                );
              }),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < 12) {
                        return Text(monthNames[idx], style: const TextStyle(fontSize: 9));
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      return Text(Formatters.formatCurrency(value),
                        style: const TextStyle(fontSize: 9));
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 12, height: 12, color: AppTheme.incomeColor),
            const SizedBox(width: 4),
            const Text('Ingresos', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 16),
            Container(width: 12, height: 12, color: AppTheme.expenseColor),
            const SizedBox(width: 4),
            const Text('Gastos', style: TextStyle(fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildExpensesPieChart(ColorScheme colorScheme) {
    if (_expensesByCategory.isEmpty) return const SizedBox();

    final sections = _expensesByCategory.entries.map((entry) {
      final color = _categoryColors[entry.key] ?? _getColor(entry.key);
      return PieChartSectionData(
        value: entry.value,
        color: color,
        title: '${(entry.value / _totalExpenses * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 80,
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 30,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildCategoryBreakdown(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Desglose de Gastos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._expensesByCategory.entries.map((entry) {
              final color = _categoryColors[entry.key] ?? _getColor(entry.key);
              final percentage = _totalExpenses > 0 ? (entry.value / _totalExpenses * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(width: 12, height: 12,
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 13))),
                        Text(Formatters.formatCurrency(entry.value),
                          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                        const SizedBox(width: 8),
                        Text('${percentage.toStringAsFixed(0)}%',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        minHeight: 4,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
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

  Widget _buildIncomeBreakdown(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Desglose de Ingresos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._incomeByType.entries.map((entry) {
              final percentage = _totalIncome > 0 ? (entry.value / _totalIncome * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward_rounded, size: 16, color: AppTheme.incomeColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 13))),
                    Text(Formatters.formatCurrency(entry.value),
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.incomeColor, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text('${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCashBankCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Efectivo y Banco',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildCashBankRow(
                  label: 'Efectivo',
                  income: _totalCashIncome,
                  expense: _totalCashExpense,
                  icon: Icons.money,
                  color: const Color(0xFF4CAF50),
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildCashBankRow(
                  label: 'Banco',
                  income: _totalBankIncome,
                  expense: _totalBankExpense,
                  icon: Icons.account_balance,
                  color: const Color(0xFF2196F3),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashBankRow({
    required String label,
    required double income,
    required double expense,
    required IconData icon,
    required Color color,
  }) {
    final balance = income - expense;
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_downward, size: 12, color: AppTheme.incomeColor),
            const SizedBox(width: 2),
            Text(Formatters.formatCurrency(income), style: TextStyle(fontSize: 11, color: AppTheme.incomeColor)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_upward, size: 12, color: AppTheme.expenseColor),
            const SizedBox(width: 2),
            Text(Formatters.formatCurrency(expense), style: TextStyle(fontSize: 11, color: AppTheme.expenseColor)),
          ],
        ),
        const SizedBox(height: 4),
        Text(Formatters.formatCurrency(balance),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
            color: balance >= 0 ? const Color(0xFF4CAF50) : Colors.red)),
      ],
    );
  }

  Widget _buildBalanceEvolutionChart(ColorScheme colorScheme, List<double> cumulative, List<MapEntry<DateTime, double>> incomeData) {
    if (cumulative.isEmpty) return const SizedBox();
    const monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

    final spots = <FlSpot>[];
    double minVal = 0;
    double maxVal = 0;
    for (int i = 0; i < cumulative.length; i++) {
      spots.add(FlSpot(i.toDouble(), cumulative[i]));
      if (cumulative[i] < minVal) minVal = cumulative[i];
      if (cumulative[i] > maxVal) maxVal = cumulative[i];
    }
    final padding = (maxVal - minVal) * 0.2;
    final minY = minVal - padding;
    final maxY = maxVal + padding;

    final isWeekly = widget.reportType == 'weekly';
    final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Evolución del Balance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFF4CAF50),
                      barWidth: 2,
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      ),
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (isWeekly) {
                            if (idx >= 0 && idx < days.length) return Text(days[idx], style: const TextStyle(fontSize: 10));
                          } else {
                            if (idx >= 0 && idx < 12) return Text(monthNames[idx], style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(Formatters.formatCurrency(value), style: const TextStyle(fontSize: 9));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY - minY) / 4,
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 0,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsInfo(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ahorro y Redistribución',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _InfoRow(label: 'Presupuesto de ahorro', value: _distribution!.savingsBudget, color: const Color(0xFF4CAF50)),
            _InfoRow(label: 'Ahorro acumulado', value: _distribution!.savings, color: const Color(0xFF4CAF50)),
            if (_totalRedistributed > 0)
              _InfoRow(label: 'Total redistribuido', value: _totalRedistributed, color: const Color(0xFF2196F3)),
            const SizedBox(height: 8),
            ...(_distribution!.userCategories.where((c) => c.totalRedistributionReceived > 0).map((cat) =>
              _InfoRow(
                label: '${cat.name} recibió',
                value: cat.totalRedistributionReceived,
                color: const Color(0xFF2196F3),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _getColor(String name) {
    final colors = [
      const Color(0xFF2196F3), const Color(0xFFFF9800), const Color(0xFF9C27B0),
      const Color(0xFFE53935), const Color(0xFF00BCD4), const Color(0xFFFF5722),
      const Color(0xFF607D8B), const Color(0xFF795548),
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(Formatters.formatCurrency(amount),
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(Formatters.formatCurrency(value),
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
