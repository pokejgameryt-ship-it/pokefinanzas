import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class PaymentReminderService {
  static final PaymentReminderService instance = PaymentReminderService._init();
  PaymentReminderService._init();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(settings);
    _initialized = true;
  }

  Future<void> checkAndScheduleReminders() async {
    if (!_initialized) await init();

    final prefs = await SharedPreferences.getInstance();
    final remindersEnabled = prefs.getBool('notif_pref_payment_reminders_enabled') ?? true;
    if (!remindersEnabled) return;

    final db = DatabaseService.instance;
    final now = DateTime.now();

    // Check recurring expenses
    final expenses = await db.getRecurringExpenses();
    for (final expense in expenses) {
      await _scheduleReminderForRecurring(
        name: expense.recurringName ?? expense.category,
        amount: expense.amount,
        dayOfMonth: expense.date.day,
        type: 'expense',
        lastChecked: prefs.getString('last_reminder_check_expense_${expense.id}'),
        prefs: prefs,
      );
    }

    // Check recurring incomes
    final incomes = await db.getRecurringIncomes();
    for (final income in incomes) {
      await _scheduleReminderForRecurring(
        name: income.recurringName ?? income.type,
        amount: income.totalAmount,
        dayOfMonth: income.date.day,
        type: 'income',
        lastChecked: prefs.getString('last_reminder_check_income_${income.id}'),
        prefs: prefs,
      );
    }

    // Check goals with payment plans
    final goals = await db.getAllGoals();
    for (final goal in goals) {
      if (goal.hasFixedPayment && goal.nextPaymentDate != null) {
        final daysUntil = goal.nextPaymentDate!.difference(now).inDays;
        if (daysUntil >= 0 && daysUntil <= 3) {
          await _showNotification(
            id: goal.id.hashCode,
            title: 'Pago pendiente: ${goal.name}',
            body: 'Tu pago de ${goal.name} vence en $daysUntil día(s). Importe: ${goal.paymentAmount?.toStringAsFixed(2) ?? "N/A"} EUR',
            type: 'goal_payment',
          );
        }
      }
    }

    // Check goals that are overdue
    for (final goal in goals) {
      if (goal.hasFixedPayment && goal.nextPaymentDate != null) {
        if (goal.nextPaymentDate!.isBefore(now)) {
          await _showNotification(
            id: goal.id.hashCode + 1000,
            title: 'Pago vencido: ${goal.name}',
            body: 'El pago de ${goal.name} está atrasado. Por favor, regístralo.',
            type: 'goal_overdue',
          );
        }
      }
    }

    // Save last check time
    await prefs.setString('last_reminder_check', now.toIso8601String());
  }

  Future<void> _scheduleReminderForRecurring({
    required String name,
    required double amount,
    required int dayOfMonth,
    required String type,
    String? lastChecked,
    required SharedPreferences prefs,
  }) async {
    final now = DateTime.now();
    final today = now.day;

    // Calculate next payment date
    int targetDay = dayOfMonth;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    if (targetDay > daysInMonth) targetDay = daysInMonth;

    final daysUntilPayment = targetDay - today;

    // Show reminder 1-2 days before
    if (daysUntilPayment >= 0 && daysUntilPayment <= 2) {
      final lastCheckKey = 'last_reminder_${type}_${name.hashCode}';
      final lastCheck = prefs.getString(lastCheckKey);
      final todayStr = '${now.year}-${now.month}-${now.day}';

      if (lastCheck != todayStr) {
        await _showNotification(
          id: name.hashCode + (type == 'expense' ? 0 : 5000),
          title: type == 'expense' ? 'Pago próximo: $name' : 'Ingreso próximo: $name',
          body: daysUntilPayment == 0
              ? 'Hoy toca $name - ${amount.toStringAsFixed(2)} EUR'
              : 'En $daysUntilPayment día(s) toca $name - ${amount.toStringAsFixed(2)} EUR',
          type: type == 'expense' ? 'recurring_expense_reminder' : 'recurring_income_reminder',
        );
        await prefs.setString(lastCheckKey, todayStr);
      }
    }
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String type,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'payment_reminders',
      'Recordatorios de pago',
      channelDescription: 'Notificaciones de pagos próximos y vencidos',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _notifications.show(id, title, body, details);
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  Future<List<UpcomingPayment>> getUpcomingPayments() async {
    final db = DatabaseService.instance;
    final now = DateTime.now();
    final payments = <UpcomingPayment>[];

    // Recurring expenses
    final expenses = await db.getRecurringExpenses();
    for (final e in expenses) {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      var targetDay = e.date.day > daysInMonth ? daysInMonth : e.date.day;
      var nextDate = DateTime(now.year, now.month, targetDay);
      if (nextDate.isBefore(now)) {
        nextDate = DateTime(now.year, now.month + 1, targetDay);
      }
      payments.add(UpcomingPayment(
        name: e.recurringName ?? e.category,
        amount: e.amount,
        date: nextDate,
        isExpense: true,
      ));
    }

    // Recurring incomes
    final incomes = await db.getRecurringIncomes();
    for (final i in incomes) {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      var targetDay = i.date.day > daysInMonth ? daysInMonth : i.date.day;
      var nextDate = DateTime(now.year, now.month, targetDay);
      if (nextDate.isBefore(now)) {
        nextDate = DateTime(now.year, now.month + 1, targetDay);
      }
      payments.add(UpcomingPayment(
        name: i.recurringName ?? i.type,
        amount: i.totalAmount,
        date: nextDate,
        isExpense: false,
      ));
    }

    // Goals with payment plans
    final goals = await db.getAllGoals();
    for (final g in goals) {
      if (g.hasFixedPayment && g.nextPaymentDate != null) {
        payments.add(UpcomingPayment(
          name: g.name,
          amount: g.paymentAmount ?? 0,
          date: g.nextPaymentDate!,
          isExpense: true,
          isGoal: true,
        ));
      }
    }

    payments.sort((a, b) => a.date.compareTo(b.date));
    return payments;
  }
}

class UpcomingPayment {
  final String name;
  final double amount;
  final DateTime date;
  final bool isExpense;
  final bool isGoal;

  UpcomingPayment({
    required this.name,
    required this.amount,
    required this.date,
    required this.isExpense,
    this.isGoal = false,
  });
}
