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

abstract class DatabaseServiceInterface {
  static void init() {}

  String get _userId;
  Future<void> resetForNewUser();
  Future<void> syncFromFirebase();

  // Incomes
  Future<void> insertIncome(DailyIncome income);
  Future<List<DailyIncome>> getIncomesByMonth(int month, int year);
  Future<List<DailyIncome>> getAllIncomes();
  Future<List<DailyIncome>> getIncomesByDate(DateTime date);
  Future<double> getTotalIncomeByMonth(int month, int year);
  Future<double> getIncomesByDateRange(DateTime from, DateTime to);
  Future<void> deleteIncome(String id);
  Future<void> updateIncome(DailyIncome income);
  Future<List<DailyIncome>> getRecurringIncomes();

  // Expenses
  Future<void> insertExpense(Expense expense);
  Future<List<Expense>> getExpensesByMonth(int month, int year);
  Future<List<Expense>> getAllExpenses();
  Future<List<Expense>> getExpensesByDate(DateTime date);
  Future<double> getTotalExpensesByMonth(int month, int year);
  Future<double> getExpensesByDateRange(DateTime from, DateTime to);
  Future<void> deleteExpense(String id);
  Future<void> updateExpense(Expense expense);
  Future<List<Expense>> getRecurringExpenses();

  // Distributions
  Future<void> insertDistribution(SavingsDistribution distribution);
  Future<SavingsDistribution?> getDistribution(int month, int year);
  Future<void> updateDistribution(SavingsDistribution distribution);
  Future<List<DistributionCategory>> getDistributionCategories(int month, int year);
  Future<SavingsDistribution?> getPreviousMonthDistribution(int currentMonth, int currentYear);
  Future<double> calculateRedistributionForMonth(int currentMonth, int currentYear);

  // Balance
  Future<double> getTotalBalance();
  Future<double> getTotalSavings();
  Future<double> getTotalCashIncome();
  Future<double> getTotalCashExpense();
  Future<double> getTotalBankIncome();
  Future<double> getTotalBankExpense();
  Future<double> getCashIncomeByMonth(int month, int year);
  Future<double> getCashExpenseByMonth(int month, int year);

  // Notifications
  Future<void> insertNotification(AppNotification notification);
  Future<List<AppNotification>> getAllNotifications();
  Future<int> getUnreadNotificationCount();
  Future<void> markNotificationAsRead(String id);
  Future<void> markAllNotificationsAsRead();
  Future<void> deleteNotification(String id);
  Future<void> deleteAllNotifications();

  // Products
  Future<void> insertProduct(Product product);
  Future<List<Product>> getAllProducts();
  Future<void> deleteProduct(String id);
  Future<void> updateProduct(Product product);

  // Product Groups
  Future<void> insertProductGroup(ProductGroup group);
  Future<List<ProductGroup>> getAllProductGroups();
  Future<void> deleteProductGroup(String id);
  Future<void> updateProductGroup(ProductGroup group);

  // Goals
  Future<void> insertGoal(Goal goal);
  Future<List<Goal>> getAllGoals();
  Future<Goal?> getActiveGoal();
  Future<void> deleteGoal(String id);
  Future<void> updateGoal(Goal goal);
  Future<void> setActiveGoal(String goalId);

  // Budgets
  Future<void> insertBudget(Budget budget);
  Future<List<Budget>> getBudgetsByMonth(int month, int year);
  Future<Budget?> getBudgetByCategory(int month, int year, String category);
  Future<void> updateBudgetSpent(int month, int year, String category, double spent);
  Future<void> deleteBudget(String id);
  Future<void> updateBudget(Budget budget);

  // Subcategories
  Future<void> insertSubcategory(Subcategory subcategory);
  Future<List<Subcategory>> getSubcategories(String categoryId);
  Future<void> deleteSubcategory(String id);

  // Redistribution Settings
  Future<int> getGlobalRedistributionDay();
  Future<void> setGlobalRedistributionDay(int day);
  Future<bool> getRedistributionEnabled();
  Future<void> setRedistributionEnabled(bool enabled);
  Future<void> insertRedistributionConfig(String categoryName, RedistributionConfig config);
  Future<Map<String, RedistributionConfig>> getRedistributionConfigs();
  Future<void> deleteRedistributionConfig(String categoryName);

  // Redistribution Presets
  Future<void> insertRedistributionPreset(RedistributionPreset preset);
  Future<List<RedistributionPreset>> getRedistributionPresets();
  Future<void> deleteRedistributionPreset(String presetId);

  // Recurring auto-generation
  Future<void> autoGenerateRecurring();

  // Categories
  Future<void> insertCategory(CategoryModel category);
  Future<List<CategoryModel>> getAllCategories();
  Future<void> updateCategory(CategoryModel category);
  Future<void> deleteCategory(String id);
  Future<CategoryModel?> getCategoryByName(String name);

  // Tags
  Future<List<String>> getAllTags();
  Future<void> addTag(String tag);
  Future<void> removeTag(String tag);

  // Search
  Future<List<Expense>> searchExpenses(String query);
  Future<List<DailyIncome>> searchIncomes(String query);

  // Delete all user data
  Future<void> deleteAllData();
}
