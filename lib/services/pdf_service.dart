import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/daily_income.dart';
import '../models/expense.dart';
import '../models/goal.dart';
import '../services/database_service.dart';

import 'pdf_service_stub.dart'
    if (dart.library.io) 'pdf_service_io.dart';

class PdfService {
  static final _db = DatabaseService.instance;

  static String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'es_ES', symbol: 'EUR', decimalDigits: 2);
    return formatter.format(amount);
  }

  static String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
  static String _formatDateShort(DateTime date) => DateFormat('dd/MM').format(date);
  static String _formatTime(DateTime date) => DateFormat('HH:mm').format(date);

  static String _getIncomeTypeLabel(String type) {
    switch (type) {
      case 'hourly': return 'Por horas';
      case 'recurring': return 'Recurrente';
      default: return 'Fijo';
    }
  }

  // Light professional theme
  static final PdfColor _bg = PdfColor.fromHex('#FFFFFF');
  static final PdfColor _cardBg = PdfColor.fromHex('#F7F8FA');
  static final PdfColor _cardBorder = PdfColor.fromHex('#E0E3E8');
  static final PdfColor _textPrimary = PdfColor.fromHex('#1A1D21');
  static final PdfColor _textSecondary = PdfColor.fromHex('#5F6B7A');
  static final PdfColor _textMuted = PdfColor.fromHex('#9BA3AF');
  static final PdfColor _green = PdfColor.fromHex('#22C55E');
  static final PdfColor _greenDark = PdfColor.fromHex('#16A34A');
  static final PdfColor _red = PdfColor.fromHex('#EF4444');
  static final PdfColor _redDark = PdfColor.fromHex('#DC2626');
  static final PdfColor _blue = PdfColor.fromHex('#3B82F6');
  static final PdfColor _teal = PdfColor.fromHex('#14B8A6');
  static final PdfColor _accent = PdfColor.fromHex('#6366F1');
  static final PdfColor _border = PdfColor.fromHex('#E5E7EB');
  static final PdfColor _gridLine = PdfColor.fromHex('#E8E8E8');

  static Future<pw.Document> generateCustomRangeReport({
    required DateTime startDate,
    required DateTime endDate,
    bool includeComparison = true,
    bool includeGoalsSummary = true,
  }) async {
    final pdf = pw.Document();

    final allIncomes = await _db.getAllIncomes();
    final allExpenses = await _db.getAllExpenses();
    final goals = await _db.getAllGoals();

    final incomes = allIncomes.where((i) =>
        i.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
        i.date.isBefore(endDate.add(const Duration(days: 1)))).toList();
    final expenses = allExpenses.where((e) =>
        e.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
        e.date.isBefore(endDate.add(const Duration(days: 1)))).toList();

    double totalIncome = 0;
    for (final i in incomes) { totalIncome += i.totalAmount; }
    double totalExpenses = 0;
    for (final e in expenses) { totalExpenses += e.amount; }
    final balance = totalIncome - totalExpenses;
    final savingsRate = totalIncome > 0 ? (balance / totalIncome * 100) : 0.0;

    final periodDays = endDate.difference(startDate).inDays + 1;
    final prevEndDate = startDate.subtract(const Duration(days: 1));
    final prevStartDate = prevEndDate.subtract(Duration(days: periodDays - 1));
    final prevIncomes = allIncomes.where((i) =>
        i.date.isAfter(prevStartDate.subtract(const Duration(days: 1))) &&
        i.date.isBefore(prevEndDate.add(const Duration(days: 1)))).toList();
    final prevExpenses = allExpenses.where((e) =>
        e.date.isAfter(prevStartDate.subtract(const Duration(days: 1))) &&
        e.date.isBefore(prevEndDate.add(const Duration(days: 1)))).toList();
    double prevTotalIncome = 0;
    for (final i in prevIncomes) { prevTotalIncome += i.totalAmount; }
    double prevTotalExpenses = 0;
    for (final e in prevExpenses) { prevTotalExpenses += e.amount; }

    final Map<String, double> expensesByCategory = {};
    for (final e in expenses) {
      expensesByCategory[e.category] = (expensesByCategory[e.category] ?? 0) + e.amount;
    }
    final sortedCategories = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sortedDates = <DateTime>[];
    for (int i = 0; i <= periodDays; i++) {
      final d = startDate.add(Duration(days: i));
      sortedDates.add(DateTime(d.year, d.month, d.day));
    }
    final Map<DateTime, double> dailyIncome = {};
    final Map<DateTime, double> dailyExpenses = {};
    for (final d in sortedDates) { dailyIncome[d] = 0; dailyExpenses[d] = 0; }
    for (final i in incomes) {
      final dk = DateTime(i.date.year, i.date.month, i.date.day);
      dailyIncome[dk] = (dailyIncome[dk] ?? 0) + i.totalAmount;
    }
    for (final e in expenses) {
      final dk = DateTime(e.date.year, e.date.month, e.date.day);
      dailyExpenses[dk] = (dailyExpenses[dk] ?? 0) + e.amount;
    }

    // Cumulative balance: running total of (income - expenses) over time
    final cumulativeBalance = <double>[];
    double runningBalance = 0;
    for (final d in sortedDates) {
      runningBalance += (dailyIncome[d] ?? 0) - (dailyExpenses[d] ?? 0);
      cumulativeBalance.add(runningBalance);
    }

    final sortedDailyExpenses = dailyExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3Days = sortedDailyExpenses.take(3).where((e) => e.value > 0).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 20),
        header: (context) => _buildHeader(startDate, endDate),
        footer: (context) => _buildFooter(),
        build: (context) => [
          _buildKpiRow(totalIncome, totalExpenses, balance, savingsRate),
          pw.SizedBox(height: 16),
          _card([
            _buildRealLineChart('Ingresos Diarios', dailyIncome, sortedDates, _green),
          ]),
          pw.SizedBox(height: 10),
          _card([
            _buildRealLineChart('Gastos Diarios', dailyExpenses, sortedDates, _red),
          ]),
          pw.SizedBox(height: 10),
          _card([
            _buildCumulativeBalanceChart(sortedDates, cumulativeBalance),
          ]),
          if (includeComparison && prevTotalIncome > 0) ...[
            pw.SizedBox(height: 10),
            _card([
              _buildComparison(totalIncome, totalExpenses, balance, prevTotalIncome, prevTotalExpenses),
            ]),
          ],
          if (sortedCategories.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _card([
              _buildCategoryLineChart(sortedCategories, totalExpenses),
            ]),
          ],
          if (top3Days.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _card([
              _buildTop3(top3Days, expenses),
            ]),
          ],
          pw.SizedBox(height: 10),
          _card([
            _buildIncomeTable(incomes),
          ]),
          pw.SizedBox(height: 10),
          _card([
            _buildExpenseTable(expenses),
          ]),
          if (includeGoalsSummary && goals.any((g) => g.isActive && !g.isCompleted)) ...[
            pw.SizedBox(height: 10),
            _card([
              _buildGoals(goals.where((g) => g.isActive && !g.isCompleted).toList()),
            ]),
          ],
        ],
      ),
    );

    return pdf;
  }

  // === CARD WRAPPER ===
  static pw.Widget _card(List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _cardBg,
        border: pw.Border.all(color: _cardBorder, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // === HEADER ===
  static pw.Widget _buildHeader(DateTime startDate, DateTime endDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Informe Financiero', style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold, color: _textPrimary)),
              pw.SizedBox(height: 3),
              pw.Text('${_formatDate(startDate)} - ${_formatDate(endDate)}',
                  style: pw.TextStyle(fontSize: 10, color: _textSecondary)),
            ],
          ),
          pw.Text('Generado: ${_formatDate(DateTime.now())}',
              style: pw.TextStyle(fontSize: 8, color: _textMuted)),
        ],
      ),
    );
  }

  // === FOOTER ===
  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.5)),
      ),
      child: pw.Text('Finanzas App',
          style: pw.TextStyle(fontSize: 7, color: _textMuted),
          textAlign: pw.TextAlign.center),
    );
  }

  // === KPI ROW ===
  static pw.Widget _buildKpiRow(double income, double expenses, double balance, double savingsRate) {
    return pw.Row(children: [
      _kpiCard('Ingresos', _formatCurrency(income), _green),
      pw.SizedBox(width: 6),
      _kpiCard('Gastos', _formatCurrency(expenses), _red),
      pw.SizedBox(width: 6),
      _kpiCard('Balance', _formatCurrency(balance), balance >= 0 ? _blue : _red),
      pw.SizedBox(width: 6),
      _kpiCard('Tasa Ahorro', '${savingsRate.toStringAsFixed(2)}%', _teal),
    ]);
  }

  static pw.Widget _kpiCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _cardBorder, width: 0.5),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label.toUpperCase(), style: pw.TextStyle(
                fontSize: 7, fontWeight: pw.FontWeight.bold, color: _textMuted)),
            pw.SizedBox(height: 5),
            pw.Text(value, style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // === Nice axis values (round numbers as guides) ===
  static List<double> _niceAxisValues(double maxVal, {bool symmetric = false, int targetTicks = 5}) {
    if (maxVal <= 0) return [0.0];
    // Find a nice step size (1, 2, 5, 10, 20, 50, 100, 200, 500...)
    final roughStep = maxVal / targetTicks;
    final mag = (roughStep == 0) ? 1 : (math.pow(10, (math.log(roughStep) / math.log(10)).floor())).toDouble();
    final normalized = roughStep / mag;
    double niceStep;
    if (normalized <= 1.0) {
      niceStep = 1.0 * mag;
    } else if (normalized <= 2.0) {
      niceStep = 2.0 * mag;
    } else if (normalized <= 5.0) {
      niceStep = 5.0 * mag;
    } else {
      niceStep = 10.0 * mag;
    }

    final niceMax = (maxVal / niceStep).ceil() * niceStep;
    final values = <double>[];
    for (double v = 0; v <= niceMax + niceStep * 0.01; v += niceStep) {
      values.add(double.parse(v.toStringAsFixed(10)));
    }
    if (symmetric) {
      final negatives = values.where((v) => v > 0).map((v) => -v).toList().reversed.toList();
      return [...negatives, ...values];
    }
    return values;
  }

  // === Split peaks into two sets for alternating top/bottom labels ===
  static List<List<int>> _splitPeaks(List<double> values) {
    final indices = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (values[i] > 0) indices.add(i);
    }
    final a = <int>[];
    final b = <int>[];
    for (int i = 0; i < indices.length; i++) {
      if (i % 2 == 0) {
        a.add(indices[i]);
      } else {
        b.add(indices[i]);
      }
    }
    return [a, b];
  }

  // === REAL LINE CHART using pdf built-in Chart widget ===
  static pw.Widget _buildRealLineChart(
      String title, Map<DateTime, double> data, List<DateTime> dates, PdfColor color) {
    final values = dates.map((d) => data[d] ?? 0).toList();
    final maxVal = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          pw.SizedBox(height: 10),
          pw.Text('Sin datos en este periodo', style: pw.TextStyle(color: _textMuted, fontSize: 9)),
        ],
      );
    }

    final chartData = <pw.PointChartValue>[];
    for (int i = 0; i < values.length; i++) {
      chartData.add(pw.PointChartValue(i.toDouble(), values[i]));
    }

    final xStep = dates.length > 8 ? (dates.length / 6).ceil() : 1;
    final xLabels = <String>[];
    for (int i = 0; i < dates.length; i++) {
      xLabels.add(i % xStep == 0 ? _formatDateShort(dates[i]) : '');
    }

    final yMax = maxVal > 0 ? maxVal * 1.15 : maxVal;
    final yValues = _niceAxisValues(yMax);

    final peakSplit = _splitPeaks(values);
    final peakA = peakSplit[0].map((i) => pw.PointChartValue(i.toDouble(), values[i])).toList();
    final peakB = peakSplit[1].map((i) => pw.PointChartValue(i.toDouble(), values[i])).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        pw.SizedBox(height: 10),
        pw.SizedBox(
          height: 180,
          child: pw.Chart(
          grid: pw.CartesianGrid(
          xAxis: pw.FixedAxis(
            List.generate(dates.length, (i) => i),
            format: (v) => xLabels[v.toInt()],
            textStyle: pw.TextStyle(fontSize: 6, color: _textMuted),
            margin: 15,
            divisions: true,
            divisionsColor: _gridLine,
            divisionsDashed: true,
          ),
          yAxis: pw.FixedAxis(
            yValues,
            format: (v) => _formatCurrency(v.toDouble()),
            textStyle: pw.TextStyle(fontSize: 6, color: _textMuted),
            divisions: true,
            divisionsColor: _gridLine,
            divisionsDashed: true,
          ),
        ),
        datasets: [
          pw.LineDataSet(
            data: chartData,
            color: color,
            lineColor: color,
            lineWidth: 2,
            drawLine: true,
            drawPoints: false,
          ),
          if (peakA.isNotEmpty)
            pw.LineDataSet(
              data: peakA,
              color: color,
              lineColor: color,
              lineWidth: 0,
              drawLine: false,
              drawPoints: true,
              pointSize: 4,
              pointColor: color,
              valuePosition: pw.ValuePosition.top,
              buildValue: (context, value) => pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(_formatCurrency(value.y),
                    style: pw.TextStyle(fontSize: 5, color: _textSecondary, fontWeight: pw.FontWeight.bold)),
              ),
            ),
          if (peakB.isNotEmpty)
            pw.LineDataSet(
              data: peakB,
              color: color,
              lineColor: color,
              lineWidth: 0,
              drawLine: false,
              drawPoints: true,
              pointSize: 4,
              pointColor: color,
              valuePosition: pw.ValuePosition.top,
              buildValue: (context, value) => pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(_formatCurrency(value.y),
                    style: pw.TextStyle(fontSize: 5, color: _textSecondary, fontWeight: pw.FontWeight.bold)),
              ),
            ),
        ],
        ),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  // === CUMULATIVE BALANCE CHART ===
  static pw.Widget _buildCumulativeBalanceChart(List<DateTime> dates, List<double> cumulativeBalance) {
    if (cumulativeBalance.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Evolucion del Balance'),
          pw.SizedBox(height: 10),
          pw.Text('Sin datos en este periodo', style: pw.TextStyle(color: _textMuted, fontSize: 9)),
        ],
      );
    }

    final maxVal = cumulativeBalance.reduce((a, b) => a > b ? a : b);
    final minVal = cumulativeBalance.reduce((a, b) => a < b ? a : b);
    final absMax = [maxVal.abs(), minVal.abs()].reduce((a, b) => a > b ? a : b);
    if (absMax == 0) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Evolucion del Balance'),
          pw.SizedBox(height: 10),
          pw.Text('Sin datos en este periodo', style: pw.TextStyle(color: _textMuted, fontSize: 9)),
        ],
      );
    }

    final chartData = <pw.PointChartValue>[];
    for (int i = 0; i < cumulativeBalance.length; i++) {
      chartData.add(pw.PointChartValue(i.toDouble(), cumulativeBalance[i]));
    }

    final xStep = dates.length > 8 ? (dates.length / 6).ceil() : 1;
    final xLabels = <String>[];
    for (int i = 0; i < dates.length; i++) {
      xLabels.add(i % xStep == 0 ? _formatDateShort(dates[i]) : '');
    }

    // Y axis: nice round numbers
    List<double> yValues;
    if (minVal < 0) {
      yValues = _niceAxisValues(absMax, symmetric: true);
    } else {
      yValues = _niceAxisValues(maxVal);
    }

    // Find peak indices: first, last, min, max (with min distance filter)
    final peakCandidates = <int>{0, cumulativeBalance.length - 1};
    int minIdx = 0, maxIdx = 0;
    for (int i = 0; i < cumulativeBalance.length; i++) {
      if (cumulativeBalance[i] < cumulativeBalance[minIdx]) minIdx = i;
      if (cumulativeBalance[i] > cumulativeBalance[maxIdx]) maxIdx = i;
    }
    peakCandidates.add(minIdx);
    peakCandidates.add(maxIdx);

    final sortedPeaks = peakCandidates.toList()..sort();
    final peakA = <pw.PointChartValue>[];
    final peakB = <pw.PointChartValue>[];
    for (int i = 0; i < sortedPeaks.length; i++) {
      final idx = sortedPeaks[i];
      if (i % 2 == 0) {
        peakA.add(pw.PointChartValue(idx.toDouble(), cumulativeBalance[idx]));
      } else {
        peakB.add(pw.PointChartValue(idx.toDouble(), cumulativeBalance[idx]));
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Evolucion del Balance'),
        pw.SizedBox(height: 10),
        pw.SizedBox(
          height: 180,
          child: pw.Chart(
          grid: pw.CartesianGrid(
          xAxis: pw.FixedAxis(
            List.generate(dates.length, (i) => i),
            format: (v) => xLabels[v.toInt()],
            textStyle: pw.TextStyle(fontSize: 6, color: _textMuted),
            margin: 15,
            divisions: true,
            divisionsColor: _gridLine,
            divisionsDashed: true,
          ),
          yAxis: pw.FixedAxis(
            yValues,
            format: (v) => _formatCurrency(v.toDouble()),
            textStyle: pw.TextStyle(fontSize: 6, color: _textMuted),
            divisions: true,
            divisionsColor: _gridLine,
            divisionsDashed: true,
          ),
        ),
        datasets: [
          pw.LineDataSet(
            data: chartData,
            color: _teal,
            lineColor: _teal,
            lineWidth: 2,
            drawLine: true,
            drawPoints: false,
          ),
          if (peakA.isNotEmpty)
            pw.LineDataSet(
              data: peakA,
              color: _teal,
              lineColor: _teal,
              lineWidth: 0,
              drawLine: false,
              drawPoints: true,
              pointSize: 4,
              pointColor: _teal,
              valuePosition: pw.ValuePosition.top,
              buildValue: (context, value) => pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(_formatCurrency(value.y),
                    style: pw.TextStyle(fontSize: 5, color: _textSecondary, fontWeight: pw.FontWeight.bold)),
              ),
            ),
          if (peakB.isNotEmpty)
            pw.LineDataSet(
              data: peakB,
              color: _teal,
              lineColor: _teal,
              lineWidth: 0,
              drawLine: false,
              drawPoints: true,
              pointSize: 4,
              pointColor: _teal,
              valuePosition: pw.ValuePosition.top,
              buildValue: (context, value) => pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(_formatCurrency(value.y),
                    style: pw.TextStyle(fontSize: 5, color: _textSecondary, fontWeight: pw.FontWeight.bold)),
              ),
            ),
        ],
        ),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  // === CATEGORY LINE CHART ===
  static pw.Widget _buildCategoryLineChart(List<MapEntry<String, double>> cats, double total) {
    final sortedTop = cats.take(10).toList();
    final values = sortedTop.map((e) => e.value).toList();
    final labels = sortedTop.map((e) => e.key).toList();
    final maxVal = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return pw.SizedBox();

    // Single category: show as simple row
    if (sortedTop.length == 1) {
      final pct = total > 0 ? (values[0] / total * 100) : 0;
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Gastos por Categoria'),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Text(labels[0],
                  style: pw.TextStyle(fontSize: 10, color: _textPrimary, fontWeight: pw.FontWeight.bold))),
              pw.Text(_formatCurrency(values[0]),
                  style: pw.TextStyle(fontSize: 10, color: _textSecondary, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 8),
              pw.Text('(${pct.toStringAsFixed(2)}%)',
                  style: pw.TextStyle(fontSize: 9, color: _textMuted)),
            ]),
          ),
        ],
      );
    }

    final chartData = <pw.PointChartValue>[];
    for (int i = 0; i < values.length; i++) {
      chartData.add(pw.PointChartValue(i.toDouble(), values[i]));
    }

    // Shorten labels for X axis
    final xLabels = <String>[];
    for (int i = 0; i < labels.length; i++) {
      final short = labels[i].length > 8 ? labels[i].substring(0, 8) : labels[i];
      xLabels.add(short);
    }

    final yMax = maxVal * 1.2;
    final yValues = _niceAxisValues(yMax);

    final peakSplit = _splitPeaks(values);
    final peakA = peakSplit[0].map((i) => pw.PointChartValue(i.toDouble(), values[i])).toList();
    final peakB = peakSplit[1].map((i) => pw.PointChartValue(i.toDouble(), values[i])).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Gastos por Categoria'),
        pw.SizedBox(height: 10),
        pw.SizedBox(
          height: 180,
          child: pw.Chart(
          grid: pw.CartesianGrid(
          xAxis: pw.FixedAxis(
            List.generate(labels.length, (i) => i),
            format: (v) => xLabels[v.toInt()],
            textStyle: pw.TextStyle(fontSize: 5, color: _textMuted),
            angle: 0,
            margin: 15,
            divisions: true,
            divisionsColor: _gridLine,
            divisionsDashed: true,
          ),
          yAxis: pw.FixedAxis(
            yValues,
            format: (v) => _formatCurrency(v.toDouble()),
            textStyle: pw.TextStyle(fontSize: 6, color: _textMuted),
            divisions: true,
            divisionsColor: _gridLine,
            divisionsDashed: true,
          ),
        ),
        datasets: [
          pw.LineDataSet(
            data: chartData,
            color: _blue,
            lineColor: _blue,
            lineWidth: 2,
            drawLine: true,
            drawPoints: false,
          ),
          if (peakA.isNotEmpty)
            pw.LineDataSet(
              data: peakA,
              color: _blue,
              lineColor: _blue,
              lineWidth: 0,
              drawLine: false,
              drawPoints: true,
              pointSize: 4,
              pointColor: _blue,
              valuePosition: pw.ValuePosition.top,
              buildValue: (context, value) {
                final pct = total > 0 ? (value.y / total * 100) : 0;
                return pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Column(children: [
                    pw.Text(_formatCurrency(value.y),
                        style: pw.TextStyle(fontSize: 5, color: _textSecondary, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${pct.toStringAsFixed(1)}%',
                        style: pw.TextStyle(fontSize: 4, color: _textMuted)),
                  ]),
                );
              },
            ),
          if (peakB.isNotEmpty)
            pw.LineDataSet(
              data: peakB,
              color: _blue,
              lineColor: _blue,
              lineWidth: 0,
              drawLine: false,
              drawPoints: true,
              pointSize: 4,
              pointColor: _blue,
              valuePosition: pw.ValuePosition.top,
              buildValue: (context, value) {
                final pct = total > 0 ? (value.y / total * 100) : 0;
                return pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(children: [
                    pw.Text(_formatCurrency(value.y),
                        style: pw.TextStyle(fontSize: 5, color: _textSecondary, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${pct.toStringAsFixed(1)}%',
                        style: pw.TextStyle(fontSize: 4, color: _textMuted)),
                  ]),
                );
              },
            ),
        ],
        ),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  // === COMPARISON ===
  static pw.Widget _buildComparison(
      double income, double expenses, double balance,
      double prevIncome, double prevExpenses) {
    final incChg = prevIncome > 0 ? ((income - prevIncome) / prevIncome * 100) : 0.0;
    final expChg = prevExpenses > 0 ? ((expenses - prevExpenses) / prevExpenses * 100) : 0.0;
    final prevBal = prevIncome - prevExpenses;
    final balChg = prevBal > 0 ? ((balance - prevBal) / prevBal * 100) : 0.0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Comparativa Periodo Anterior'),
        pw.SizedBox(height: 10),
        _compRow('Ingresos', income, prevIncome, incChg),
        pw.SizedBox(height: 6),
        _compRow('Gastos', expenses, prevExpenses, expChg),
        pw.SizedBox(height: 6),
        _compRow('Balance', balance, prevBal, balChg),
      ],
    );
  }

  static pw.Widget _compRow(String label, double current, double previous, double changePct) {
    final isIncrease = changePct > 0;
    final color = isIncrease ? _red : _green;
    final sign = isIncrease ? '+' : '';

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(children: [
        pw.SizedBox(width: 80, child: pw.Text(label,
            style: pw.TextStyle(fontSize: 9, color: _textPrimary, fontWeight: pw.FontWeight.bold))),
        pw.Expanded(child: pw.Text(_formatCurrency(current),
            style: pw.TextStyle(fontSize: 9, color: _textPrimary))),
        pw.Text('$sign${changePct.toStringAsFixed(2)}%',
            style: pw.TextStyle(fontSize: 9, color: color, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(width: 6),
        pw.Text('vs anterior',
            style: pw.TextStyle(fontSize: 7, color: _textMuted)),
      ]),
    );
  }

  // === TOP 3 WITH DETAILED EXPENSES ===
  static pw.Widget _buildTop3(List<MapEntry<DateTime, double>> top3, List<Expense> allExpenses) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Top 3 Dias de Mayor Gasto'),
        pw.SizedBox(height: 10),
        ...top3.asMap().entries.map((entry) {
          final i = entry.key;
          final dayEntry = entry.value;
          final dayDate = dayEntry.key;
          final dayTotal = dayEntry.value;

          final dayExpenses = allExpenses.where((e) =>
              e.date.year == dayDate.year &&
              e.date.month == dayDate.month &&
              e.date.day == dayDate.day).toList()
            ..sort((a, b) => b.amount.compareTo(a.amount));

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(children: [
                  pw.Container(
                    width: 28, height: 28,
                    decoration: pw.BoxDecoration(
                      color: _red,
                      borderRadius: pw.BorderRadius.circular(14),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text('${i + 1}', style: pw.TextStyle(
                        color: _bg, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(DateFormat('EEEE dd MMMM', 'es_ES').format(dayDate),
                          style: pw.TextStyle(fontSize: 9, color: _textPrimary, fontWeight: pw.FontWeight.bold)),
                      pw.Text(_formatDate(dayDate),
                          style: pw.TextStyle(fontSize: 7, color: _textMuted)),
                    ],
                  )),
                  pw.Text(_formatCurrency(dayTotal),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _redDark, fontSize: 11)),
                ]),
                pw.SizedBox(height: 8),
                ...dayExpenses.map((e) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    color: _bg,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  margin: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(e.category,
                              style: pw.TextStyle(fontSize: 8, color: _textPrimary, fontWeight: pw.FontWeight.bold)),
                          if (e.description != null && e.description!.isNotEmpty)
                            pw.Text(e.description!,
                                style: pw.TextStyle(fontSize: 7, color: _textMuted)),
                        ],
                      )),
                      pw.SizedBox(width: 8),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(_formatCurrency(e.amount),
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textPrimary)),
                          pw.Text('${_formatTime(e.date)} - ${e.isCash ? 'Efectivo' : 'Banco'}',
                              style: pw.TextStyle(fontSize: 6, color: _textMuted)),
                        ],
                      ),
                    ],
                  ),
                )),
              ],
            ),
          );
        }),
      ],
    );
  }

  // === INCOME TABLE ===
  static pw.Widget _buildIncomeTable(List<DailyIncome> incomes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Detalle de Ingresos'),
        pw.SizedBox(height: 10),
        if (incomes.isEmpty)
          pw.Text('No hay ingresos registrados.', style: pw.TextStyle(color: _textMuted, fontSize: 9))
        else
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: _textPrimary),
            cellStyle: pw.TextStyle(fontSize: 7, color: _textSecondary),
            headerDecoration: pw.BoxDecoration(color: _cardBorder),
            cellDecoration: (row, col, rowCount) => pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.3)),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(1.3),
              1: const pw.FlexColumnWidth(1.3),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(0.8),
              4: const pw.FlexColumnWidth(2),
            },
            headers: ['Fecha', 'Tipo', 'Cantidad', 'Recurrente', 'Notas'],
            data: incomes.map((i) => [
              _formatDate(i.date),
              _getIncomeTypeLabel(i.type),
              _formatCurrency(i.totalAmount),
              i.isRecurring ? 'Si' : 'No',
              i.notes ?? '-',
            ]).toList(),
          ),
      ],
    );
  }

  // === EXPENSE TABLE ===
  static pw.Widget _buildExpenseTable(List<Expense> expenses) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Detalle de Gastos'),
        pw.SizedBox(height: 10),
        if (expenses.isEmpty)
          pw.Text('No hay gastos registrados.', style: pw.TextStyle(color: _textMuted, fontSize: 9))
        else
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: _textPrimary),
            cellStyle: pw.TextStyle(fontSize: 7, color: _textSecondary),
            headerDecoration: pw.BoxDecoration(color: _cardBorder),
            cellDecoration: (row, col, rowCount) => pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.3)),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(1.3),
              1: const pw.FlexColumnWidth(1.3),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(2),
            },
            headers: ['Fecha', 'Categoria', 'Cantidad', 'Descripcion'],
            data: expenses.map((e) => [
              _formatDate(e.date),
              e.category,
              _formatCurrency(e.amount),
              e.description ?? '-',
            ]).toList(),
          ),
      ],
    );
  }

  // === GOALS ===
  static pw.Widget _buildGoals(List<Goal> activeGoals) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Metas Activas'),
        pw.SizedBox(height: 10),
        ...activeGoals.map((goal) {
          final progress = goal.progressPercentage;
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _cardBorder, width: 0.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(goal.name, style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11, color: _textPrimary)),
                    pw.Text('${progress.toStringAsFixed(2)}%',
                        style: pw.TextStyle(color: _teal, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  height: 8,
                  decoration: pw.BoxDecoration(
                    color: _cardBorder,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Container(
                      width: progress > 0 ? (progress / 100 * 400) : 2,
                      height: 8,
                      decoration: pw.BoxDecoration(
                        color: progress >= 100 ? _greenDark : _teal,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Ahorrado: ${_formatCurrency(goal.savedAmount)}',
                        style: pw.TextStyle(fontSize: 8, color: _textSecondary)),
                    pw.Text('Objetivo: ${_formatCurrency(goal.targetAmount)}',
                        style: pw.TextStyle(fontSize: 8, color: _textSecondary)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Text('Restante: ${_formatCurrency(goal.remainingAmount)}',
                    style: pw.TextStyle(fontSize: 8, color: _textMuted)),
                if (goal.hasFixedPayment && goal.nextPaymentDate != null) ...[
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: _bg,
                      border: pw.Border.all(color: _blue, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'Proximo pago: ${_formatDate(goal.nextPaymentDate!)} - ${_formatCurrency(goal.nextPaymentAmount ?? 0)}',
                      style: pw.TextStyle(fontSize: 8, color: _blue),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  // === HELPERS ===
  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 2)),
      ),
      child: pw.Text(title, style: pw.TextStyle(
          fontSize: 11, fontWeight: pw.FontWeight.bold, color: _textPrimary)),
    );
  }

  static Future<pw.Document> generateMonthlyReport(int month, int year) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);
    return generateCustomRangeReport(startDate: startDate, endDate: endDate,
        includeComparison: false, includeGoalsSummary: false);
  }

  static Future<String> savePdfToFile(pw.Document pdf, String fileName) async {
    final bytes = await pdf.save();
    return savePdfToNative(bytes, fileName);
  }

  static Future<void> sharePdf(pw.Document pdf, String fileName) async {
    final bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
