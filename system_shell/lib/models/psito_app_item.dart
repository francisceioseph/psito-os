// system_shell/lib/models/psito_app_item.dart
import 'package:flutter/material.dart';

class PsitoAppItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const PsitoAppItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}