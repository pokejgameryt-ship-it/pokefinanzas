import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final bool isDefault;
  final bool isEnabled;
  final int order;

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.isDefault = false,
    this.isEnabled = true,
    this.order = 0,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'isDefault': isDefault ? 1 : 0,
      'isEnabled': isEnabled ? 1 : 0,
      'order': order,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      iconCodePoint: (map['iconCodePoint'] as num?)?.toInt() ?? Icons.category.codePoint,
      colorValue: (map['colorValue'] as num?)?.toInt() ?? Colors.grey.value,
      isDefault: map['isDefault'] == 1 || map['isDefault'] == true,
      isEnabled: map['isEnabled'] != 0 && map['isEnabled'] != false,
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    int? colorValue,
    bool? isDefault,
    bool? isEnabled,
    int? order,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
      isEnabled: isEnabled ?? this.isEnabled,
      order: order ?? this.order,
    );
  }

  static List<CategoryModel> get defaultCategories => [
    CategoryModel(
      id: 'cat_alquiler',
      name: 'Alquiler',
      iconCodePoint: Icons.home.codePoint,
      colorValue: const Color(0xFFE53935).value,
      isDefault: true,
      order: 0,
    ),
    CategoryModel(
      id: 'cat_comida',
      name: 'Comida',
      iconCodePoint: Icons.restaurant.codePoint,
      colorValue: const Color(0xFFFF9800).value,
      isDefault: true,
      order: 1,
    ),
    CategoryModel(
      id: 'cat_transporte',
      name: 'Transporte',
      iconCodePoint: Icons.directions_bus.codePoint,
      colorValue: const Color(0xFF2196F3).value,
      isDefault: true,
      order: 2,
    ),
    CategoryModel(
      id: 'cat_servicios',
      name: 'Servicios',
      iconCodePoint: Icons.bolt.codePoint,
      colorValue: const Color(0xFFFFC107).value,
      isDefault: true,
      order: 3,
    ),
    CategoryModel(
      id: 'cat_ocio',
      name: 'Ocio',
      iconCodePoint: Icons.sports_esports.codePoint,
      colorValue: const Color(0xFF9C27B0).value,
      isDefault: true,
      order: 4,
    ),
    CategoryModel(
      id: 'cat_salud',
      name: 'Salud',
      iconCodePoint: Icons.local_hospital.codePoint,
      colorValue: const Color(0xFF4CAF50).value,
      isDefault: true,
      order: 5,
    ),
    CategoryModel(
      id: 'cat_ropa',
      name: 'Ropa',
      iconCodePoint: Icons.checkroom.codePoint,
      colorValue: const Color(0xFF795548).value,
      isDefault: true,
      order: 6,
    ),
    CategoryModel(
      id: 'cat_ahorro',
      name: 'Ahorro',
      iconCodePoint: Icons.savings.codePoint,
      colorValue: const Color(0xFF00BCD4).value,
      isDefault: true,
      order: 7,
    ),
    CategoryModel(
      id: 'cat_otros',
      name: 'Otros',
      iconCodePoint: Icons.more_horiz.codePoint,
      colorValue: const Color(0xFF607D8B).value,
      isDefault: true,
      order: 8,
    ),
  ];
}
