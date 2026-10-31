// shell/lib/app_icon.dart
//
// Os ícones dos apps, do tema do sistema pelo PsitoIcon do SDK (o plugin do
// psito_runtime carrega pelo GtkIconTheme, que também lê SVG).
import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/shell/app_entry.dart';

import 'desktop_entries.dart';

class AppIcon extends StatelessWidget {
  final String? name;
  final double size;

  const AppIcon(this.name, {super.key, required this.size});

  @override
  Widget build(BuildContext context) => PsitoIcon(
    [?name],
    size: size,
    fallback: Icon(Icons.apps_rounded, size: size, color: Colors.white70),
  );
}

/// Um app para os widgets do system_shell, com o ícone do tema. Os do Psito
/// têm a cor do manifesto (`X-Psito-Color`); os de fora, a de destaque.
AppEntry appEntry(
  String id,
  String name,
  DesktopEntry? desktop,
  Color color, {
  String? icon,
}) {
  final psitoColor = desktop?.color;
  return AppEntry(
    id: id,
    name: name,
    color: psitoColor != null ? Color(psitoColor) : color,
    icon: (size) => AppIcon(desktop?.icon ?? icon, size: size),
  );
}

/// Uma pasta ou um arquivo na dock, com o ícone do tema ([icons], o
/// primeiro que existir).
AppEntry pathEntry(String id, String name, List<String> icons, Color color) =>
    AppEntry(
      id: id,
      name: name,
      color: color,
      icon: (size) => PsitoIcon(
        icons,
        size: size,
        fallback: Icon(
          Icons.insert_drive_file_outlined,
          size: size,
          color: Colors.white70,
        ),
      ),
    );
