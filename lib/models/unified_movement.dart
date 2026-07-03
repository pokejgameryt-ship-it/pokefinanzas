import '../models/daily_income.dart';
import '../models/expense.dart';

class UnifiedMovement {
  final String id;
  final double amount;
  final String label;
  final String? subtitle;
  final DateTime date;
  final bool isIncome;
  final bool isRecurring;
  final String? recurringName;
  final DailyIncome? income;
  final Expense? expense;

  bool get isCash => income?.isCash ?? expense?.isCash ?? false;

  const UnifiedMovement({
    required this.id,
    required this.amount,
    required this.label,
    this.subtitle,
    required this.date,
    required this.isIncome,
    required this.isRecurring,
    this.recurringName,
    this.income,
    this.expense,
  });
}
