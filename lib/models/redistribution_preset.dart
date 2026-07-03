class RedistributionPreset {
  final String id;
  final String name;
  final String type; // 'general' or 'individual'
  final String? categoryName; // only for individual type
  final Map<String, Map<String, double>>? categories; // for general: categoryName -> percentages
  final Map<String, double>? singleCategory; // for individual: percentages
  final DateTime createdAt;

  const RedistributionPreset({
    required this.id,
    required this.name,
    required this.type,
    this.categoryName,
    this.categories,
    this.singleCategory,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'categoryName': categoryName,
      'categories': categories?.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v))),
      'singleCategory': singleCategory,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RedistributionPreset.fromMap(Map<String, dynamic> map) {
    Map<String, Map<String, double>>? categories;
    if (map['categories'] != null) {
      categories = (map['categories'] as Map<String, dynamic>).map((k, v) {
        return MapEntry(k, (v as Map<String, dynamic>).map((k2, v2) => MapEntry(k2, (v2 as num).toDouble())));
      });
    }

    Map<String, double>? singleCategory;
    if (map['singleCategory'] != null) {
      singleCategory = (map['singleCategory'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    return RedistributionPreset(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      categoryName: map['categoryName'],
      categories: categories,
      singleCategory: singleCategory,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  RedistributionPreset copyWith({
    String? id,
    String? name,
    String? type,
    String? categoryName,
    Map<String, Map<String, double>>? categories,
    Map<String, double>? singleCategory,
  }) {
    return RedistributionPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      categoryName: categoryName ?? this.categoryName,
      categories: categories ?? this.categories,
      singleCategory: singleCategory ?? this.singleCategory,
      createdAt: createdAt,
    );
  }
}
