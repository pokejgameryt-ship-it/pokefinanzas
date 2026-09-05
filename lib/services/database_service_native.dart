import 'package:uuid/uuid.dart';
import '../models/daily_income.dart';
import '../models/expense.dart';
import '../models/savings_distribution.dart';
import '../models/product.dart';
import '../models/product_group.dart';
import '../models/goal.dart';
import '../models/budget.dart';
import '../models/app_notification.dart';
import '../models/subcategory.dart';
import '../models/redistribution_config.dart';
import '../models/redistribution_preset.dart';
import '../models/category_model.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import 'payment_reminder_service.dart';
import 'database_service_stub.dart';

class DatabaseService implements DatabaseServiceInterface {
  static final DatabaseService instance = DatabaseService._init();
  DatabaseService._init();

  static void init() {}

  final List<dynamic> _pendingSaves = [];

  Future<void> _retryPendingSaves() async {
    final pending = List<dynamic>.from(_pendingSaves);
    _pendingSaves.clear();
    for (final item in pending) {
      if (item is DailyIncome) {
        final alreadyLoaded = _incomes.any((i) => i.id == item.id);
        final ok = await FirebaseService.saveIncome(item);
        if (!ok) {
          _pendingSaves.add(item);
        } else if (!alreadyLoaded) {
          _incomes.add(item);
        }
      } else if (item is Expense) {
        final alreadyLoaded = _expenses.any((e) => e.id == item.id);
        final ok = await FirebaseService.saveExpense(item);
        if (!ok) {
          _pendingSaves.add(item);
        } else if (!alreadyLoaded) {
          _expenses.add(item);
        }
      } else if (item is AppNotification) {
        final alreadyLoaded = _notifications.any((n) => n.id == item.id);
        final ok = await FirebaseService.saveNotification(item);
        if (!ok) {
          _pendingSaves.add(item);
        } else if (!alreadyLoaded) {
          _notifications.add(item);
        }
      }
    }
  }

  @override
  Future<void> resetForNewUser() async {
    _incomes.clear();
    _expenses.clear();
    _products.clear();
    _groups.clear();
    _distributions.clear();
    _goals.clear();
    _notifications.clear();
    _budgets.clear();
    _subcategories.clear();
    _globalRedistributionDay = 1;
    _redistributionEnabled = true;
    _redistributionConfigs.clear();
    _redistributionPresets.clear();
  }

  @override
  Future<void> syncFromFirebase() async {
    await loadAllFromFirebase();
  }

  // === INCOMES ===
  final List<DailyIncome> _incomes = [];

  @override
  Future<void> insertIncome(DailyIncome income) async {
    _incomes.removeWhere((i) => i.id == income.id);
    _incomes.add(income);
    final saved = await FirebaseService.saveIncome(income);
    if (!saved) {
      _pendingSaves.add(income);
    }
  }

