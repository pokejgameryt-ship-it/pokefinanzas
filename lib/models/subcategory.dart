class Subcategory {
  final String id;
  final String name;
  final String categoryId; // parent category name

  Subcategory({
    required this.id,
    required this.name,
    required this.categoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'categoryId': categoryId,
    };
  }

  factory Subcategory.fromMap(Map<String, dynamic> map) {
    return Subcategory(
      id: map['id'],
      name: map['name'],
      categoryId: map['categoryId'],
    );
  }

  Subcategory copyWith({
    String? id,
    String? name,
    String? categoryId,
  }) {
    return Subcategory(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}
