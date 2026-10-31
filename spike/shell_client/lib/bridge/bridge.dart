// spike/shell_client/lib/bridge/bridge.dart
//
// A ponte de configuração: as Configurações do Psito viram a configuração do
// compositor (atalhos e molduras) e o tema GTK. O compositor é o que o
// ambiente indica: LABWC_PID (labwc) ou WAYFIRE_SOCKET (Wayfire).
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:system_shell/shell/settings_store.dart';

import 'gtk_theme.dart';
import 'labwc.dart';
import 'wayfire.dart';

enum Compositor { labwc, wayfire, unknown }

Compositor detectCompositor(Map<String, String> env) {
  if (env.containsKey('LABWC_PID')) return Compositor.labwc;
  if (env.containsKey('WAYFIRE_SOCKET')) return Compositor.wayfire;
  return Compositor.unknown;
}

Directory configHome(Map<String, String> env) =>
    Directory(env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? '.'}/.config');

class Bridge {
  Bridge(this.settings, {Map<String, String>? environment})
    : env = environment ?? Platform.environment;

  final SettingsStore settings;
  final Map<String, String> env;
  Color? _applied;

  /// Aplica agora e de novo a cada mudança da cor de destaque.
  void start() {
    unawaited(apply());
    settings.addListener(() {
      if (settings.value.accent != _applied) unawaited(apply());
    });
  }

  Future<void> apply() async {
    final accent = settings.value.accent;
    _applied = accent;
    final compositor = detectCompositor(env);
    try {
      switch (compositor) {
        case Compositor.labwc:
          await applyLabwc(configHome(env), accent, environment: env);
        case Compositor.wayfire:
          await applyWayfire(env['WAYFIRE_SOCKET']!, accent);
        case Compositor.unknown:
          debugPrint('🦜 ponte: compositor desconhecido, sem atalhos');
      }
    } on Exception catch (e) {
      debugPrint('🦜 ponte: ${compositor.name} falhou ($e)');
    }
    try {
      final skipped = await applyGtkTheme(configHome(env), accent);
      for (final path in skipped) {
        debugPrint('🦜 ponte: $path é do usuário, ficou como está');
      }
    } on FileSystemException catch (e) {
      debugPrint('🦜 ponte: tema GTK falhou ($e)');
    }
    debugPrint('🦜 ponte: ${compositor.name}, destaque ${accent.toARGB32()}');
  }
}
