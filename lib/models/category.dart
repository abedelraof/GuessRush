import 'package:flutter/material.dart';

class Category {
  final String key;
  final String name;
  final String emoji;
  final Color bg;

  const Category({
    required this.key,
    required this.name,
    required this.emoji,
    required this.bg,
  });
}
