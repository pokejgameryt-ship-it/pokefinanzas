import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/daily_income.dart';
import '../models/expense.dart';
import '../models/savings_distribution.dart';
import '../models/goal.dart';
import '../models/budget.dart';
import '../models/app_notification.dart';
import '../models/redistribution_config.dart';
import '../models/redistribution_preset.dart';
import 'database_service.dart';

class BackupData {
  final List<DailyIncome> incomes;
  final List<Expense> expenses;
  final List<SavingsDistribution> distributions;
  final List<Goal> goals;
  final List<Budget> budgets;
  final List<AppNotification> notifications;
  final List<RedistributionPreset> presets;

  BackupData({
    required this.incomes,
    required this.expenses,
    required this.distributions,
    required this.goals,
    required this.budgets,
    required this.notifications,
    required this.presets,
  });

  Map<String, dynamic> toMap() => {
    'exportedAt': DateTime.now().toIso8601String(),
    'version': 1,
    'incomes': incomes.map((i) => i.toMap()).toList(),
    'expenses': expenses.map((e) => e.toMap()).toList(),
    'distributions': distributions.map((d) => d.toMap()).toList(),
    'goals': goals.map((g) => g.toMap()).toList(),
    'budgets': budgets.map((b) => b.toMap()).toList(),
    'notifications': notifications.map((n) => n.toMap()).toList(),
    'presets': presets.map((p) => p.toMap()).toList(),
  };

  factory BackupData.fromMap(Map<String, dynamic> map) {
    final incomes = (map['incomes'] as List)
        .map((i) => DailyIncome.fromMap(Map<String, dynamic>.from(i))).toList();
    final expenses = (map['expenses'] as List)
        .map((e) => Expense.fromMap(Map<String, dynamic>.from(e))).toList();
    final distributions = (map['distributions'] as List)
        .map((d) => SavingsDistribution.fromMap(Map<String, dynamic>.from(d))).toList();
    final goals = (map['goals'] as List)
        .map((g) => Goal.fromMap(Map<String, dynamic>.from(g))).toList();
    final budgets = (map['budgets'] as List)
        .map((b) => Budget.fromMap(Map<String, dynamic>.from(b))).toList();
    final notifications = (map['notifications'] as List)
        .map((n) => AppNotification.fromMap(Map<String, dynamic>.from(n))).toList();
    final presets = (map['presets'] as List)
        .map((p) => RedistributionPreset.fromMap(Map<String, dynamic>.from(p))).toList();
    return BackupData(
      incomes: incomes,
      expenses: expenses,
      distributions: distributions,
      goals: goals,
      budgets: budgets,
      notifications: notifications,
      presets: presets,
    );
  }

  String toJson() => const JsonEncoder.withIndent('  ').convert(toMap());

  factory BackupData.fromJson(String json) =>
      BackupData.fromMap(jsonDecode(json));
}

class BackupService {
  static final _db = DatabaseService.instance;

  static Future<String> exportToJson() async {
    final results = await Future.wait([
      _db.getAllIncomes(),
      _db.getAllExpenses(),
      _db.getAllGoals(),
      _db.getAllNotifications(),
      _db.getRedistributionPresets(),
    ]);
    final data = BackupData(
      incomes: results[0] as List<DailyIncome>,
      expenses: results[1] as List<Expense>,
      distributions: [],
      goals: results[2] as List<Goal>,
      budgets: [],
      notifications: results[3] as List<AppNotification>,
      presets: results[4] as List<RedistributionPreset>,
    );
    return data.toJson();
  }

  static Future<int> importFromJson(String json) async {
    final data = BackupData.fromJson(json);
    int count = 0;

    for (final income in data.incomes) {
      await _db.insertIncome(income);
      count++;
    }
    for (final expense in data.expenses) {
      await _db.insertExpense(expense);
      count++;
    }
    for (final dist in data.distributions) {
      await _db.insertDistribution(dist);
      count++;
    }
    for (final goal in data.goals) {
      await _db.insertGoal(goal);
      count++;
    }
    for (final budget in data.budgets) {
      await _db.insertBudget(budget);
      count++;
    }
    for (final notif in data.notifications) {
      await _db.insertNotification(notif);
      count++;
    }
    for (final preset in data.presets) {
      await _db.insertRedistributionPreset(preset);
      count++;
    }

    return count;
  }
}
