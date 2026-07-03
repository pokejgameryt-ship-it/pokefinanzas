import 'package:uuid/uuid.dart';
import '../models/daily_income.dart';
import '../models/expense.dart';

class ImportResult {
  final List<DailyIncome> incomes;
  final List<Expense> expenses;
  final List<String> errors;

  ImportResult({
    required this.incomes,
    required this.expenses,
    required this.errors,
  });

  int get totalRows => incomes.length + expenses.length;
  bool get hasErrors => errors.isNotEmpty;
}

class ImportService {
  static ImportResult importCsv(String csvContent) {
    final incomes = <DailyIncome>[];
    final expenses = <Expense>[];
    final errors = <String>[];

    final lines = csvContent.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) {
      errors.add('El archivo está vacío');
      return ImportResult(incomes: incomes, expenses: expenses, errors: errors);
    }

    int startIdx = 0;
    final firstLine = lines[0].toLowerCase();
    if (firstLine.contains('fecha') && firstLine.contains('tipo')) {
      startIdx = 1;
    }

    for (int i = startIdx; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = _parseCsvLine(line);
      if (parts.length < 5) {
        errors.add('Línea ${i + 1}: faltan columnas (esperado 5, encontrado ${parts.length})');
        continue;
      }

      final fechaStr = parts[0].trim();
      final tipo = parts[1].trim().toLowerCase();
      final categoria = parts[2].trim();
      final descripcion = parts[3].trim();
      final cantidadStr = parts[4].trim();

      final date = _parseDate(fechaStr);
      if (date == null) {
        errors.add('Línea ${i + 1}: fecha inválida "$fechaStr"');
        continue;
      }

      final amount = double.tryParse(cantidadStr.replaceAll(',', '.'));
      if (amount == null || amount <= 0) {
        errors.add('Línea ${i + 1}: cantidad inválida "$cantidadStr"');
        continue;
      }

      if (tipo == 'ingreso') {
        incomes.add(DailyIncome(
          id: const Uuid().v4(),
          date: date,
          totalAmount: amount,
          notes: descripcion.isNotEmpty ? descripcion : null,
          type: 'fixed',
        ));
      } else if (tipo == 'gasto') {
        expenses.add(Expense(
          id: const Uuid().v4(),
          amount: amount,
          category: categoria,
          date: date,
          description: descripcion.isNotEmpty ? descripcion : null,
        ));
      } else {
        errors.add('Línea ${i + 1}: tipo inválido "$tipo" (esperado "ingreso" o "gasto")');
      }
    }

    return ImportResult(incomes: incomes, expenses: expenses, errors: errors);
  }

  static DateTime? _parseDate(String dateStr) {
    final isoMatch = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(dateStr);
    if (isoMatch != null) {
      final year = int.tryParse(isoMatch.group(1)!);
      final month = int.tryParse(isoMatch.group(2)!);
      final day = int.tryParse(isoMatch.group(3)!);
      if (year != null && month != null && day != null &&
          month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    final euMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(dateStr);
    if (euMatch != null) {
      final day = int.tryParse(euMatch.group(1)!);
      final month = int.tryParse(euMatch.group(2)!);
      final year = int.tryParse(euMatch.group(3)!);
      if (day != null && month != null && year != null &&
          month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(c);
        }
      } else {
        if (c == '"') {
          inQuotes = true;
        } else if (c == ',') {
          result.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(c);
        }
      }
    }
    result.add(buffer.toString());
    return result;
  }
}
