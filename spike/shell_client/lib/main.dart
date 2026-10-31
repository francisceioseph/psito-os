// spike/shell_client/lib/main.dart
//
// O shell do Psito como cliente layer-shell do compositor (fase 3, etapa 4).
// O runner cria uma superfície por parte do shell; aqui cada uma ganha a sua
// view, com os widgets e os serviços do system_shell.
import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:system_shell/services/system_services.dart';
import 'package:system_shell/shell/settings_store.dart';

import 'shell_bus.dart';
import 'shell_state.dart';
import 'toplevels.dart';
import 'views.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load(defaultSettingsFile());
  final state = ShellState(
    settings: settings,
    services: SystemServices.start(),
    toplevels: ToplevelList(),
  );
  final viewIds = await state.surfaces.viewIds();
  runWidget(ShellViews(state: state, viewIds: viewIds));

  unawaited(state.toplevels.start());
  unawaited(state.loadApps(Platform.environment));
  try {
    await publishShell(
      ShellBusObject(
        onToggleLauncher: () => state.toggle(ShellOverlay.launcher),
      ),
    );
  } on Exception catch (e) {
    debugPrint('🦜 shell: sem o barramento da sessão ($e)');
  }
}
