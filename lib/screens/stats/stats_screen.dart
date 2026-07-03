import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/savings_distribution.dart';
import '../../providers/app_state.dart';
import '../../services/database_service.dart';
import '../../services/csv_service.dart';
import '../../utils/formatters.dart';
import '../../utils/theme.dart';

enum StatsPeriod { weekly, monthly, annual, general }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _db = DatabaseService.instance;
  bool _isLoading = true;

  double _totalIncome = 0;
  double _totalExpenses = 0;
  double _cashIncome = 0;
  double _cashExpenses = 0;
  double _bankIncome = 0;
  double _bankExpenses = 0;
  double _currentSavings = 0;
  double _totalSavings = 0;
  double _prevIncome = 0;
  double _prevExpenses = 0;
  double _prevSavings = 0;
  Map<String, double> _expensesByCategory = {};
  Map<String, Map<String, double>> _expensesBySubcategory = {};
  List<MapEntry<DateTime, double>> _monthlyIncome = [];
  List<MapEntry<DateTime, double>> _monthlyExpenses = [];
  List<MapEntry<DateTime, double>> _monthlySavingsChart = [];
  int _selectedMonths = 6;
  SavingsDistribution? _currentDistribution;
  StatsPeriod _selectedPeriod = StatsPeriod.monthly;
  bool _showBarChart = true;
  bool _showDistValues = true;

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
    final now = DateTime.now();

    // Load period-appropriate data
    double totalIncome, totalExpenses, prevIncome, prevExpenses;
    List<dynamic> expenses;
    List<dynamic> incomes;

    switch (_selectedPeriod) {
      case StatsPeriod.weekly:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final weekStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        totalIncome = await _db.getIncomesByDateRange(weekStart, now);
        totalExpenses = await _db.getExpensesByDateRange(weekStart, now);
        expenses = await _db.getExpensesByDate(now);
        incomes = await _db.getIncomesByDate(now);
        prevIncome = 0;
        prevExpenses = 0;
        break;
      case StatsPeriod.annual:
        final yearStart = DateTime(now.year, 1, 1);
        totalIncome = await _db.getIncomesByDateRange(yearStart, now);
        totalExpenses = await _db.getExpensesByDateRange(yearStart, now);
        expenses = await _db.getExpensesByMonth(now.month, now.year);
        incomes = await _db.getIncomesByMonth(now.month, now.year);
        final prevYear = now.year - 1;
        final prevYearStart = DateTime(prevYear, 1, 1);
        final prevYearEnd = DateTime(prevYear, 12, 31);
        prevIncome = await _db.getIncomesByDateRange(prevYearStart, prevYearEnd);
        prevExpenses = await _db.getExpensesByDateRange(prevYearStart, prevYearEnd);
        break;
      case StatsPeriod.general:
        totalIncome = 0;
        totalExpenses = 0;
        for (final i in await _db.getAllIncomes()) {
          totalIncome += i.totalAmount;
        }
        for (final e in await _db.getAllExpenses()) {
          if (!e.isTransfer) totalExpenses += e.amount;
        }
        expenses = await _db.getExpensesByMonth(now.month, now.year);
        incomes = await _db.getIncomesByMonth(now.month, now.year);
        prevIncome = 0;
        prevExpenses = 0;
        break;
      default: // monthly
        totalIncome = await _db.getTotalIncomeByMonth(now.month, now.year);
        totalExpenses = await _db.getTotalExpensesByMonth(now.month, now.year);
        expenses = await _db.getExpensesByMonth(now.month, now.year);
        incomes = await _db.getIncomesByMonth(now.month, now.year);
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        prevIncome = await _db.getTotalIncomeByMonth(prevMonth, prevYear);
        prevExpenses = await _db.getTotalExpensesByMonth(prevMonth, prevYear);
    }

    // Savings data
    final currentDist = await _db.getDistribution(now.month, now.year);
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevYear = now.month == 1 ? now.year - 1 : now.year;
    final previousDist = await _db.getDistribution(prevMonth, prevYear);
    final currentSavings = currentDist?.savings ?? 0;
    final prevSavings = previousDist?.savings ?? 0;
    final totalSavings = await _db.getTotalSavings();

    // Gastos por categoría (exclude transfers)
    final Map<String, double> byCategory = {};
    final Map<String, Map<String, double>> bySubcategory = {};
    for (final e in expenses) {
      if (e.isTransfer) continue;
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
      if (e.subcategory.isNotEmpty) {
        bySubcategory.putIfAbsent(e.category, () => {});
        bySubcategory[e.category]![e.subcategory] =
            (bySubcategory[e.category]![e.subcategory] ?? 0) + e.amount;
      }
    }

    // Datos mensuales (últimos N meses)
    final List<MapEntry<DateTime, double>> monthlyIncome = [];
    final List<MapEntry<DateTime, double>> monthlyExpenses = [];
    final List<MapEntry<DateTime, double>> monthlySavingsData = [];

    for (int i = _selectedMonths - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final inc = await _db.getTotalIncomeByMonth(month.month, month.year);
      final exp = await _db.getTotalExpensesByMonth(month.month, month.year);
      final dist = await _db.getDistribution(month.month, month.year);
      monthlyIncome.add(MapEntry(month, inc));
      monthlyExpenses.add(MapEntry(month, exp));
      monthlySavingsData.add(MapEntry(month, dist?.savings ?? 0));
    }

    // Cash/Bank split for the period
    double cashInc = 0, cashExp = 0, bankInc = 0, bankExp = 0;
    for (final e in expenses) {
      if (e.isTransfer) continue;
      if (e.isCash) cashExp += e.amount; else bankExp += e.amount;
    }
    for (final inc in incomes) {
      if (inc.isCash) cashInc += inc.totalAmount; else bankInc += inc.totalAmount;
    }

    setState(() {
      _totalIncome = totalIncome;
      _totalExpenses = totalExpenses;
      _currentSavings = currentSavings;
      _totalSavings = totalSavings;
      _prevIncome = prevIncome;
      _prevExpenses = prevExpenses;
      _prevSavings = prevSavings;
      _expensesByCategory = byCategory;
      _expensesBySubcategory = bySubcategory;
      _monthlyIncome = monthlyIncome;
      _monthlyExpenses = monthlyExpenses;
      _monthlySavingsChart = monthlySavingsData;
      _currentDistribution = currentDist;
      _cashIncome = cashInc;
      _cashExpenses = cashExp;
      _bankIncome = bankInc;
      _bankExpenses = bankExp;
      _isLoading = false;
    });
  }

  String _periodLabel(StatsPeriod p) {
    switch (p) {
      case StatsPeriod.weekly: return 'Semanal';
      case StatsPeriod.monthly: return 'Mensual';
      case StatsPeriod.annual: return 'Anual';
      case StatsPeriod.general: return 'General';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final balance = _totalIncome - _totalExpenses;
    final prevBalance = _prevIncome - _prevExpenses;
    final incomeChange = _totalIncome - _prevIncome;
    final expenseChange = _totalExpenses - _prevExpenses;
    final balanceChange = balance - prevBalance;
    final incomeChangePct = _prevIncome > 0 ? incomeChange / _prevIncome * 100 : 0.0;
    final expenseChangePct = _prevExpenses > 0 ? expenseChange / _prevExpenses * 100 : 0.0;
    final balanceChangePct = prevBalance != 0 ? balanceChange / prevBalance.abs() * 100 : 0.0;
    final savingsChange = _currentSavings - _prevSavings;
    final savingsChangePct = _prevSavings > 0 ? savingsChange / _prevSavings * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            onPressed: _exportCsv,
            icon: const Icon(Icons.file_download),
            tooltip: 'Exportar CSV',
          ),
          PopupMenuButton<int>(
            onSelected: (value) {
              setState(() => _selectedMonths = value);
              _loadData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 3, child: Text('Últimos 3 meses')),
              const PopupMenuItem(value: 6, child: Text('Últimos 6 meses')),
              const PopupMenuItem(value: 12, child: Text('Último año')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final p in StatsPeriod.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(_periodLabel(p)),
                              selected: _selectedPeriod == p,
                              onSelected: (_) {
                                setState(() => _selectedPeriod = p);
                                _loadData();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Resumen card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Resumen ${_periodLabel(_selectedPeriod).toLowerCase()}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryItem(
                                  label: 'Ingresos',
                                  amount: _totalIncome,
                                  color: AppTheme.incomeColor,
                                  icon: Icons.trending_up,
                                  change: _prevIncome > 0 ? incomeChangePct : null,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _SummaryItem(
                                  label: 'Gastos',
                                  amount: _totalExpenses,
                                  color: AppTheme.expenseColor,
                                  icon: Icons.trending_down,
                                  change: _prevExpenses > 0 ? expenseChangePct : null,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _SummaryItem(
                                  label: 'Balance',
                                  amount: balance,
                                  color: balance >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor,
                                  icon: balance >= 0 ? Icons.account_balance_wallet : Icons.warning,
                                  change: prevBalance != 0 ? balanceChangePct : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryItem(
                                  label: 'Efectivo',
                                  amount: _cashIncome - _cashExpenses,
                                  color: Colors.orange,
                                  icon: Icons.money_rounded,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _SummaryItem(
                                  label: 'Banco',
                                  amount: _bankIncome - _bankExpenses,
                                  color: Colors.blue,
                                  icon: Icons.account_balance_rounded,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _SummaryItem(
                                  label: 'Ahorro',
                                  amount: _currentSavings,
                                  color: const Color(0xFF4CAF50),
                                  icon: Icons.savings,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Chart type toggle
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _showBarChart = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _showBarChart ? colorScheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bar_chart, size: 18,
                                      color: _showBarChart ? colorScheme.onPrimary : colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 6),
                                  Text('Barras',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                                        color: _showBarChart ? colorScheme.onPrimary : colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _showBarChart = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_showBarChart ? colorScheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.show_chart, size: 18,
                                      color: !_showBarChart ? colorScheme.onPrimary : colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 6),
                                  Text('Líneas',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                                        color: !_showBarChart ? colorScheme.onPrimary : colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Chart
                  if (_showBarChart) ...[
                    Text('Evolución Mensual',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(height: 220, child: _buildBarChart()),
                  ] else ...[
                    Text('Tendencia',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(height: 220, child: _buildLineChart(colorScheme)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ChartLegend(color: AppTheme.incomeColor, label: 'Ingresos'),
                        const SizedBox(width: 16),
                        _ChartLegend(color: AppTheme.expenseColor, label: 'Gastos'),
                        const SizedBox(width: 16),
                        _ChartLegend(color: colorScheme.primary, label: 'Balance'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Monthly comparison card
                  if (_prevIncome > 0 || _prevExpenses > 0) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Comparativa',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Período actual vs anterior',
                                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                            const SizedBox(height: 12),
                            _ComparisonRow(label: 'Ingresos', current: _totalIncome, previous: _prevIncome,
                                changeAbs: incomeChange, changePct: incomeChangePct,
                                icon: Icons.arrow_downward_rounded, positiveIsGreen: true),
                            const SizedBox(height: 8),
                            _ComparisonRow(label: 'Gastos', current: _totalExpenses, previous: _prevExpenses,
                                changeAbs: expenseChange, changePct: expenseChangePct,
                                icon: Icons.arrow_upward_rounded, positiveIsGreen: false),
                            const SizedBox(height: 8),
                            _ComparisonRow(label: 'Balance', current: balance, previous: prevBalance,
                                changeAbs: balanceChange, changePct: balanceChangePct,
                                icon: balance >= 0 ? Icons.trending_up : Icons.trending_down, positiveIsGreen: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Expense pie chart
                  if (_expensesByCategory.isNotEmpty) ...[
                    Text('Gastos por Categoría',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(height: 200, child: _buildPieChart(colorScheme)),
                    const SizedBox(height: 12),
                    ..._expensesByCategory.entries.map((entry) {
                      final color = _categoryColors[entry.key] ?? Colors.grey;
                      final pct = _totalExpenses > 0 ? entry.value / _totalExpenses * 100 : 0.0;
                      final subcats = _expensesBySubcategory[entry.key];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(width: 14, height: 14,
                                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                                const SizedBox(width: 8),
                                Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 13))),
                                Text(Formatters.formatCurrency(entry.value),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                                const SizedBox(width: 6),
                                Text('${pct.toStringAsFixed(1)}%',
                                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
                              ],
                            ),
                            if (subcats != null && subcats.isNotEmpty)
                              ...subcats.entries.map((sub) {
                                final subPct = entry.value > 0 ? sub.value / entry.value * 100 : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 22, top: 1),
                                  child: Row(
                                    children: [
                                      Icon(Icons.circle, size: 6, color: color.withValues(alpha: 0.6)),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(sub.key,
                                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)))),
                                      Text(Formatters.formatCurrency(sub.value),
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color.withValues(alpha: 0.8))),
                                      const SizedBox(width: 6),
                                      Text('${subPct.toStringAsFixed(0)}%',
                                          style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],

                  // Distribution pie chart
                  if (_currentDistribution != null && _currentDistribution!.userCategories.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text('Distribución del Presupuesto',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _showDistValues = !_showDistValues),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_showDistValues ? 'Mostrar %' : 'Mostrar €',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                    color: colorScheme.onPrimaryContainer)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(height: 200, child: _buildDistributionPieChart(colorScheme)),
                    const SizedBox(height: 12),
                    ..._buildDistributionLegend(colorScheme),
                    if (_currentDistribution!.savingsBudget > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(width: 14, height: 14,
                                decoration: BoxDecoration(color: const Color(0xFF4CAF50), borderRadius: BorderRadius.circular(3))),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Ahorro', style: TextStyle(fontSize: 13))),
                            Text(Formatters.formatCurrency(_currentDistribution!.savingsBudget),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50), fontSize: 13)),
                            const SizedBox(width: 6),
                            Text('${(_distTotalWithSavings > 0 ? _currentDistribution!.savingsBudget / _distTotalWithSavings * 100 : 0).toStringAsFixed(1)}%',
                                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
            ),
    );
  }

  Widget _buildBarChart() {
    if (_monthlyIncome.isEmpty) return const SizedBox();

    final groups = <BarChartGroupData>[];
    double maxY = 0;

    for (int i = 0; i < _monthlyIncome.length; i++) {
      final inc = _monthlyIncome[i].value;
      final exp = _monthlyExpenses[i].value;
      if (inc > maxY) maxY = inc;
      if (exp > maxY) maxY = exp;
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: inc,
            color: AppTheme.incomeColor,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
          BarChartRodData(
            toY: exp,
            color: AppTheme.expenseColor,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      ));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.25,
        barGroups: groups,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < _monthlyIncome.length) {
                  final d = _monthlyIncome[i].key;
                  final label = d.month == 1 ? '${_getMonthName(d.month)} ${d.year.toString().substring(2)}'
                      : _getMonthName(d.month);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label, style: const TextStyle(fontSize: 9)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                return Text(Formatters.formatCurrency(value), style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }

  Widget _buildLineChart(ColorScheme colorScheme) {
    if (_monthlyIncome.isEmpty) return const SizedBox();

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    final balanceSpots = <FlSpot>[];
    double maxY = 0, minY = 0;

    for (int i = 0; i < _monthlyIncome.length; i++) {
      final inc = _monthlyIncome[i].value;
      final exp = _monthlyExpenses[i].value;
      final bal = inc - exp;
      incomeSpots.add(FlSpot(i.toDouble(), inc));
      expenseSpots.add(FlSpot(i.toDouble(), exp));
      balanceSpots.add(FlSpot(i.toDouble(), bal));
      if (inc > maxY) maxY = inc;
      if (exp > maxY) maxY = exp;
      if (bal > maxY) maxY = bal;
      if (bal < minY) minY = bal;
    }

    final absMax = maxY.abs() > minY.abs() ? maxY.abs() : minY.abs();
    final paddedMax = absMax * 1.3;

    return LineChart(
      LineChartData(
        minY: -paddedMax,
        maxY: paddedMax,
        lineBarsData: [
          LineChartBarData(
            spots: incomeSpots,
            isCurved: false,
            color: AppTheme.incomeColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: expenseSpots,
            isCurved: false,
            color: AppTheme.expenseColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
          LineChartBarData(
            spots: balanceSpots,
            isCurved: false,
            color: colorScheme.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            dashArray: [5, 5],
            belowBarData: BarAreaData(show: false),
          ),
        ],
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < _monthlyIncome.length) {
                  final d = _monthlyIncome[i].key;
                  final label = d.month == 1 ? '${_getMonthName(d.month)} ${d.year.toString().substring(2)}'
                      : _getMonthName(d.month);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label, style: const TextStyle(fontSize: 9)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                return Text(Formatters.formatCurrency(value), style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: absMax > 0 ? absMax / 4 : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(ColorScheme colorScheme) {
    if (_expensesByCategory.isEmpty) return const SizedBox();

    final sections = _expensesByCategory.entries.map((entry) {
      final color = _categoryColors[entry.key] ?? Colors.grey;
      return PieChartSectionData(
        value: entry.value,
        color: color,
        title: _showDistValues
            ? Formatters.formatCurrency(entry.value)
            : '${(entry.value / _totalExpenses * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildDistributionPieChart(ColorScheme colorScheme) {
    if (_currentDistribution == null) return const SizedBox();

    final seen = <String>{};
    final deduped = <DistributionCategory>[];
    for (final cat in _currentDistribution!.userCategories) {
      if (seen.add(cat.name)) {
        deduped.add(cat);
      }
    }

    final total = _distTotalWithSavings;
    if (total <= 0 || deduped.isEmpty) return const SizedBox();

    final sections = <PieChartSectionData>[];

    for (final cat in deduped) {
      final budget = _currentDistribution!.getCategoryBudget(cat);
      if (budget <= 0) continue;
      final color = _categoryColors[cat.name] ?? _getDistributionColor(cat.name);
      sections.add(PieChartSectionData(
        value: budget,
        color: color,
        title: _showDistValues
            ? Formatters.formatCurrency(budget)
            : '${(budget / total * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 80,
      ));
    }

    if (_currentDistribution!.savingsBudget > 0) {
      sections.add(PieChartSectionData(
        value: _currentDistribution!.savingsBudget,
        color: const Color(0xFF4CAF50),
        title: _showDistValues
            ? Formatters.formatCurrency(_currentDistribution!.savingsBudget)
            : '${(total > 0 ? _currentDistribution!.savingsBudget / total * 100 : 0).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 80,
      ));
    }

    if (sections.isEmpty) return const SizedBox();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 30,
        sectionsSpace: 2,
      ),
    );
  }

  List<Widget> _buildDistributionLegend(ColorScheme colorScheme) {
    if (_currentDistribution == null) return [];

    final seen = <String>{};
    final deduped = <DistributionCategory>[];
    for (final cat in _currentDistribution!.userCategories) {
      if (seen.add(cat.name)) {
        deduped.add(cat);
      }
    }

    final total = _distTotalWithSavings;
    final list = <Widget>[];

    for (final cat in deduped) {
      final budget = _currentDistribution!.getCategoryBudget(cat);
      if (budget <= 0) continue;
      final pct = total > 0 ? budget / total * 100 : 0.0;
      final color = _categoryColors[cat.name] ?? _getDistributionColor(cat.name);
      list.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(width: 14, height: 14,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Text(cat.name, style: const TextStyle(fontSize: 13))),
            Text(Formatters.formatCurrency(budget),
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            const SizedBox(width: 6),
            Text('${pct.toStringAsFixed(1)}%',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
          ],
        ),
      ));
    }

    return list;
  }

  double get _distTotalWithSavings {
    if (_currentDistribution == null) return 0;
    final seen = <String>{};
    double total = 0;
    for (final cat in _currentDistribution!.userCategories) {
      if (!seen.add(cat.name)) continue;
      final b = _currentDistribution!.getCategoryBudget(cat);
      if (b > 0) total += b;
    }
    if (_currentDistribution!.savingsBudget > 0) total += _currentDistribution!.savingsBudget;
    return total;
  }

  Color _getDistributionColor(String name) {
    const colors = [
      Color(0xFF2196F3), Color(0xFFFF9800), Color(0xFF9C27B0),
      Color(0xFFE53935), Color(0xFF00BCD4), Color(0xFFFF5722),
      Color(0xFF607D8B), Color(0xFF795548), Color(0xFFCDDC39),
      Color(0xFF3F51B5),
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  String _getMonthName(int month) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return months[month - 1];
  }

  Future<void> _exportCsv() async {
    final now = DateTime.now();
    final incomes = await _db.getIncomesByMonth(now.month, now.year);
    final expenses = await _db.getExpensesByMonth(now.month, now.year);
    final csv = CsvService.generateMonthlyCsv(incomes, expenses);
    await Clipboard.setData(ClipboardData(text: csv));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV copiado al portapapeles (${_getMonthName(now.month)} ${now.year})'),
        ),
      );
    }
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final double? change;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.change,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = change != null && change! > 0;
    final isNegative = change != null && change! < 0;

    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(Formatters.formatCurrency(amount),
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
        if (change != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isPositive ? Icons.arrow_upward : (isNegative ? Icons.arrow_downward : Icons.remove),
                  size: 10,
                  color: isPositive ? AppTheme.incomeColor : (isNegative ? AppTheme.expenseColor : Colors.grey)),
              const SizedBox(width: 1),
              Text('${change!.abs().toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 9,
                      color: isPositive ? AppTheme.incomeColor : (isNegative ? AppTheme.expenseColor : Colors.grey))),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final double current;
  final double previous;
  final double changeAbs;
  final double changePct;
  final IconData icon;
  final bool positiveIsGreen;

  const _ComparisonRow({
    required this.label,
    required this.current,
    required this.previous,
    required this.changeAbs,
    required this.changePct,
    required this.icon,
    required this.positiveIsGreen,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = changeAbs > 0;
    final isNegative = changeAbs < 0;
    final changeColor = positiveIsGreen
        ? (isPositive ? AppTheme.incomeColor : (isNegative ? AppTheme.expenseColor : Colors.grey))
        : (isPositive ? AppTheme.expenseColor : (isNegative ? AppTheme.incomeColor : Colors.grey));
    final arrowIcon = isPositive ? Icons.arrow_upward : (isNegative ? Icons.arrow_downward : Icons.remove);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: changeColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${Formatters.formatCurrency(previous)} → ${Formatters.formatCurrency(current)}',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(arrowIcon, size: 12, color: changeColor),
                  const SizedBox(width: 2),
                  Text('${changeAbs >= 0 ? '+' : ''}${Formatters.formatCurrency(changeAbs)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: changeColor)),
                ],
              ),
              Text('${changePct >= 0 ? '+' : ''}${changePct.abs().toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: changeColor)),
            ],
          ),
        ],
      ),
    );
  }
}
