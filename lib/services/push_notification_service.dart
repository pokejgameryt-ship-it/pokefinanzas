import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreference {
  final String id;
  final String title;
  final String description;
  final bool isEnabled;
  final String category;

  const NotificationPreference({
    required this.id,
    required this.title,
    required this.description,
    this.isEnabled = true,
    required this.category,
  });

  NotificationPreference copyWith({bool? isEnabled}) {
    return NotificationPreference(
      id: id,
      title: title,
      description: description,
      isEnabled: isEnabled ?? this.isEnabled,
      category: category,
    );
  }
}

class PushNotificationService {
  static const String _prefix = 'notif_pref_';
  static bool _initialized = false;

  static final List<NotificationPreference> defaultPreferences = [
    // Budget notifications
    NotificationPreference(
      id: 'budget_alert',
      title: 'Alertas de presupuesto',
      description: 'Aviso cuando un categoría se acerca al límite (80%)',
      category: 'Presupuesto',
    ),
    NotificationPreference(
      id: 'budget_exceeded',
      title: 'Presupuesto superado',
      description: 'Aviso cuando se supera el presupuesto de una categoría',
      category: 'Presupuesto',
    ),
    
    // Savings notifications
    NotificationPreference(
      id: 'savings_goal_reached',
      title: 'Meta de ahorro alcanzada',
      description: 'Aviso cuando alcanzas una meta de ahorro',
      category: 'Ahorro',
    ),
    NotificationPreference(
      id: 'savings_goal_reminder',
      title: 'Recordatorio de meta',
      description: 'Recordatorio mensual del progreso de tus metas',
      category: 'Ahorro',
    ),
    
    // Recurring payment notifications
    NotificationPreference(
      id: 'recurring_payment_due',
      title: 'Pago recurrente próximo',
      description: 'Aviso 3 días antes de un pago recurrente',
      category: 'Pagos',
    ),
    NotificationPreference(
      id: 'recurring_payment_day',
      title: 'Día de pago recurrente',
      description: 'Aviso el día del pago recurrente',
      category: 'Pagos',
    ),
    
    // Goal payment notifications
    NotificationPreference(
      id: 'goal_payment_due',
      title: 'Pago de meta próximo',
      description: 'Aviso cuando vence un pago de compra a plazos',
      category: 'Metas',
    ),
    NotificationPreference(
      id: 'goal_payment_overdue',
      title: 'Pago de meta vencido',
      description: 'Aviso cuando un pago de meta está atrasado',
      category: 'Metas',
    ),
    
    // Reports
    NotificationPreference(
      id: 'monthly_report',
      title: 'Informe mensual',
      description: 'Recordatorio para revisar tu informe mensual',
      category: 'Informes',
    ),
    NotificationPreference(
      id: 'weekly_summary',
      title: 'Resumen semanal',
      description: 'Resumen de gastos de la semana',
      category: 'Informes',
    ),
    
    // General
    NotificationPreference(
      id: 'daily_reminder',
      title: 'Recordatorio diario',
      description: 'Recordatorio para registrar gastos del día',
      category: 'General',
    ),
    
    // Local payment reminders
    NotificationPreference(
      id: 'payment_reminders_enabled',
      title: 'Recordatorios de pago locales',
      description: 'Alertas automáticas para pagos recurrentes y metas próximas',
      category: 'Pagos',
    ),
  ];

  static Future<void> initialize() async {
    if (_initialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Initialize default preferences if not set
    for (final pref in defaultPreferences) {
      final key = '$_prefix${pref.id}';
      if (prefs.getBool(key) == null) {
        await prefs.setBool(key, pref.isEnabled);
      }
    }
    
    _initialized = true;
  }

  static Future<bool> isEnabled(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$id') ?? true;
  }

  static Future<void> setEnabled(String id, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$id', enabled);
  }

  static Future<List<NotificationPreference>> getAllPreferences() async {
    await initialize();
    
    final prefs = await SharedPreferences.getInstance();
    return defaultPreferences.map((pref) {
      final enabled = prefs.getBool('$_prefix${pref.id}') ?? pref.isEnabled;
      return pref.copyWith(isEnabled: enabled);
    }).toList();
  }

  static Future<Map<String, List<NotificationPreference>>> getPreferencesByCategory() async {
    final all = await getAllPreferences();
    final grouped = <String, List<NotificationPreference>>{};
    
    for (final pref in all) {
      grouped.putIfAbsent(pref.category, () => []).add(pref);
    }
    
    return grouped;
  }

  static Future<void> toggleAll(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    for (final pref in defaultPreferences) {
      await prefs.setBool('$_prefix${pref.id}', enabled);
    }
  }

  static Future<int> getEnabledCount() async {
    final all = await getAllPreferences();
    return all.where((p) => p.isEnabled).length;
  }

  // Check and trigger notifications based on current data
  static Future<List<String>> checkNotifications({
    required double totalSpent,
    required double monthlyIncome,
    required List<Map<String, dynamic>> goalsWithPayments,
  }) async {
    final notifications = <String>[];
    
    // Budget alerts
    if (await isEnabled('budget_alert') && monthlyIncome > 0) {
      final percentage = (totalSpent / monthlyIncome * 100);
      if (percentage >= 80 && percentage < 100) {
        notifications.add('⚠️ Has gastado el ${percentage.toStringAsFixed(0)}% de tus ingresos este mes');
      }
    }
    
    if (await isEnabled('budget_exceeded') && monthlyIncome > 0) {
      if (totalSpent > monthlyIncome) {
        notifications.add('🚨 ¡Has superado tus ingresos este mes!');
      }
    }
    
    // Goal payment due notifications
    if (await isEnabled('goal_payment_due')) {
      final now = DateTime.now();
      for (final goalData in goalsWithPayments) {
        final nextDate = goalData['nextPaymentDate'] as DateTime?;
        if (nextDate != null) {
          final daysUntil = nextDate.difference(now).inDays;
          if (daysUntil <= 3 && daysUntil >= 0) {
            notifications.add('📅 Tienes un pago pendiente en ${goalData['name']} en $daysUntil días');
          }
          if (daysUntil < 0) {
            notifications.add('⏰ Pago atrasado en ${goalData['name']} (${daysUntil.abs()} días)');
          }
        }
      }
    }
    
    return notifications;
  }
}
