import 'package:flutter/material.dart';

class ProductGroup {
  final String id;
  final String name;
  final int colorValue;
  final DateTime createdAt;

  ProductGroup({
    required this.id,
    required this.name,
    this.colorValue = 0xFF607D8B,
    required this.createdAt,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ProductGroup.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(map['createdAt']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }
    return ProductGroup(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF607D8B,
      createdAt: parsedDate,
    );
  }

  ProductGroup copyWith({
    String? id,
    String? name,
    int? colorValue,
    DateTime? createdAt,
  }) {
    return ProductGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
