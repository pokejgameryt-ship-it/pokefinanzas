class Expense {
  final String id;
  final double amount;
  final String category;
  final String subcategory;
  final DateTime date;
  final String? description;
  final bool isRecurring;
  final String? recurringName;
  final String? transferTo;
  final bool isCash;
  final List<String> tags;

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    this.subcategory = '',
    required this.date,
    this.description,
    this.isRecurring = false,
    this.recurringName,
    this.transferTo,
    this.isCash = false,
    this.tags = const [],
  });

  bool get isTransfer => category == 'Transferencia';
  bool get isCashTransfer => category == 'Cajero';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'subcategory': subcategory,
      'date': date.toIso8601String(),
      'description': description,
      'isRecurring': isRecurring ? 1 : 0,
      'recurringName': recurringName,
      'transferTo': transferTo,
      'isCash': isCash ? 1 : 0,
      'tags': tags,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    final dateStr = map['date']?.toString() ?? '';
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(dateStr);
    } catch (_) {
      parsedDate = DateTime.now();
    }
    return Expense(
      id: map['id']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      category: map['category']?.toString() ?? '',
      subcategory: map['subcategory']?.toString() ?? '',
      date: parsedDate,
      description: map['description']?.toString(),
      isRecurring: map['isRecurring'] == 1 || map['isRecurring'] == true,
      recurringName: map['recurringName']?.toString(),
      transferTo: map['transferTo']?.toString(),
      isCash: map['isCash'] == 1 || map['isCash'] == true,
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Expense copyWith({
    String? id,
    double? amount,
    String? category,
    String? subcategory,
    DateTime? date,
    String? description,
    bool? isRecurring,
    String? recurringName,
    String? transferTo,
    bool? isCash,
    List<String>? tags,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      date: date ?? this.date,
      description: description ?? this.description,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringName: recurringName ?? this.recurringName,
      transferTo: transferTo ?? this.transferTo,
      isCash: isCash ?? this.isCash,
      tags: tags ?? this.tags,
    );
  }
}
