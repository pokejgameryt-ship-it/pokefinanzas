import 'package:uuid/uuid.dart';
import '../models/app_notification.dart';
import '../utils/formatters.dart';
import 'database_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  NotificationService._init();

  final _db = DatabaseService.instance;

  Future<void> generateMonthlyReport(int month, int year) async {
    final monthNames = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final reportTitle = 'Informe Mensual - ${monthNames[month]} $year';

    final existing = await _db.getAllNotifications();
    final alreadyExists = existing.any(
      (n) => n.type == 'monthly_report' && n.title == reportTitle,
    );
    if (alreadyExists) return;

    final income = await _db.getTotalIncomeByMonth(month, year);
    final expenses = await _db.getTotalExpensesByMonth(month, year);
    final balance = income - expenses;

    double totalRedistributed = 0;
    final dist = await _db.getDistribution(month, year);
    if (dist != null) {
      for (final cat in dist.userCategories) {
        final unspent = dist.getCategoryUnspent(cat);
        if (unspent <= 0) continue;
        for (final entry in cat.redistributionPercentages.entries) {
          totalRedistributed += unspent * entry.value / 100;
        }
      }
    }

    final savingsBudget = dist?.savingsBudget ?? 0;

    final notif = AppNotification(
      id: const Uuid().v4(),
      title: 'Informe Mensual - ${monthNames[month]} $year',
      message:
          'Ingresos: ${Formatters.formatCurrency(income)} | '
          'Gastos: ${Formatters.formatCurrency(expenses)} | '
          'Balance: ${Formatters.formatCurrency(balance)} | '
          'Ahorro: ${Formatters.formatCurrency(savingsBudget)}'
          '${totalRedistributed > 0 ? ' | Redistribuido: ${Formatters.formatCurrency(totalRedistributed)}' : ''}',
      type: 'monthly_report',
      createdAt: DateTime.now(),
    );
    await _db.insertNotification(notif);
  }

  Future<void> generateWeeklyReport() async {
    final now = DateTime.now();
    final existing = await _db.getAllNotifications();
    final weekNumber = ((now.day - 1) ~/ 7) + 1;
    final reportTitle = 'Resumen Semanal - Semana $weekNumber';
    final alreadyExists = existing.any(
      (n) => n.type == 'weekly_report' && n.title == reportTitle,
    );
    if (alreadyExists) return;

    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    double weekIncome = 0;
    double weekExpenses = 0;
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      if (day.isAfter(now)) break;
      final dayIncomes = await _db.getIncomesByDate(day);
      for (final inc in dayIncomes) {
        weekIncome += inc.totalAmount;
      }
      final dayExpenses = await _db.getExpensesByDate(day);
      for (final exp in dayExpenses) {
        if (!exp.isTransfer) weekExpenses += exp.amount;
      }
    }

    final notif = AppNotification(
      id: const Uuid().v4(),
      title: 'Resumen Semanal - Semana $weekNumber',
      message:
          '${Formatters.formatDate(weekStart)} - ${Formatters.formatDate(weekEnd)}\n'
          'Ingresos: ${Formatters.formatCurrency(weekIncome)} | '
          'Gastos: ${Formatters.formatCurrency(weekExpenses)} | '
          'Balance: ${Formatters.formatCurrency(weekIncome - weekExpenses)}',
      type: 'weekly_report',
      createdAt: DateTime.now(),
    );
    await _db.insertNotification(notif);
  }

  Future<void> generateAnnualReport(int year) async {
    final existing = await _db.getAllNotifications();
    final alreadyExists = existing.any(
      (n) => n.type == 'annual_report' &&
          n.title.contains('$year'),
    );
    if (alreadyExists) return;

    double totalIncome = 0;
    double totalExpenses = 0;
    for (int m = 1; m <= 12; m++) {
      totalIncome += await _db.getTotalIncomeByMonth(m, year);
      totalExpenses += await _db.getTotalExpensesByMonth(m, year);
    }
    final balance = totalIncome - totalExpenses;

    final notif = AppNotification(
      id: const Uuid().v4(),
      title: 'Informe Anual - $year',
      message:
          'Ingresos totales: ${Formatters.formatCurrency(totalIncome)} | '
          'Gastos totales: ${Formatters.formatCurrency(totalExpenses)} | '
          'Balance: ${Formatters.formatCurrency(balance)}',
      type: 'annual_report',
      createdAt: DateTime.now(),
    );
    await _db.insertNotification(notif);
  }

  Future<void> generateSavingsAlert(int month, int year) async {
    final dist = await _db.getDistribution(month, year);
    if (dist == null) return;

    final savings = dist.savings;
    if (savings <= 0) return;

    final existing = await _db.getAllNotifications();
    final alreadyExists = existing.any(
      (n) => n.type == 'savings_alert' && n.title == 'Ahorro del Mes',
    );
    if (alreadyExists) return;

    final notif = AppNotification(
      id: const Uuid().v4(),
      title: 'Ahorro del Mes',
      message:
          'Tienes ${Formatters.formatCurrency(savings)} de ahorro sin redistribuir. '
          'Recuerda apartarlos en tu cuenta bancaria.',
      type: 'savings_alert',
      createdAt: DateTime.now(),
    );
    await _db.insertNotification(notif);
  }

  Future<void> generateBudgetAlert(
      String categoryName, double spent, double budget) async {
    final percentage = (spent / budget * 100).toStringAsFixed(0);

    final notif = AppNotification(
      id: const Uuid().v4(),
      title: 'Alerta de Presupuesto',
      message:
          'Has superado el límite de "$categoryName": ${Formatters.formatCurrency(spent)} de ${Formatters.formatCurrency(budget)} ($percentage%)',
      type: 'budget_alert',
      createdAt: DateTime.now(),
    );
    await _db.insertNotification(notif);
  }

  Future<void> checkBudgetAlerts(
      double spentAmount, double budgetAmount, String categoryName) async {
    if (budgetAmount <= 0) return;

    final now = DateTime.now();
    final percentage = spentAmount / budgetAmount * 100;

    final existing = await _db.getAllNotifications();
    final alreadyWarning = existing.any(
      (n) =>
          n.type == 'budget_warning' &&
          n.message.contains(categoryName) &&
          n.createdAt.month == now.month &&
          n.createdAt.year == now.year,
    );
    final alreadyExceeded = existing.any(
      (n) =>
          n.type == 'budget_exceeded' &&
          n.message.contains(categoryName) &&
          n.createdAt.month == now.month &&
          n.createdAt.year == now.year,
    );

    if (spentAmount > budgetAmount && !alreadyExceeded) {
      final notif = AppNotification(
        id: const Uuid().v4(),
        title: 'Presupuesto excedido',
        message:
            'El presupuesto de "$categoryName" ha sido superado: '
            '${Formatters.formatCurrency(spentAmount)} de ${Formatters.formatCurrency(budgetAmount)} '
            '(${percentage.toStringAsFixed(0)}%)',
        type: 'budget_exceeded',
        createdAt: DateTime.now(),
      );
      await _db.insertNotification(notif);
    } else if (percentage >= 90 && !alreadyWarning) {
      final notif = AppNotification(
        id: const Uuid().v4(),
        title: 'Alerta de presupuesto',
        message:
            'El presupuesto de "$categoryName" está al ${percentage.toStringAsFixed(0)}%: '
            '${Formatters.formatCurrency(spentAmount)} de ${Formatters.formatCurrency(budgetAmount)}',
        type: 'budget_warning',
        createdAt: DateTime.now(),
      );
      await _db.insertNotification(notif);
    }
  }

  Future<void> checkSavingsAlert(
      double currentSavings, double targetSavings) async {
    if (targetSavings <= 0) return;
    if (currentSavings < targetSavings) return;

    final now = DateTime.now();
    final existing = await _db.getAllNotifications();
    final alreadyExists = existing.any(
      (n) =>
          n.type == 'savings_goal_reached' &&
          n.createdAt.month == now.month &&
          n.createdAt.year == now.year,
    );
    if (alreadyExists) return;

    final notif = AppNotification(
      id: const Uuid().v4(),
      title: 'Meta de ahorro alcanzada',
      message:
          '¡Enhorabuena! Has alcanzado tu meta de ahorro: '
          '${Formatters.formatCurrency(currentSavings)} de ${Formatters.formatCurrency(targetSavings)}',
      type: 'savings_goal_reached',
      createdAt: DateTime.now(),
    );
    await _db.insertNotification(notif);
  }

  Future<void> checkAndGenerateNotifications() async {
    final now = DateTime.now();

    // Monthly report for the PREVIOUS month (completed month)
    final lastMonth = now.month == 1 ? 12 : now.month - 1;
    final lastYear = now.month == 1 ? now.year - 1 : now.year;
    await generateMonthlyReport(lastMonth, lastYear);

    // Weekly report (every Monday or first app open of the week)
    if (now.weekday == DateTime.monday) {
      await generateWeeklyReport();
    }

    // Annual report for previous year (only in January)
    if (now.month == DateTime.january) {
      await generateAnnualReport(now.year - 1);
    }

    // Savings alert from previous month
    await generateSavingsAlert(lastMonth, lastYear);

    // Budget exceeded alerts for current month
    final dist = await _db.getDistribution(now.month, now.year);
    if (dist != null) {
      for (final cat in dist.userCategories) {
        final budget = dist.getCategoryBudget(cat);
        if (budget > 0 && cat.spentAmount > budget) {
          await generateBudgetAlert(cat.name, cat.spentAmount, budget);
        }
      }
    }

    // Payment reminders for recurring expenses
    await checkRecurringPaymentReminders(now);
  }

  Future<void> checkRecurringPaymentReminders(DateTime now) async {
    final existing = await _db.getAllNotifications();

    // Check recurring expenses
    final recurringExpenses = await _db.getRecurringExpenses();
    for (final exp in recurringExpenses) {
      final dayOfMonth = exp.date.day;
      final currentDay = now.day;
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final targetDay = dayOfMonth.clamp(1, daysInMonth);

      final daysUntil = targetDay - currentDay;
      if (daysUntil > 0 && daysUntil <= 2) {
        final alreadyExists = existing.any(
          (n) =>
              n.type == 'recurring_expense_reminder' &&
              n.message.contains(exp.recurringName ?? exp.category) &&
              n.createdAt.month == now.month &&
              n.createdAt.year == now.year,
        );
        if (!alreadyExists) {
          final name = exp.recurringName ?? (exp.category.isNotEmpty ? exp.category : 'Gasto recurrente');
          final notif = AppNotification(
            id: const Uuid().v4(),
            title: 'Gasto próximo',
            message:
                '$name se cobrará en $daysUntil día${daysUntil > 1 ? 's' : ''}: '
                '${Formatters.formatCurrency(exp.amount)}',
            type: 'recurring_expense_reminder',
            createdAt: DateTime.now(),
          );
          await _db.insertNotification(notif);
        }
      }
    }

    // Check recurring incomes
    final recurringIncomes = await _db.getRecurringIncomes();
    for (final inc in recurringIncomes) {
      final dayOfMonth = inc.date.day;
      final currentDay = now.day;
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final targetDay = dayOfMonth.clamp(1, daysInMonth);

      final daysUntil = targetDay - currentDay;
      if (daysUntil > 0 && daysUntil <= 2) {
        final alreadyExists = existing.any(
          (n) =>
              n.type == 'recurring_income_reminder' &&
              n.message.contains(inc.recurringName ?? 'Ingreso recurrente') &&
              n.createdAt.month == now.month &&
              n.createdAt.year == now.year,
        );
        if (!alreadyExists) {
          final name = inc.recurringName ?? 'Ingreso recurrente';
          final notif = AppNotification(
            id: const Uuid().v4(),
            title: 'Ingreso próximo',
            message:
                '$name se ingresará en $daysUntil día${daysUntil > 1 ? 's' : ''}: '
                '${Formatters.formatCurrency(inc.totalAmount)}',
            type: 'recurring_income_reminder',
            createdAt: DateTime.now(),
          );
          await _db.insertNotification(notif);
        }
      }
    }
  }
}
