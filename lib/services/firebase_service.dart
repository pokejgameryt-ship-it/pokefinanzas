import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/daily_income.dart';
import '../models/expense.dart';
import '../models/product.dart';
import '../models/product_group.dart';
import '../models/goal.dart';
import '../models/savings_distribution.dart';
import '../models/app_notification.dart';
import '../models/budget.dart';
import '../models/subcategory.dart';
import '../models/redistribution_config.dart';
import '../models/redistribution_preset.dart';
import '../models/category_model.dart';
import 'auth_service.dart';

class FirebaseService {
  static const String _baseUrl =
      'https://pokefinanzas-default-rtdb.europe-west1.firebasedatabase.app';

  static const Duration _timeout = Duration(seconds: 15);

  static String? get _userId => AuthService.currentUser?.uid;
  static String? get _token => AuthService.idToken;

  static String _userPath() => 'users/${_userId}';

  // === SAVING (write-through to Firebase) ===

  static Future<void> saveIncome(DailyIncome income) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/incomes/${income.id}.json?auth=$_token');
      await http.put(url, body: jsonEncode(income.toMap())).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> deleteIncome(String incomeId) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/incomes/$incomeId.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> saveExpense(Expense expense) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/expenses/${expense.id}.json?auth=$_token');
      await http.put(url, body: jsonEncode(expense.toMap())).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> deleteExpense(String expenseId) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/expenses/$expenseId.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> saveProduct(Product product) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/products/${product.id}.json?auth=$_token');
      await http.put(url, body: jsonEncode(product.toMap())).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> deleteProduct(String productId) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/products/$productId.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }

  // === PRODUCT GROUPS ===

  static Future<void> saveProductGroup(ProductGroup group) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/product_groups/${group.id}.json?auth=$_token');
      await http.put(url, body: jsonEncode(group.toMap())).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> deleteProductGroup(String groupId) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/product_groups/$groupId.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }

  static Future<List<ProductGroup>> loadProductGroups() async {
    if (_userId == null) return [];
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/product_groups.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data.values
            .map((v) => ProductGroup.fromMap(v as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveGoal(Goal goal) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/goals/${goal.id}.json?auth=$_token');
      await http.put(url, body: jsonEncode(goal.toMap())).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> deleteGoal(String goalId) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/goals/$goalId.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> saveDistribution(SavingsDistribution dist) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/distributions/${dist.id}.json?auth=$_token');
      final map = dist.toMap();
      map['categories'] = dist.categories.map((c) => c.toMap()).toList();
      await http.put(url, body: jsonEncode(map)).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> deleteDistribution(String distId) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/distributions/$distId.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> saveNotification(AppNotification notif) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/notifications/${notif.id}.json?auth=$_token');
      await http.put(url, body: jsonEncode(notif.toMap())).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> deleteNotification(String notifId) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/notifications/$notifId.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }

  // === LOADING (from Firebase as primary source) ===

  static Future<List<DailyIncome>> loadIncomes() async {
    if (_userId == null) return [];
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/incomes.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data.values
            .map((v) => DailyIncome.fromMap(v as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Expense>> loadExpenses() async {
    if (_userId == null) return [];
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/expenses.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data.values
            .map((v) => Expense.fromMap(v as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Product>> loadProducts() async {
    if (_userId == null) return [];
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/products.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data.values
            .map((v) => Product.fromMap(v as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Goal>> loadGoals() async {
    if (_userId == null) return [];
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/goals.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data.values
            .map((v) => Goal.fromMap(v as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<SavingsDistribution>> loadDistributions() async {
    if (_userId == null) return [];
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/distributions.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data.values.map((v) {
          final map = v as Map<String, dynamic>;
          if (map['categories'] is List) {
            map['categories'] = (map['categories'] as List)
                .map((c) => (c as Map<String, dynamic>))
                .toList();
          }
          return SavingsDistribution.fromMap(map);
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<AppNotification>> loadNotifications() async {
    if (_userId == null) return [];
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/notifications.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data.values
            .map((v) => AppNotification.fromMap(v as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // === DELETE ALL USER DATA ===

  // === BUDGETS ===

  static Future<void> saveBudget(Budget budget) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/budgets/${budget.id}.json?auth=$_token');
      await http.put(url, body: jsonEncode(budget.toMap())).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> deleteBudget(String budgetId) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/budgets/$budgetId.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }

  static Future<List<Budget>> loadBudgets() async {
    if (_userId == null) return [];
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/budgets.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data.values
            .map((v) => Budget.fromMap(v as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // === SUBCATEGORIES ===

  static Future<void> saveSubcategory(Subcategory subcategory) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/subcategories/${subcategory.id}.json?auth=$_token');
      await http.put(url, body: jsonEncode(subcategory.toMap())).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> deleteSubcategory(String subcategoryId) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/subcategories/$subcategoryId.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }

  static Future<List<Subcategory>> loadSubcategories() async {
    if (_userId == null) return [];
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/subcategories.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data.values
            .map((v) => Subcategory.fromMap(v as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // === REDISTRIBUTION SETTINGS ===

  static Future<void> saveGlobalRedistributionDay(int day) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/redistributionSettings/globalRedistributionDay.json?auth=$_token');
      await http.put(url, body: jsonEncode(day)).timeout(_timeout);
    } catch (_) {}
  }

  static Future<int> loadGlobalRedistributionDay() async {
    if (_userId == null) return 1;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/redistributionSettings/globalRedistributionDay.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        return jsonDecode(response.body) as int;
      }
    } catch (_) {}
    return 1;
  }

  static Future<void> saveRedistributionEnabled(bool enabled) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/redistributionSettings/redistributionEnabled.json?auth=$_token');
      await http.put(url, body: jsonEncode(enabled)).timeout(_timeout);
    } catch (_) {}
  }

  static Future<bool> loadRedistributionEnabled() async {
    if (_userId == null) return true;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/redistributionSettings/redistributionEnabled.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        return jsonDecode(response.body) as bool;
      }
    } catch (_) {}
    return true;
  }

  static Future<void> saveRedistributionConfig(String categoryName, RedistributionConfig config) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/redistributionConfigs/$categoryName.json?auth=$_token');
      await http.put(url, body: jsonEncode(config.toMap())).timeout(_timeout);
    } catch (_) {}
  }

  static Future<Map<String, RedistributionConfig>> loadRedistributionConfigs() async {
    if (_userId == null) return {};
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/redistributionConfigs.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data.map((k, v) => MapEntry(k, RedistributionConfig.fromMap(v as Map<String, dynamic>)));
      }
    } catch (_) {}
    return {};
  }

  static Future<void> deleteRedistributionConfig(String categoryName) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/redistributionConfigs/$categoryName.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }

  // === REDISTRIBUTION PRESETS ===

  static Future<void> saveRedistributionPreset(RedistributionPreset preset) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/redistributionPresets/${preset.id}.json?auth=$_token');
      await http.put(url, body: jsonEncode(preset.toMap())).timeout(_timeout);
    } catch (_) {}
  }

  static Future<List<RedistributionPreset>> loadRedistributionPresets() async {
    if (_userId == null) return [];
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/redistributionPresets.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data.values.map((v) => RedistributionPreset.fromMap(v as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> deleteRedistributionPreset(String presetId) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/redistributionPresets/$presetId.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }

  // === CATEGORIES ===

  static Future<void> saveCategory(CategoryModel category) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/categories/${category.id}.json?auth=$_token');
      await http.put(url, body: jsonEncode(category.toMap())).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> deleteCategory(String categoryId) async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/categories/$categoryId.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }

  static Future<List<CategoryModel>> loadCategories() async {
    if (_userId == null) return [];
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}/categories.json?auth=$_token');
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data.values
            .map((v) => CategoryModel.fromMap(v as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // === TAGS ===

  static Future<void> saveTag(String tag) async {
    if (_userId == null) return;
    try {
      final encoded = tag.replaceAll('.', '_dot_');
      final url = Uri.parse('$_baseUrl/${_userPath()}/tags/$encoded.json?auth=$_token');
      await http.put(url, body: jsonEncode(tag)).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> deleteTag(String tag) async {
    if (_userId == null) return;
    try {
      final encoded = tag.replaceAll('.', '_dot_');
      final url = Uri.parse('$_baseUrl/${_userPath()}/tags/$encoded.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }

  // === DELETE ALL USER DATA ===

  static Future<void> deleteAllUserData() async {
    if (_userId == null) return;
    try {
      final url = Uri.parse('$_baseUrl/${_userPath()}.json?auth=$_token');
      await http.delete(url).timeout(_timeout);
    } catch (_) {}
  }
}
