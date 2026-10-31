// system_shell/lib/shell/app_entry.dart
import 'package:flutter/widgets.dart';
import 'package:psito_sdk/psito_sdk.dart';

/// O que a dock, o launcher e a busca precisam de um app: o bastante para
/// mostrar e abrir. Serve tanto para um [PsitoApp] quanto para um app de fora
/// (um `.desktop`, no shell como cliente do compositor).
class AppEntry {
  final String id;
  final String name;
  final Color color;

  /// O ícone no tamanho pedido.
  final Widget Function(double size) icon;

  const AppEntry({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  factory AppEntry.fromPsitoApp(PsitoApp app) => AppEntry(
    id: app.id,
    name: app.name,
    color: app.color,
    icon: (size) => Icon(app.icon, size: size, color: app.color),
  );
}
