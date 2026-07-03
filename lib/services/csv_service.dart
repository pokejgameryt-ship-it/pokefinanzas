import 'dart:convert';
import '../models/daily_income.dart';
import '../models/expense.dart';

class CsvService {
  static String generateMonthlyCsv(List<DailyIncome> incomes, List<Expense> expenses) {
    final buffer = StringBuffer();
    buffer.writeln('Fecha,Tipo,Categoria,Descripcion,Cantidad');

    for (final income in incomes) {
      final date = '${income.date.day}/${income.date.month}/${income.date.year}';
      final description = _escapeCsv(income.notes ?? income.type);
      buffer.writeln('$date,Ingreso,$income.type,$description,${income.totalAmount}');
    }

    for (final expense in expenses) {
      final date = '${expense.date.day}/${expense.date.month}/${expense.date.year}';
      final description = _escapeCsv(expense.description ?? '');
      buffer.writeln('$date,Gasto,${expense.category},$description,${expense.amount}');
    }

    return buffer.toString();
  }

  static String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  static List<int> csvToBytes(String csv) {
    return utf8.encode(csv);
  }
}
