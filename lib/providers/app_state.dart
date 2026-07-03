import 'package:flutter/foundation.dart';
import '../models/daily_income.dart';
import '../models/expense.dart';
import '../models/savings_distribution.dart';
import '../services/database_service.dart';

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._init();
  AppState._init();

  final _db = DatabaseService.instance;

  List<DailyIncome> _incomes = [];
  List<Expense> _expenses = [];
  double _incomeTotal = 0;
  double _expenseTotal = 0;
  double _totalBalance = 0;
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = false;
  SavingsDistribution? _distribution;

  List<DailyIncome> get incomes => _incomes;
  List<Expense> get expenses => _expenses;
  double get incomeTotal => _incomeTotal;
  double get expenseTotal => _expenseTotal;
  double get totalBalance => _totalBalance;
  DateTime get selectedMonth => _selectedMonth;
  bool get isLoading => _isLoading;
  SavingsDistribution? get distribution => _distribution;
  double get balance => _incomeTotal - _expenseTotal;

  Future<void> loadData({int? month, int? year}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final m = month ?? _selectedMonth.month;
      final y = year ?? _selectedMonth.year;

      final results = await Future.wait([
        _db.getIncomesByMonth(m, y),
        _db.getExpensesByMonth(m, y),
        _db.getTotalBalance(),
        _db.getDistribution(m, y),
      ]);

      _incomes = results[0] as List<DailyIncome>;
      _expenses = results[1] as List<Expense>;
      _totalBalance = results[2] as double;
      _distribution = results[3] as SavingsDistribution?;

      _incomeTotal = 0;
      for (final i in _incomes) {
        _incomeTotal += i.totalAmount;
      }

      _expenseTotal = 0;
      for (final e in _expenses) {
        _expenseTotal += e.amount;
      }
    } catch (e) {
      debugPrint('Error loading app state: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSelectedMonth(DateTime month) async {
    _selectedMonth = month;
    await loadData(month: month.month, year: month.year);
  }

  Future<void> addIncome(DailyIncome income) async {
    await _db.insertIncome(income);
    await loadData();
  }

  Future<void> updateIncome(DailyIncome income) async {
    await _db.updateIncome(income);
    await loadData();
  }

  Future<void> deleteIncome(String id) async {
    await _db.deleteIncome(id);
    await loadData();
  }

  Future<void> addExpense(Expense expense) async {
    await _db.insertExpense(expense);
    await loadData();
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.updateExpense(expense);
    await loadData();
  }

  Future<void> deleteExpense(String id) async {
    await _db.deleteExpense(id);
    await loadData();
  }

  void reset() {
    _incomes = [];
    _expenses = [];
    _incomeTotal = 0;
    _expenseTotal = 0;
    _totalBalance = 0;
    _selectedMonth = DateTime.now();
    _distribution = null;
    notifyListeners();
  }
}
