class Product {
  final String id;
  final String name;
  final double price;
  final bool isFavorite;
  final String? groupId;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.isFavorite = false,
    this.groupId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'isFavorite': isFavorite ? 1 : 0,
      'groupId': groupId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(map['createdAt']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }
    return Product(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      isFavorite: map['isFavorite'] == 1 || map['isFavorite'] == true,
      groupId: map['groupId']?.toString(),
      createdAt: parsedDate,
    );
  }

  Product copyWith({
    String? id,
    String? name,
    double? price,
    bool? isFavorite,
    String? groupId,
    bool clearGroupId = false,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isFavorite: isFavorite ?? this.isFavorite,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
