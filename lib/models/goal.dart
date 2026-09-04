class PaymentRecord {
  final DateTime date;
  final double amount;
  final String? note;

  PaymentRecord({
    required this.date,
    required this.amount,
    this.note,
  });

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'amount': amount,
    'note': note,
  };

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(map['date']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }
    return PaymentRecord(
      date: parsedDate,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      note: map['note']?.toString(),
    );
  }
}

class Goal {
  final String id;
  final String name;
  final List<String> productIds;
  final double targetAmount;
  final double savedAmount;
  final bool isActive;
  final DateTime? deadline;
  final DateTime createdAt;

  final bool hasFixedPayment;
  final String? paymentFrequency;
  final double? paymentAmount;
  final int? totalPayments;
  final int completedPayments;
  final DateTime? firstPaymentDate;
  final List<PaymentRecord> paymentHistory;

  Goal({
    required this.id,
    required this.name,
    required this.productIds,
    required this.targetAmount,
    this.savedAmount = 0.0,
    this.isActive = false,
    this.deadline,
    required this.createdAt,
    this.hasFixedPayment = false,
    this.paymentFrequency,
    this.paymentAmount,
    this.totalPayments,
    this.completedPayments = 0,
    this.firstPaymentDate,
    this.paymentHistory = const [],
  });

  double get progressPercentage {
    if (targetAmount <= 0) return 0.0;
    return (savedAmount / targetAmount * 100).clamp(0.0, 100.0);
  }

  bool get isCompleted => savedAmount >= targetAmount;

  double get remainingAmount => (targetAmount - savedAmount).clamp(0.0, double.infinity);

  int get remainingPayments => (totalPayments ?? 0) - completedPayments;

  double? get nextPaymentAmount {
    if (!hasFixedPayment || isCompleted || remainingPayments <= 0) return null;
    return paymentAmount;
  }

  DateTime? get nextPaymentDate {
    if (!hasFixedPayment || isCompleted || firstPaymentDate == null || paymentFrequency == null) return null;
    final interval = _getPaymentInterval();
    if (interval == null) return null;
    final nextDate = firstPaymentDate!.add(interval * completedPayments);
    return nextDate;
  }

  Duration? _getPaymentInterval() {
    switch (paymentFrequency) {
      case 'daily':
        return const Duration(days: 1);
      case 'weekly':
        return const Duration(days: 7);
      case 'monthly':
        return const Duration(days: 30);
      case 'quarterly':
        return const Duration(days: 91);
      case 'annual':
        return const Duration(days: 365);
      default:
        return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'productIds': productIds.join(','),
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'isActive': isActive ? 1 : 0,
      'deadline': deadline?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'hasFixedPayment': hasFixedPayment ? 1 : 0,
      'paymentFrequency': paymentFrequency,
      'paymentAmount': paymentAmount,
      'totalPayments': totalPayments,
      'completedPayments': completedPayments,
      'firstPaymentDate': firstPaymentDate?.toIso8601String(),
      'paymentHistory': paymentHistory.map((p) => p.toMap()).toList(),
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    DateTime parsedCreated;
    try {
      parsedCreated = DateTime.parse(map['createdAt']?.toString() ?? '');
    } catch (_) {
      parsedCreated = DateTime.now();
    }
    DateTime? parsedDeadline;
    if (map['deadline'] != null) {
      try {
        parsedDeadline = DateTime.parse(map['deadline'].toString());
      } catch (_) {}
    }
    DateTime? parsedFirstPayment;
    if (map['firstPaymentDate'] != null) {
      try {
        parsedFirstPayment = DateTime.parse(map['firstPaymentDate'].toString());
      } catch (_) {}
    }
    final productIdsStr = map['productIds']?.toString() ?? '';
    final productIds = productIdsStr.isEmpty ? <String>[] : productIdsStr.split(',');
    final List<PaymentRecord> history = [];
    if (map['paymentHistory'] is List) {
      for (final p in map['paymentHistory']) {
        try {
          history.add(PaymentRecord.fromMap(Map<String, dynamic>.from(p)));
        } catch (_) {}
      }
    }
    return Goal(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      productIds: productIds,
      targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 0,
      savedAmount: (map['savedAmount'] as num?)?.toDouble() ?? 0.0,
      isActive: map['isActive'] == 1 || map['isActive'] == true,
      deadline: parsedDeadline,
      createdAt: parsedCreated,
      hasFixedPayment: map['hasFixedPayment'] == 1 || map['hasFixedPayment'] == true,
      paymentFrequency: map['paymentFrequency']?.toString(),
      paymentAmount: (map['paymentAmount'] as num?)?.toDouble(),
      totalPayments: map['totalPayments'] as int?,
      completedPayments: map['completedPayments'] as int? ?? 0,
      firstPaymentDate: parsedFirstPayment,
      paymentHistory: history,
    );
  }

  Goal copyWith({
    String? id,
    String? name,
    List<String>? productIds,
    double? targetAmount,
    double? savedAmount,
    bool? isActive,
    DateTime? deadline,
    DateTime? createdAt,
    bool? hasFixedPayment,
    String? paymentFrequency,
    double? paymentAmount,
    int? totalPayments,
    int? completedPayments,
    DateTime? firstPaymentDate,
    List<PaymentRecord>? paymentHistory,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      productIds: productIds ?? this.productIds,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      isActive: isActive ?? this.isActive,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      hasFixedPayment: hasFixedPayment ?? this.hasFixedPayment,
      paymentFrequency: paymentFrequency ?? this.paymentFrequency,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      totalPayments: totalPayments ?? this.totalPayments,
      completedPayments: completedPayments ?? this.completedPayments,
      firstPaymentDate: firstPaymentDate ?? this.firstPaymentDate,
      paymentHistory: paymentHistory ?? this.paymentHistory,
    );
  }
}
