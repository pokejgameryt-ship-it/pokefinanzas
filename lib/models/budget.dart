class Budget {
  final String id;
  final int month;
  final int year;
  final String category;
  final double limitAmount;
  final double spentAmount;

  Budget({
    required this.id,
    required this.month,
    required this.year,
    required this.category,
    required this.limitAmount,
    this.spentAmount = 0,
  });

  double get percentageUsed =>
      limitAmount > 0 ? (spentAmount / limitAmount * 100) : 0;

  bool get isOverBudget => spentAmount > limitAmount;

  bool get isNearLimit => percentageUsed >= 80 && !isOverBudget;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'month': month,
      'year': year,
      'category': category,
      'limitAmount': limitAmount,
      'spentAmount': spentAmount,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      month: map['month'],
      year: map['year'],
      category: map['category'],
      limitAmount: map['limitAmount'],
      spentAmount: map['spentAmount'] ?? 0,
    );
  }

  Budget copyWith({
    String? id,
    int? month,
    int? year,
    String? category,
    double? limitAmount,
    double? spentAmount,
  }) {
    return Budget(
      id: id ?? this.id,
      month: month ?? this.month,
      year: year ?? this.year,
      category: category ?? this.category,
      limitAmount: limitAmount ?? this.limitAmount,
      spentAmount: spentAmount ?? this.spentAmount,
    );
  }
}
