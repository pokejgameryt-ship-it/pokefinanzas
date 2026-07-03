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
    return Product(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      isFavorite: map['isFavorite'] == 1,
      groupId: map['groupId'] as String?,
      createdAt: DateTime.parse(map['createdAt']),
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
