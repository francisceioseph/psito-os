// shell/lib/app_icon.dart
//
// Ícones do tema do sistema. O runner carrega pelo GtkIconTheme (que também
// lê SVG) e devolve um PNG, então o Dart não precisa de pacote de SVG.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/shell/app_entry.dart';
import 'package:system_shell/shell/app_registry.dart';

import 'desktop_entries.dart';

const _channel = MethodChannel('psito/icons');

/// Os ícones são carregados uma vez, no tamanho maior que a dock usa.
const _loadSize = 96;
final _cache = <String, Future<Uint8List?>>{};

Future<Uint8List?> _load(String name) => _cache.putIfAbsent(
  name,
  () => _channel.invokeMethod<Uint8List>('iconPng', {
    'name': name,
    'size': _loadSize,
  }),
);

class AppIcon extends StatelessWidget {
  final String? name;
  final double size;

  const AppIcon(this.name, {super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      Icons.apps_rounded,
      size: size,
      color: Colors.white70,
    );
    final name = this.name;
    if (name == null) return fallback;
    return FutureBuilder(
      future: _load(name),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return snapshot.connectionState == ConnectionState.done
              ? fallback
              : SizedBox.square(dimension: size);
        }
        return Image.memory(
          bytes,
          width: size,
          height: size,
          filterQuality: FilterQuality.medium,
        );
      },
    );
  }
}

/// O prefixo do `app_id` e do `.desktop` dos apps do Psito (`apps/`).
const psitoAppPrefix = 'org.psito.';

/// O app do Psito com esse `app_id` (`org.psito.<id>`), se for um.
PsitoApp? psitoAppFor(String appId) {
  if (!appId.startsWith(psitoAppPrefix)) return null;
  final id = appId.substring(psitoAppPrefix.length);
  for (final app in registeredApps) {
    if (app.id == id) return app;
  }
  return null;
}

/// Um app para os widgets do system_shell: os do Psito com o ícone e a cor
/// deles; os de fora com o ícone do tema.
AppEntry appEntry(
  String id,
  String name,
  DesktopEntry? desktop,
  Color color, {
  String? icon,
}) {
  final psito = psitoAppFor(id);
  if (psito != null) {
    return AppEntry(
      id: id,
      name: psito.name,
      color: psito.color,
      icon: (size) => Icon(psito.icon, size: size, color: psito.color),
    );
  }
  return AppEntry(
    id: id,
    name: name,
    color: color,
    icon: (size) => AppIcon(desktop?.icon ?? icon, size: size),
  );
}
