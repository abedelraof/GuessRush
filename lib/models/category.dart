import 'package:flutter/material.dart';

class Category {
  final int id;
  final String key;
  final String name;
  final String emoji;
  final Color bg;

  const Category({
    required this.id,
    required this.key,
    required this.name,
    required this.emoji,
    required this.bg,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        key: json['key_slug'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String,
        bg: _colorFromHex(json['color_hex'] as String),
      );

  static Color _colorFromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
