import 'package:flutter/material.dart';
import '../../utils/formatters.dart';
import '../../services/pdf_service.dart';
import '../../services/database_service.dart';
import '../../models/daily_income.dart';
import '../../models/expense.dart';

class ExportSummaryScreen extends StatefulWidget {
  const ExportSummaryScreen({super.key});

  @override
  State<ExportSummaryScreen> createState() => _ExportSummaryScreenState();
}

class _ExportSummaryScreenState extends State<ExportSummaryScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _includeComparison = true;
  bool _includeGoalsSummary = true;
  bool _isGenerating = false;

  final _db = DatabaseService.instance;
  List<DailyIncome> _incomes = [];
  List<Expense> _expenses = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final allIncomes = await _db.getAllIncomes();
    final allExpenses = await _db.getAllExpenses();
    setState(() {
      _incomes = allIncomes.where((i) =>
          i.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
          i.date.isBefore(_endDate.add(const Duration(days: 1)))).toList();
      _expenses = allExpenses.where((e) =>
          e.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
          e.date.isBefore(_endDate.add(const Duration(days: 1)))).toList();
    });
  }

  double get _totalIncome => _incomes.fold(0.0, (sum, i) => sum + i.totalAmount);
  double get _totalExpenses => _expenses.fold(0.0, (sum, e) => sum + e.amount);
  double get _balance => _totalIncome - _totalExpenses;

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
      _loadData();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      _loadData();
    }
  }

  Future<void> _generatePdf() async {
    setState(() => _isGenerating = true);

    try {
      final pdf = await PdfService.generateCustomRangeReport(
        startDate: _startDate,
        endDate: _endDate,
        includeComparison: _includeComparison,
        includeGoalsSummary: _includeGoalsSummary,
      );

      if (mounted) {
        final fileName = '${_startDate.day.toString().padLeft(2, '0')}${_startDate.month.toString().padLeft(2, '0')}${_startDate.year}_${_endDate.day.toString().padLeft(2, '0')}${_endDate.month.toString().padLeft(2, '0')}${_endDate.year}_Informe.pdf';
        await PdfService.sharePdf(pdf, fileName);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF generado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportar Resumen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date range selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rango de Fechas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectStartDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Desde', style: Theme.of(context).textTheme.bodySmall),
                              Text(Formatters.formatDate(_startDate)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectEndDate,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hasta', style: Theme.of(context).textTheme.bodySmall),
                              Text(Formatters.formatDate(_endDate)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Summary preview
          Card(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vista Previa',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _summaryRow('Ingresos totales', Formatters.formatCurrency(_totalIncome), Colors.green),
                  const SizedBox(height: 8),
                  _summaryRow('Gastos totales', Formatters.formatCurrency(_totalExpenses), Colors.red),
                  const SizedBox(height: 8),
                  _summaryRow('Balance', Formatters.formatCurrency(_balance),
                      _balance >= 0 ? Colors.green : Colors.red),
                  const Divider(height: 24),
                  _summaryRow('Movimientos', '${_incomes.length + _expenses.length}', null),
                  _summaryRow('Período', '${_endDate.difference(_startDate).inDays + 1} días', null),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Optional sections
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Secciones Opcionales',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Comparativa período anterior'),
                    subtitle: const Text('Muestra cambio porcentual vs período anterior'),
                    value: _includeComparison,
                    onChanged: (value) => setState(() => _includeComparison = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Resumen de metas activas'),
                    subtitle: const Text('Incluye progreso de tus metas de ahorro'),
                    value: _includeGoalsSummary,
                    onChanged: (value) => setState(() => _includeGoalsSummary = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // PDF contents info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'El informe PDF incluirá:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _contentItem(Icons.assessment, 'Resumen ejecutivo con totales'),
                  _contentItem(Icons.pie_chart, 'Gráfico de gastos por categoría'),
                  _contentItem(Icons.show_chart, 'Gráfico de ingresos diarios'),
                  _contentItem(Icons.bar_chart, 'Gráfico de gastos diarios'),
                  _contentItem(Icons.timeline, 'Gráfico de balance diario'),
                  _contentItem(Icons.table_chart, 'Tabla detallada de movimientos'),
                  _contentItem(Icons.trending_up, 'Top 3 días de mayor gasto'),
                  if (_includeComparison)
                    _contentItem(Icons.compare_arrows, 'Comparativa período anterior'),
                  if (_includeGoalsSummary)
                    _contentItem(Icons.flag, 'Resumen de metas activas'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Generate button
          FilledButton.icon(
            onPressed: _isGenerating ? null : _generatePdf,
            icon: _isGenerating
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: Text(_isGenerating ? 'Generando...' : 'Generar y Compartir PDF'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color? valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _contentItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }
}
