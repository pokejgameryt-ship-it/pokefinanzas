class DailyIncome {
  final String id;
  final DateTime date;
  final double hoursWorked;
  final double hourlyRate;
  final double totalAmount;
  final String? notes;
  final String type;
  final bool isRecurring;
  final String? recurringName;
  final bool isCash;

  DailyIncome({
    required this.id,
    required this.date,
    this.hoursWorked = 0,
    this.hourlyRate = 0,
    required this.totalAmount,
    this.notes,
    this.type = 'fixed',
    this.isRecurring = false,
    this.recurringName,
    this.isCash = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'hoursWorked': hoursWorked,
      'hourlyRate': hourlyRate,
      'totalAmount': totalAmount,
      'notes': notes,
      'type': type,
      'isRecurring': isRecurring ? 1 : 0,
      'recurringName': recurringName,
      'isCash': isCash ? 1 : 0,
    };
  }

  factory DailyIncome.fromMap(Map<String, dynamic> map) {
    return DailyIncome(
      id: map['id'],
      date: DateTime.parse(map['date']),
      hoursWorked: map['hoursWorked'] ?? 0,
      hourlyRate: map['hourlyRate'] ?? 0,
      totalAmount: map['totalAmount'],
      notes: map['notes'],
      type: map['type'] ?? 'fixed',
      isRecurring: map['isRecurring'] == 1,
      recurringName: map['recurringName'],
      isCash: map['isCash'] == 1,
    );
  }

  DailyIncome copyWith({
    String? id,
    DateTime? date,
    double? hoursWorked,
    double? hourlyRate,
    double? totalAmount,
    String? notes,
    String? type,
    bool? isRecurring,
    String? recurringName,
    bool? isCash,
  }) {
    return DailyIncome(
      id: id ?? this.id,
      date: date ?? this.date,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      type: type ?? this.type,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringName: recurringName ?? this.recurringName,
      isCash: isCash ?? this.isCash,
    );
  }
}
