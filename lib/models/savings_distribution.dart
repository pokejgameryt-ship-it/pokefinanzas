class DistributionCategory {
  final String name;
  final double? fixedAmount;
  final double? percentage;
  final bool isFixed;
  final double spentAmount;
  final bool isAutomatic;
  final Map<String, double> redistributionPercentages;
  final bool redistributionApplied;
  final double totalRedistributionReceived;
  final bool isEnabled;

  DistributionCategory({
    required this.name,
    this.fixedAmount,
    this.percentage,
    this.isFixed = true,
    this.spentAmount = 0,
    this.isAutomatic = false,
    this.redistributionPercentages = const {},
    this.redistributionApplied = false,
    this.totalRedistributionReceived = 0,
    this.isEnabled = true,
  });

  double computeBudget(double monthlyIncome, {double totalFixed = 0}) {
    if (isAutomatic || !isEnabled) return 0;
    if (isFixed) return fixedAmount ?? 0;
    final remaining = monthlyIncome - totalFixed;
    return remaining > 0 ? (remaining * (percentage ?? 0) / 100) : 0;
  }

  double computeUnspent(double monthlyIncome, {double totalFixed = 0}) {
    return (computeBudget(monthlyIncome, totalFixed: totalFixed) - spentAmount).clamp(0, double.infinity);
  }

  double computePercentageUsed(double monthlyIncome, {double totalFixed = 0}) {
    final budget = computeBudget(monthlyIncome, totalFixed: totalFixed);
    return budget > 0 ? (spentAmount / budget * 100) : 0;
  }

  bool isOverBudgetAmount(double monthlyIncome, {double totalFixed = 0}) =>
      spentAmount > computeBudget(monthlyIncome, totalFixed: totalFixed) && !isAutomatic && isEnabled;

  double get budgetAmount {
    if (isAutomatic || !isEnabled) return 0;
    return isFixed ? (fixedAmount ?? 0) : (percentage ?? 0);
  }

  double get remaining => budgetAmount - spentAmount;
  bool get isOverBudget => spentAmount > budgetAmount && !isAutomatic && isEnabled;
  double get percentageUsed =>
      budgetAmount > 0 ? (spentAmount / budgetAmount * 100) : 0;

  double get unspent => (budgetAmount - spentAmount).clamp(0, double.infinity);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'fixedAmount': fixedAmount,
      'percentage': percentage,
      'isFixed': isFixed,
      'spentAmount': spentAmount,
      'isAutomatic': isAutomatic,
      'redistributionPercentages': redistributionPercentages,
      'redistributionApplied': redistributionApplied,
      'totalRedistributionReceived': totalRedistributionReceived,
      'isEnabled': isEnabled,
    };
  }

  factory DistributionCategory.fromMap(Map<String, dynamic> map) {
    return DistributionCategory(
      name: map['name'],
      fixedAmount: map['fixedAmount']?.toDouble(),
      percentage: map['percentage']?.toDouble(),
      isFixed: map['isFixed'] ?? true,
      spentAmount: map['spentAmount']?.toDouble() ?? 0,
      isAutomatic: map['isAutomatic'] ?? false,
      redistributionPercentages: (map['redistributionPercentages'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          const {},
      redistributionApplied: map['redistributionApplied'] ?? false,
      totalRedistributionReceived: map['totalRedistributionReceived']?.toDouble() ?? 0,
      isEnabled: map['isEnabled'] ?? true,
    );
  }

  DistributionCategory copyWith({
    String? name,
    double? fixedAmount,
    double? percentage,
    bool? isFixed,
    double? spentAmount,
    bool? isAutomatic,
    Map<String, double>? redistributionPercentages,
    bool? redistributionApplied,
    double? totalRedistributionReceived,
    bool? isEnabled,
  }) {
    return DistributionCategory(
      name: name ?? this.name,
      fixedAmount: fixedAmount ?? this.fixedAmount,
      percentage: percentage ?? this.percentage,
      isFixed: isFixed ?? this.isFixed,
      spentAmount: spentAmount ?? this.spentAmount,
      isAutomatic: isAutomatic ?? this.isAutomatic,
      redistributionPercentages:
          redistributionPercentages ?? this.redistributionPercentages,
      redistributionApplied: redistributionApplied ?? this.redistributionApplied,
      totalRedistributionReceived: totalRedistributionReceived ?? this.totalRedistributionReceived,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

class SavingsDistribution {
  final String id;
  final int month;
  final int year;
  final double monthlyIncome;
  final List<DistributionCategory> categories;

  SavingsDistribution({
    required this.id,
    required this.month,
    required this.year,
    required this.monthlyIncome,
    required this.categories,
  });

  static final DistributionCategory _defaultSavings = DistributionCategory(
    name: 'Ahorro',
    isFixed: true,
    isAutomatic: true,
  );

  List<DistributionCategory> get userCategories =>
      categories.where((c) => !c.isAutomatic).toList();

  List<DistributionCategory> get enabledUserCategories =>
      userCategories.where((c) => c.isEnabled).toList();

  DistributionCategory get savingsCategory =>
      categories.firstWhere((c) => c.isAutomatic, orElse: () => _defaultSavings);

  double get totalFixed {
    double total = 0;
    for (final cat in enabledUserCategories) {
      if (cat.isFixed) total += cat.fixedAmount ?? 0;
    }
    return total;
  }

  double get totalPercentage {
    double total = 0;
    for (final cat in enabledUserCategories) {
      if (!cat.isFixed) total += cat.percentage ?? 0;
    }
    return total;
  }

  double get totalBudget {
    final fixed = totalFixed;
    final remaining = monthlyIncome - fixed;
    if (remaining <= 0) return fixed;
    return fixed + (remaining * totalPercentage / 100);
  }

  double get totalSpent {
    double total = 0;
    for (final cat in enabledUserCategories) {
      total += cat.spentAmount;
    }
    return total;
  }

  double get totalOverBudget {
    double total = 0;
    for (final cat in enabledUserCategories) {
      final budget = cat.isFixed
          ? (cat.fixedAmount ?? 0)
          : (monthlyIncome - totalFixed) * (cat.percentage ?? 0) / 100;
      if (cat.spentAmount > budget) {
        total += cat.spentAmount - budget;
      }
    }
    return total;
  }

  double get savingsBudget {
    final fixed = totalFixed;
    final remaining = monthlyIncome - fixed;
    if (remaining <= 0) return 0;
    final pctTotal = totalPercentage;
    final allocated = remaining * pctTotal / 100;
    return remaining - allocated > 0 ? remaining - allocated : 0;
  }

  double get savingsSpent {
    return savingsCategory.spentAmount;
  }

  double get savings {
    final unspent = monthlyIncome - totalSpent;
    return unspent > 0 ? unspent : 0;
  }

  double get remaining {
    return monthlyIncome - totalBudget;
  }

  bool get isOverBudget => totalSpent > monthlyIncome;

  double getOverBudgetAmount(String categoryName) {
    final cat = categories.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => DistributionCategory(name: categoryName),
    );
    final fixed = totalFixed;
    final remaining = monthlyIncome - fixed;
    final budget = cat.isFixed
        ? (cat.fixedAmount ?? 0)
        : remaining > 0 ? remaining * (cat.percentage ?? 0) / 100 : 0;
    return cat.spentAmount > budget ? cat.spentAmount - budget : 0;
  }

  double getCategoryBudget(DistributionCategory cat) {
    if (cat.isAutomatic) return savingsBudget;
    if (!cat.isEnabled) return 0;
    final fixed = totalFixed;
    final remaining = monthlyIncome - fixed;
    final base = cat.isFixed
        ? (cat.fixedAmount ?? 0)
        : remaining > 0 ? remaining * (cat.percentage ?? 0) / 100 : 0;
    return base + cat.totalRedistributionReceived;
  }

  double getCategoryUnspent(DistributionCategory cat) {
    if (cat.isAutomatic) {
      if (cat.redistributionPercentages.isEmpty) return 0;
      return (savingsBudget - cat.spentAmount).clamp(0, double.infinity);
    }
    if (!cat.isEnabled) return 0;
    final budget = getCategoryBudget(cat);
    return (budget - cat.spentAmount).clamp(0, double.infinity);
  }

  /// Unspent based on the BASE budget only (without totalRedistributionReceived).
  /// Use this for redistribution calculations to avoid inflating unspent
  /// with money that was already redistributed from earlier months.
  double getCategoryUnspentBase(DistributionCategory cat) {
    if (cat.isAutomatic) {
      if (cat.redistributionPercentages.isEmpty) return 0;
      return (savingsBudget - cat.spentAmount).clamp(0, double.infinity);
    }
    if (!cat.isEnabled) return 0;
    final fixed = totalFixed;
    final remaining = monthlyIncome - fixed;
    final base = cat.isFixed
        ? (cat.fixedAmount ?? 0)
        : remaining > 0 ? remaining * (cat.percentage ?? 0) / 100 : 0;
    return (base - cat.spentAmount).clamp(0, double.infinity);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'month': month,
      'year': year,
      'monthlyIncome': monthlyIncome,
      'categories': categories.map((c) => c.toMap()).toList(),
    };
  }

  factory SavingsDistribution.fromMap(Map<String, dynamic> map) {
    return SavingsDistribution(
      id: map['id'],
      month: map['month'],
      year: map['year'],
      monthlyIncome: map['monthlyIncome']?.toDouble() ?? 0,
      categories: (map['categories'] as List)
          .map((c) => DistributionCategory.fromMap(c))
          .toList(),
    );
  }

  SavingsDistribution copyWith({
    String? id,
    int? month,
    int? year,
    double? monthlyIncome,
    List<DistributionCategory>? categories,
  }) {
    return SavingsDistribution(
      id: id ?? this.id,
      month: month ?? this.month,
      year: year ?? this.year,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      categories: categories ?? this.categories,
    );
  }
}
