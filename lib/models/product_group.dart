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
    return ProductGroup(
      id: map['id'],
      name: map['name'],
      colorValue: map['colorValue'] ?? 0xFF607D8B,
      createdAt: DateTime.parse(map['createdAt']),
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
