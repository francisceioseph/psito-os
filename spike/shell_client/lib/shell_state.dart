// spike/shell_client/lib/shell_state.dart
//
// O estado do shell, um só para todas as superfícies: as views da top bar,
// da dock e da sobreposição leem e mudam este mesmo objeto.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:system_shell/services/system_services.dart';
import 'package:system_shell/shell/notification_center.dart';
import 'package:system_shell/shell/settings_store.dart';

import 'desktop_entries.dart';
import 'dock_model.dart';
import 'surfaces.dart';
import 'toplevels.dart';

/// O que a sobreposição mostra; só uma coisa por vez, como no system_shell.
enum ShellOverlay { launcher, notifications, network, volume, battery, power }

/// Ações de energia que pedem confirmação.
enum PowerAction { powerOff, reboot }

class ShellState {
  ShellState({
    required this.settings,
    required this.services,
    required this.toplevels,
    this.surfaces = const Surfaces(),
  }) {
    overlay.addListener(_syncOverlay);
    confirm.addListener(_syncOverlay);
  }

  final SettingsStore settings;
  final SystemServices services;
  final ToplevelList toplevels;
  final Surfaces surfaces;

  late final notifications = NotificationCenter(
    silent: () => settings.value.doNotDisturb,
  );

  /// Os apps de fora, dos `.desktop`.
  final apps = ValueNotifier<List<DesktopEntry>>(const []);

  /// Fixados na dock, por id do `.desktop`.
  static const pinned = ['firefox-esr', 'foot', 'org.gtk.Demo4'];

  final overlay = ValueNotifier<ShellOverlay?>(null);
  final confirm = ValueNotifier<PowerAction?>(null);

  Future<void> loadApps(Map<String, String> env) async {
    apps.value = await loadDesktopEntries(
      desktopEntryDirs(env),
      locale: env['LANG'],
    );
  }

  /// Abrir uma camada fecha a que estiver aberta; abrir a mesma fecha.
  void toggle(ShellOverlay value) {
    overlay.value = overlay.value == value ? null : value;
    if (overlay.value == ShellOverlay.notifications) {
      notifications.markAllRead();
    }
  }

  void closeOverlay() => overlay.value = null;

  void askPower(PowerAction action) {
    closeOverlay();
    confirm.value = action;
  }

  void runPower(PowerAction action) {
    confirm.value = null;
    switch (action) {
      case PowerAction.powerOff:
        services.session.powerOff();
      case PowerAction.reboot:
        services.session.reboot();
    }
  }

  List<DockSlot> get dockSlots => dockSlotsFor(
    pinned: pinned,
    entries: {for (final app in apps.value) app.id: app},
    windows: toplevels.windows,
  );

  void tapDock(DockSlot slot) {
    switch (tapAction(slot)) {
      case LaunchApp(:final entry):
        unawaited(entry.launch());
      case ActivateWindow(:final id):
        unawaited(toplevels.activate(id));
      case MinimizeWindow(:final id):
        unawaited(toplevels.minimize(id));
      case null:
        break;
    }
  }

  void launch(DesktopEntry entry) {
    closeOverlay();
    unawaited(entry.launch());
  }

  /// A superfície da sobreposição existe só enquanto tem algo aberto.
  void _syncOverlay() {
    if (confirm.value != null || overlay.value == ShellOverlay.launcher) {
      unawaited(surfaces.showOverlay(OverlayKeyboard.exclusive));
    } else if (overlay.value != null) {
      unawaited(surfaces.showOverlay(OverlayKeyboard.onDemand));
    } else {
      unawaited(surfaces.hideOverlay());
    }
  }
}