  @override
  Future<List<DailyIncome>> getIncomesByMonth(int month, int year) async {
    return _incomes.where((i) => i.date.month == month && i.date.year == year).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<List<DailyIncome>> getAllIncomes() async {
    return List<DailyIncome>.from(_incomes)..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<double> getTotalIncomeAll() async {
    double total = 0;
    for (final i in _incomes) {
      if (i.type == 'cajero') continue;
      total += i.totalAmount;
    }
    return total;
  }

  Future<double> getTotalExpensesAll() async {
    double total = 0;
    for (final e in _expenses) {
      if (e.isTransfer) continue;
      if (e.category == 'Cajero') continue;
      total += e.amount;
    }
    return total;
  }

  @override
  Future<List<DailyIncome>> getIncomesByDate(DateTime date) async {
    return _incomes.where((i) =>
        i.date.year == date.year && i.date.month == date.month && i.date.day == date.day).toList();
  }

  @override
  Future<double> getTotalIncomeByMonth(int month, int year) async {
    double total = 0;
    for (final i in await getIncomesByMonth(month, year)) {
      if (i.type == 'cajero') continue;
      total += i.totalAmount;
    }
    return total;
  }

  @override
  Future<double> getIncomesByDateRange(DateTime from, DateTime to) async {
    double total = 0;
    for (final i in _incomes) {
      if (i.type == 'cajero') continue;
      if (i.date.isAfter(from.subtract(const Duration(days: 1))) &&
          i.date.isBefore(to.add(const Duration(days: 1)))) {
        total += i.totalAmount;
      }
    }
    return total;
  }

  @override
  Future<void> deleteIncome(String id) async {
    _incomes.removeWhere((i) => i.id == id);
    await FirebaseService.deleteIncome(id);
  }

  @override
  Future<void> updateIncome(DailyIncome income) async {
    _incomes.removeWhere((i) => i.id == income.id);
    _incomes.add(income);
    await FirebaseService.saveIncome(income);
  }

  @override
  Future<List<DailyIncome>> getRecurringIncomes() async {
    return _incomes.where((i) => i.isRecurring).toList();
  }

  // === EXPENSES ===
  final List<Expense> _expenses = [];

  @override
  Future<void> insertExpense(Expense expense) async {
    _expenses.removeWhere((e) => e.id == expense.id);
    _expenses.add(expense);
    final saved = await FirebaseService.saveExpense(expense);
    if (!saved) {
      _pendingSaves.add(expense);
    }
  }

  @override
  Future<List<Expense>> getExpensesByMonth(int month, int year) async {
    return _expenses.where((e) => e.date.month == month && e.date.year == year).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<List<Expense>> getAllExpenses() async {
    return List<Expense>.from(_expenses)..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<List<Expense>> getExpensesByDate(DateTime date) async {
    return _expenses.where((e) =>
        e.date.year == date.year && e.date.month == date.month && e.date.day == date.day).toList();
  }

  @override
  Future<double> getTotalExpensesByMonth(int month, int year) async {
    double total = 0;
    for (final e in await getExpensesByMonth(month, year)) {
      if (e.isTransfer) continue;
      if (e.category == 'Cajero') continue;
      total += e.amount;
    }
    return total;
  }

  @override
  Future<double> getExpensesByDateRange(DateTime from, DateTime to) async {
    double total = 0;
    for (final e in _expenses) {
      if (e.isTransfer) continue;
      if (e.category == 'Cajero') continue;
      if (e.date.isAfter(from.subtract(const Duration(days: 1))) &&
          e.date.isBefore(to.add(const Duration(days: 1)))) {
        total += e.amount;
      }
    }
    return total;
  }

  Future<List<Expense>> getExpenseListByDateRange(DateTime from, DateTime to) async {
    return _expenses.where((e) {
      if (e.isTransfer) return false;
      if (e.category == 'Cajero') return false;
      return e.date.isAfter(from.subtract(const Duration(days: 1))) &&
          e.date.isBefore(to.add(const Duration(days: 1)));
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    await FirebaseService.deleteExpense(id);
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    _expenses.removeWhere((e) => e.id == expense.id);
    _expenses.add(expense);
    await FirebaseService.saveExpense(expense);
  }

  @override
  Future<List<Expense>> getRecurringExpenses() async {
    return _expenses.where((e) => e.isRecurring).toList();
  }

  // === DISTRIBUTIONS ===
  final List<SavingsDistribution> _distributions = [];

  @override
  Future<void> insertDistribution(SavingsDistribution distribution) async {
    _distributions.removeWhere((d) => d.month == distribution.month && d.year == distribution.year);
    _distributions.add(distribution);
    await FirebaseService.saveDistribution(distribution);
  }

  @override
  Future<SavingsDistribution?> getDistribution(int month, int year) async {
    try {
      return _distributions.firstWhere((d) => d.month == month && d.year == year);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateDistribution(SavingsDistribution distribution) async {
    _distributions.removeWhere((d) => d.month == distribution.month && d.year == distribution.year);
    _distributions.add(distribution);
    await FirebaseService.saveDistribution(distribution);
  }

  @override
  Future<List<DistributionCategory>> getDistributionCategories(int month, int year) async {
    final dist = await getDistribution(month, year);
    return dist?.categories ?? [];
  }

  @override
  Future<SavingsDistribution?> getPreviousMonthDistribution(int currentMonth, int currentYear) async {
    final prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;
    final prevYear = currentMonth == 1 ? currentYear - 1 : currentYear;
    return getDistribution(prevMonth, prevYear);
  }

  @override
  Future<double> calculateRedistributionForMonth(int currentMonth, int currentYear) async {
    final prevDist = await getPreviousMonthDistribution(currentMonth, currentYear);
    if (prevDist == null || prevDist.monthlyIncome <= 0) return 0;
    double total = 0;
    for (final cat in prevDist.categories) {
      if (cat.isAutomatic) {
        if (cat.redistributionPercentages.isEmpty) continue;
        final unspent = prevDist.getCategoryUnspentBase(cat);
        if (unspent <= 0) continue;
        final config = _redistributionConfigs[cat.name];
        final percentages = config?.redistributionPercentages.isNotEmpty == true
            ? config!.redistributionPercentages
            : cat.redistributionPercentages;
        for (final entry in percentages.entries) {
          total += unspent * entry.value / 100;
        }
      } else {
        if (!cat.isEnabled) continue;
        final unspent = prevDist.getCategoryUnspentBase(cat);
        if (unspent <= 0) continue;
        final config = _redistributionConfigs[cat.name];
        final percentages = config?.redistributionPercentages.isNotEmpty == true
            ? config!.redistributionPercentages
            : (cat.redistributionPercentages.isNotEmpty
                ? cat.redistributionPercentages
                : {cat.name: 100.0});
        for (final entry in percentages.entries) {
          total += unspent * entry.value / 100;
        }
      }
    }
    return total;
  }

  // === BALANCE ===
  @override
  Future<double> getTotalBalance() async {
    double income = 0;
    for (final i in _incomes) {
      if (i.isCashTransfer) continue;
      income += i.totalAmount;
    }
    double expenses = 0;
    for (final e in _expenses) {
      if (e.isCashTransfer) continue;
      expenses += e.amount;
    }
    return income - expenses;
  }

  @override
  Future<double> getTotalSavings() async {
    double total = 0;
    for (final d in _distributions) {
      total += d.savings;
    }
    return total;
  }

  @override
  Future<double> getTotalCashIncome() async {
    double total = 0;
    for (final i in _incomes) {
      if (i.isCashTransfer) {
        // ATM transfer to cash counts for cash balance
        if (i.isCash) total += i.totalAmount;
        continue;
      }
      if (i.isCash) total += i.totalAmount;
    }
    return total;
  }

  @override
  Future<double> getTotalCashExpense() async {
    double total = 0;
    for (final e in _expenses) {
      if (e.isTransfer) continue;
      if (e.isCashTransfer) {
        // ATM withdrawal to cash counts for cash balance
        if (e.isCash) total += e.amount;
        continue;
      }
      if (e.isCash) total += e.amount;
    }
    return total;
  }

  @override
  Future<double> getTotalBankIncome() async {
    double total = 0;
    for (final i in _incomes) {
      if (i.isCashTransfer) {
        // ATM transfer to bank counts for bank balance
        if (!i.isCash) total += i.totalAmount;
        continue;
      }
      if (!i.isCash) total += i.totalAmount;
    }
    return total;
  }

  @override
  Future<double> getTotalBankExpense() async {
    double total = 0;
    for (final e in _expenses) {
      if (e.isTransfer) continue;
      if (e.isCashTransfer) {
        // ATM withdrawal from bank counts for bank balance
        if (!e.isCash) total += e.amount;
        continue;
      }
      if (!e.isCash) total += e.amount;
    }
    return total;
  }

  @override
  Future<double> getCashIncomeByMonth(int month, int year) async {
    double total = 0;
    for (final i in await getIncomesByMonth(month, year)) {
      if (i.isCashTransfer) {
        if (i.isCash) total += i.totalAmount;
        continue;
      }
      if (i.isCash) total += i.totalAmount;
    }
    return total;
  }

  @override
  Future<double> getCashExpenseByMonth(int month, int year) async {
    double total = 0;
    for (final e in await getExpensesByMonth(month, year)) {
      if (e.isTransfer) continue;
      if (e.isCashTransfer) {
        if (e.isCash) total += e.amount;
        continue;
      }
      if (e.isCash) total += e.amount;
    }
    return total;
  }

  // === NOTIFICATIONS ===
  final List<AppNotification> _notifications = [];

  @override
  Future<void> insertNotification(AppNotification notification) async {
    _notifications.removeWhere((n) => n.id == notification.id);
    _notifications.add(notification);
    final saved = await FirebaseService.saveNotification(notification);
    if (!saved) {
      _pendingSaves.add(notification);
    }
  }

  @override
  Future<List<AppNotification>> getAllNotifications() async {
    _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.from(_notifications);
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    return _notifications.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markNotificationAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      final saved = await FirebaseService.saveNotification(_notifications[idx]);
      if (!saved) {
        _pendingSaves.add(_notifications[idx]);
      }
    }
  }

  @override
  Future<void> markAllNotificationsAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
      final saved = await FirebaseService.saveNotification(_notifications[i]);
      if (!saved) {
        _pendingSaves.add(_notifications[i]);
      }
    }
  }

  @override
  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    await FirebaseService.deleteNotification(id);
  }

  @override
  Future<void> deleteAllNotifications() async {
    _notifications.clear();
    await FirebaseService.deleteAllNotifications();
  }

  // === PRODUCTS ===
  final List<Product> _products = [];

  @override
  Future<void> insertProduct(Product product) async {
    _products.removeWhere((p) => p.id == product.id);
    _products.add(product);
    await FirebaseService.saveProduct(product);
  }

  @override
  Future<List<Product>> getAllProducts() async {
    return List.from(_products);
  }

  @override
  Future<void> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
    await FirebaseService.deleteProduct(id);
  }

  @override
  Future<void> updateProduct(Product product) async {
    _products.removeWhere((p) => p.id == product.id);
    _products.add(product);
    await FirebaseService.saveProduct(product);
  }

  // === PRODUCT GROUPS ===
  final List<ProductGroup> _groups = [];

  @override
  Future<void> insertProductGroup(ProductGroup group) async {
    _groups.removeWhere((g) => g.id == group.id);
    _groups.add(group);
    await FirebaseService.saveProductGroup(group);
  }

  @override
  Future<List<ProductGroup>> getAllProductGroups() async {
    return List.from(_groups);
  }

  @override
  Future<void> deleteProductGroup(String id) async {
    for (int i = 0; i < _products.length; i++) {
      if (_products[i].groupId == id) {
        _products[i] = _products[i].copyWith(clearGroupId: true);
        await FirebaseService.saveProduct(_products[i]);
      }
    }
    _groups.removeWhere((g) => g.id == id);
    await FirebaseService.deleteProductGroup(id);
  }

  @override
  Future<void> updateProductGroup(ProductGroup group) async {
    _groups.removeWhere((g) => g.id == group.id);
    _groups.add(group);
    await FirebaseService.saveProductGroup(group);
  }

  // === GOALS ===
  final List<Goal> _goals = [];

  @override
  Future<void> insertGoal(Goal goal) async {
    _goals.removeWhere((g) => g.id == goal.id);
    _goals.add(goal);
    await FirebaseService.saveGoal(goal);
  }

  @override
  Future<List<Goal>> getAllGoals() async {
    return List.from(_goals);
  }

  @override
  Future<Goal?> getActiveGoal() async {
    try {
      return _goals.firstWhere((g) => g.isActive);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    await FirebaseService.deleteGoal(id);
  }

  @override
  Future<void> updateGoal(Goal goal) async {
    _goals.removeWhere((g) => g.id == goal.id);
    _goals.add(goal);
    await FirebaseService.saveGoal(goal);
  }

  @override
  Future<void> setActiveGoal(String goalId) async {
    for (int i = 0; i < _goals.length; i++) {
      if (_goals[i].id == goalId) {
        _goals[i] = _goals[i].copyWith(isActive: true);
      } else {
        _goals[i] = _goals[i].copyWith(isActive: false);
      }
      await FirebaseService.saveGoal(_goals[i]);
    }
  }

  // === SUBCATEGORIES ===
  final List<Subcategory> _subcategories = [];

  @override
  Future<void> insertSubcategory(Subcategory subcategory) async {
    _subcategories.removeWhere((s) => s.id == subcategory.id);
    _subcategories.add(subcategory);
    await FirebaseService.saveSubcategory(subcategory);
  }

  @override
  Future<List<Subcategory>> getSubcategories(String categoryId) async {
    return _subcategories.where((s) => s.categoryId == categoryId).toList();
  }

  @override
  Future<void> deleteSubcategory(String id) async {
    _subcategories.removeWhere((s) => s.id == id);
    await FirebaseService.deleteSubcategory(id);
  }

  // === REDISTRIBUTION SETTINGS ===

  @override
  Future<int> getGlobalRedistributionDay() async => _globalRedistributionDay;

  @override
  Future<void> setGlobalRedistributionDay(int day) async {
    _globalRedistributionDay = day;
    await FirebaseService.saveGlobalRedistributionDay(day);
  }

  @override
  Future<bool> getRedistributionEnabled() async => _redistributionEnabled;

  @override
  Future<void> setRedistributionEnabled(bool enabled) async {
    _redistributionEnabled = enabled;
    await FirebaseService.saveRedistributionEnabled(enabled);
  }

  @override
  Future<void> insertRedistributionConfig(String categoryName, RedistributionConfig config) async {
    _redistributionConfigs[categoryName] = config;
    await FirebaseService.saveRedistributionConfig(categoryName, config);
  }

  @override
  Future<Map<String, RedistributionConfig>> getRedistributionConfigs() async => Map.from(_redistributionConfigs);

  @override
  Future<void> deleteRedistributionConfig(String categoryName) async {
    _redistributionConfigs.remove(categoryName);
    await FirebaseService.deleteRedistributionConfig(categoryName);
  }

  // === REDISTRIBUTION PRESETS ===

  @override
  Future<void> insertRedistributionPreset(RedistributionPreset preset) async {
    _redistributionPresets.removeWhere((p) => p.id == preset.id);
    _redistributionPresets.add(preset);
    await FirebaseService.saveRedistributionPreset(preset);
  }

  @override
  Future<List<RedistributionPreset>> getRedistributionPresets() async => List.from(_redistributionPresets);

  @override
  Future<void> deleteRedistributionPreset(String presetId) async {
    _redistributionPresets.removeWhere((p) => p.id == presetId);
    await FirebaseService.deleteRedistributionPreset(presetId);
  }

  // === BUDGETS ===
  final List<Budget> _budgets = [];

  // === REDISTRIBUTION ===
  int _globalRedistributionDay = 1;
  bool _redistributionEnabled = true;
  final Map<String, RedistributionConfig> _redistributionConfigs = {};
  final List<RedistributionPreset> _redistributionPresets = [];
  final List<CategoryModel> _categories = [];
  final Set<String> _tags = {};

  @override
  Future<void> insertBudget(Budget budget) async {
    _budgets.removeWhere((b) => b.id == budget.id);
    _budgets.add(budget);
    await FirebaseService.saveBudget(budget);
  }

  @override
  Future<List<Budget>> getBudgetsByMonth(int month, int year) async {
    return _budgets.where((b) => b.month == month && b.year == year).toList();
  }

  @override
  Future<Budget?> getBudgetByCategory(int month, int year, String category) async {
    try {
      return _budgets.firstWhere((b) => b.month == month && b.year == year && b.category == category);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateBudgetSpent(int month, int year, String category, double spent) async {
    final idx = _budgets.indexWhere((b) => b.month == month && b.year == year && b.category == category);
    if (idx >= 0) {
      _budgets[idx] = _budgets[idx].copyWith(spentAmount: spent);
      await FirebaseService.saveBudget(_budgets[idx]);
    }
  }

  @override
  Future<void> deleteBudget(String id) async {
    _budgets.removeWhere((b) => b.id == id);
    await FirebaseService.deleteBudget(id);
  }

  @override
  Future<void> updateBudget(Budget budget) async {
    _budgets.removeWhere((b) => b.id == budget.id);
    _budgets.add(budget);
    await FirebaseService.saveBudget(budget);
  }

  // === CATEGORIES ===

  @override
  Future<void> insertCategory(CategoryModel category) async {
    _categories.removeWhere((c) => c.id == category.id);
    _categories.add(category);
    await FirebaseService.saveCategory(category);
  }

  @override
  Future<List<CategoryModel>> getAllCategories() async {
    if (_categories.isEmpty) {
      try {
        final cats = await FirebaseService.loadCategories();
        _categories.addAll(cats);
      } catch (_) {}
    }
    return List<CategoryModel>.from(_categories);
  }

  @override
  Future<void> updateCategory(CategoryModel category) async {
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx >= 0) {
      _categories[idx] = category;
      await FirebaseService.saveCategory(category);
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
    await FirebaseService.deleteCategory(id);
  }

  @override
  Future<CategoryModel?> getCategoryByName(String name) async {
    if (_categories.isEmpty) {
      try {
        final cats = await FirebaseService.loadCategories();
        _categories.addAll(cats);
      } catch (_) {}
    }
    try {
      return _categories.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  // === TAGS ===
  @override
  Future<List<String>> getAllTags() async {
    _tags.clear();
    for (final e in _expenses) {
      _tags.addAll(e.tags);
    }
    return _tags.toList()..sort();
  }

  @override
  Future<void> addTag(String tag) async {
    _tags.add(tag);
    await FirebaseService.saveTag(tag);
  }

  @override
  Future<void> removeTag(String tag) async {
    _tags.remove(tag);
    await FirebaseService.deleteTag(tag);
  }

  // === SEARCH ===
  @override
  Future<List<Expense>> searchExpenses(String query) async {
    final q = query.toLowerCase();
    return _expenses.where((e) {
      if (e.description?.toLowerCase().contains(q) == true) return true;
      if (e.category.toLowerCase().contains(q)) return true;
      if (e.subcategory.toLowerCase().contains(q)) return true;
      if (e.amount.toString().contains(q)) return true;
      if (e.tags.any((t) => t.toLowerCase().contains(q))) return true;
      if (e.recurringName?.toLowerCase().contains(q) == true) return true;
      return false;
    }).toList();
  }

  @override
  Future<List<DailyIncome>> searchIncomes(String query) async {
    final q = query.toLowerCase();
    return _incomes.where((i) {
      if (i.notes?.toLowerCase().contains(q) == true) return true;
      if (i.type.toLowerCase().contains(q)) return true;
      if (i.totalAmount.toString().contains(q)) return true;
      return false;
    }).toList();
  }

  // === DELETE ALL DATA ===
  @override
  Future<void> deleteAllData() async {
    _incomes.clear();
    _expenses.clear();
    _products.clear();
    _groups.clear();
    _distributions.clear();
    _goals.clear();
    _notifications.clear();
    _budgets.clear();
    _categories.clear();
    _tags.clear();
    _globalRedistributionDay = 1;
    _redistributionEnabled = true;
    _redistributionConfigs.clear();
    _redistributionPresets.clear();
    await FirebaseService.deleteAllUserData();
  }

  // === LOAD FROM FIREBASE ===
  Future<void> loadAllFromFirebase() async {
    _incomes.clear();
    _expenses.clear();
    _products.clear();
    _groups.clear();
    _distributions.clear();
    _goals.clear();
    _notifications.clear();
    _budgets.clear();
    _categories.clear();
    _tags.clear();

    try {
      final incomes = await FirebaseService.loadIncomes();
      _incomes.addAll(incomes);
    } catch (_) {}

    try {
      final expenses = await FirebaseService.loadExpenses();
      _expenses.addAll(expenses);
      for (final e in _expenses) {
        _tags.addAll(e.tags);
      }
    } catch (_) {}

    try {
      final products = await FirebaseService.loadProducts();
      _products.addAll(products);
    } catch (_) {}

    try {
      final groups = await FirebaseService.loadProductGroups();
      _groups.addAll(groups);
    } catch (_) {}

    try {
      final dists = await FirebaseService.loadDistributions();
      _distributions.addAll(dists);
    } catch (_) {}

    try {
      final goals = await FirebaseService.loadGoals();
      _goals.addAll(goals);
    } catch (_) {}

    try {
      final notifs = await FirebaseService.loadNotifications();
      _notifications.addAll(notifs);
    } catch (_) {}

    try {
      final budgets = await FirebaseService.loadBudgets();
      _budgets.addAll(budgets);
    } catch (_) {}

    try {
      final cats = await FirebaseService.loadCategories();
      _categories.addAll(cats);
    } catch (_) {}

    if (_categories.isEmpty) {
      for (final cat in CategoryModel.defaultCategories) {
        _categories.add(cat);
      }
      for (final cat in _categories) {
        await FirebaseService.saveCategory(cat);
      }
    }

    try {
      _globalRedistributionDay = await FirebaseService.loadGlobalRedistributionDay();
      _redistributionEnabled = await FirebaseService.loadRedistributionEnabled();
      _redistributionConfigs.clear();
      _redistributionConfigs.addAll(await FirebaseService.loadRedistributionConfigs());
      _redistributionPresets.clear();
      _redistributionPresets.addAll(await FirebaseService.loadRedistributionPresets());
    } catch (_) {}

    try {
      await NotificationService.instance.checkAndGenerateNotifications();
    } catch (_) {}

    try {
      await PaymentReminderService.instance.checkAndScheduleReminders();
    } catch (_) {}

    try {
      await autoGenerateRecurring();
      await autoRedistributeIfNeeded();
    } catch (_) {}

    // Retry any pending saves that failed earlier
    if (_pendingSaves.isNotEmpty) {
      try {
        await _retryPendingSaves();
      } catch (_) {}
    }
  }

  /// Recalculate spentAmount for current distribution from actual expenses.
  /// Can be called with a custom date range (last 30 days) or defaults to current month.
  Future<void> recalculateDistributionSpent({DateTime? from, DateTime? to}) async {
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;

    var dist = await getDistribution(month, year);
    if (dist == null) return;

    // Get expenses — use all expenses by default
    List<Expense> expenses;
    if (from != null && to != null) {
      expenses = await getExpenseListByDateRange(from, to);
    } else {
      expenses = await getAllExpenses();
    }

    // Recalculate per-category spent
    final updatedCategories = dist.categories.map((cat) {
      if (cat.isAutomatic) {
        double transfers = 0;
        for (final exp in expenses) {
          if (exp.isTransfer && exp.transferTo == 'Ahorro') {
            transfers += exp.amount;
          }
        }
        return cat.copyWith(spentAmount: transfers);
      }
      double spent = 0;
      for (final exp in expenses) {
        if (exp.isTransfer) continue;
        if (exp.category == 'Cajero') continue;
        if (exp.category == cat.name ||
            (exp.isRecurring && exp.recurringName == cat.name)) {
          spent += exp.amount;
        }
      }
      return cat.copyWith(spentAmount: spent);
    }).toList();

    final updatedDist = dist.copyWith(categories: updatedCategories);
    await insertDistribution(updatedDist);
  }

  Future<void> autoRedistributeIfNeeded() async {
    final now = DateTime.now();
    final today = now.day;
    final currentMonth = now.month;
    final currentYear = now.year;

    final prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;
    final prevYear = currentMonth == 1 ? currentYear - 1 : currentYear;

    final prevDist = await getDistribution(prevMonth, prevYear);

    var currentDist = await getDistribution(currentMonth, currentYear);
    if (currentDist == null) {
      // Only create if doesn't exist — don't overwrite existing
      final actualPrevIncome = prevDist != null ? prevDist.monthlyIncome : 0;
      List<DistributionCategory> newCategories;
      if (prevDist != null) {
        newCategories = prevDist.userCategories.map((cat) => DistributionCategory(
          name: cat.name,
          fixedAmount: cat.fixedAmount,
          percentage: cat.percentage,
          isFixed: cat.isFixed,
          spentAmount: 0,
          isAutomatic: false,
          isEnabled: cat.isEnabled,
          redistributionPercentages: cat.redistributionPercentages,
        )).toList();
      } else {
        newCategories = [];
      }
      newCategories.add(DistributionCategory(
        name: 'Ahorro',
        isFixed: true,
        isAutomatic: true,
      ));
      currentDist = SavingsDistribution(
        id: '$currentYear-$currentMonth',
        month: currentMonth,
        year: currentYear,
        monthlyIncome: actualPrevIncome.toDouble(),
        categories: newCategories,
      );
      await insertDistribution(currentDist);
    }

    if (!_redistributionEnabled || prevDist == null) return;

    // Only redistribute if today >= redistribution day and not yet applied
    bool alreadyApplied = prevDist.categories
        .where((c) => !c.isAutomatic)
        .every((c) => c.redistributionApplied);
    if (alreadyApplied) return;

    final actualPrevIncome = prevDist.monthlyIncome;
    if (actualPrevIncome <= 0) return;

    double totalFixedExpenses = 0;
    for (final cat in prevDist.userCategories) {
      if (cat.isFixed) {
        totalFixedExpenses += cat.fixedAmount ?? 0;
      }
    }
    if (totalFixedExpenses >= actualPrevIncome) return;

    final totalActualSpent = prevDist.totalSpent;
    if (totalActualSpent >= actualPrevIncome) return;
    final netSavings = actualPrevIncome - totalActualSpent;

    var modified = false;
    double totalRedistributed = 0;
    final Map<String, double> redistributionByTarget = {};
    final List<int> appliedPrevIndices = [];
    final prevCategories = List<DistributionCategory>.from(prevDist.categories);
    final currentCategories = List<DistributionCategory>.from(currentDist.categories);

    for (int pi = 0; pi < prevCategories.length; pi++) {
      final prevCat = prevCategories[pi];
      if (prevCat.redistributionApplied) continue;

      final config = _redistributionConfigs[prevCat.name];
      final catDay = config?.redistributionDay ?? _globalRedistributionDay;

      if (today < catDay) continue;

      if (!prevCat.isEnabled && !prevCat.isAutomatic) continue;

      final unspent = prevDist.getCategoryUnspentBase(prevCat);
      if (unspent <= 0) continue;

      final percentages = config?.redistributionPercentages.isNotEmpty == true
          ? config!.redistributionPercentages
          : (prevCat.redistributionPercentages.isNotEmpty
              ? prevCat.redistributionPercentages
              : {prevCat.name: 100.0});

      for (final entry in percentages.entries) {
        final amount = unspent * entry.value / 100;
        redistributionByTarget[entry.key] =
            (redistributionByTarget[entry.key] ?? 0) + amount;
        totalRedistributed += amount;
      }

      appliedPrevIndices.add(pi);
    }

    if (totalRedistributed > netSavings && netSavings > 0) {
      final factor = netSavings / totalRedistributed;
      for (final key in redistributionByTarget.keys) {
        redistributionByTarget[key] = redistributionByTarget[key]! * factor;
      }
    }

    for (final entry in redistributionByTarget.entries) {
      final idx = currentCategories.indexWhere((c) => c.name == entry.key);
      if (idx >= 0) {
        final old = currentCategories[idx];
        currentCategories[idx] = old.copyWith(
          totalRedistributionReceived: old.totalRedistributionReceived + entry.value,
        );
      }
    }

    for (final pi in appliedPrevIndices) {
      prevCategories[pi] = prevCategories[pi].copyWith(redistributionApplied: true);
    }
    modified = appliedPrevIndices.isNotEmpty;

    if (!modified) return;

    final updatedPrevDist = prevDist.copyWith(categories: prevCategories);
    final updatedCurrentDist = currentDist.copyWith(
      categories: currentCategories,
      // Add redistributed amount to monthlyIncome for new period
      monthlyIncome: currentDist.monthlyIncome + totalRedistributed,
    );

    await insertDistribution(updatedCurrentDist);
    await updateDistribution(updatedPrevDist);
  }

  @override
  Future<void> autoGenerateRecurring() async {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final recurringIncomes = _incomes.where((i) => i.isRecurring).toList();
    for (final income in recurringIncomes) {
      final alreadyExists = _incomes.any((i) =>
          i.isRecurring &&
          i.recurringName == income.recurringName &&
          i.date.month == currentMonth &&
          i.date.year == currentYear &&
          i.id != income.id);
      if (!alreadyExists) {
        final safeDay = income.date.day.clamp(1, _daysInMonth(currentYear, currentMonth));
        final newIncome = DailyIncome(
          id: const Uuid().v4(),
          date: DateTime(currentYear, currentMonth, safeDay),
          totalAmount: income.totalAmount,
          notes: income.notes,
          type: income.type,
          isRecurring: true,
          recurringName: income.recurringName,
          isCash: income.isCash,
        );
        await insertIncome(newIncome);
      }
    }

    final recurringExpenses = _expenses.where((e) => e.isRecurring).toList();
    for (final expense in recurringExpenses) {
      final alreadyExists = _expenses.any((e) =>
          e.isRecurring &&
          e.recurringName == expense.recurringName &&
          e.date.month == currentMonth &&
          e.date.year == currentYear &&
          e.id != expense.id);
      if (!alreadyExists) {
        final safeDay = expense.date.day.clamp(1, _daysInMonth(currentYear, currentMonth));
        final newExpense = Expense(
          id: const Uuid().v4(),
          amount: expense.amount,
          category: expense.category,
          subcategory: expense.subcategory,
          date: DateTime(currentYear, currentMonth, safeDay),
          description: expense.description,
          isRecurring: true,
          recurringName: expense.recurringName,
          isCash: expense.isCash,
        );
        await insertExpense(newExpense);
      }
    }
  }

  int _daysInMonth(int year, int month) {
    if (month == 2) {
      if (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) return 29;
      return 28;
    }
    if ([1, 3, 5, 7, 8, 10, 12].contains(month)) return 31;
    return 30;
  }
}
