// apps/lib/app_context.dart
//
// O PsitoAppContext de um app no próprio processo: os serviços do sistema
// direto pelo D-Bus, as configurações pelo settings.json (que o shell vigia)
// e as notificações pelo servidor do shell.
import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/services/network_service.dart';
import 'package:system_shell/services/system_info_service.dart';
import 'package:system_shell/services/time_service.dart';
import 'package:system_shell/shell/settings_store.dart';

import 'window.dart';

/// Os serviços que um app lê. Menos que os do shell: sem áudio, bateria e
/// sessão, que só o shell usa.
class AppServices {
  final SystemInfoService systemInfo;
  final NetworkService network;
  final TimeService time;

  const AppServices({
    required this.systemInfo,
    required this.network,
    required this.time,
  });
}

class ProcessAppContext implements PsitoAppContext {
  final PsitoApp app;
  final SettingsStore store;
  final AppServices services;
  final AppWindow window;

  /// Manda a notificação ao shell.
  final void Function(PsitoNotification) onNotify;

  @override
  final String windowId;

  ProcessAppContext({
    required this.app,
    required this.store,
    required this.services,
    required this.onNotify,
    this.window = const AppWindow(),
    required this.windowId,
  });

  @override
  void setTitle(String title) => window.setTitle(title);

  @override
  void close() {
    app.onClose(this);
    window.close();
  }

  @override
  void notify(PsitoNotification notification) => onNotify(notification);

  @override
  ValueListenable<PsitoSettings> get settings => store;

  @override
  ValueListenable<PsitoSystemInfo> get systemInfo => services.systemInfo.info;

  @override
  ValueListenable<PsitoNetworkState> get network => services.network.state;

  @override
  ValueListenable<PsitoTimeState> get time => services.time.state;

  @override
  DateTime now() => services.time.now();

  @override
  Future<List<String>> timezones() => services.time.timezones();

  /// Só apps com [PsitoApp.canChangeSettings] mexem no sistema.
  bool _mayChange(String what) {
    if (app.canChangeSettings) return true;
    debugPrint('🦜 ${app.id} não pode alterar $what');
    return false;
  }

  @override
  void setTimezone(String timezone) {
    if (_mayChange('o fuso')) services.time.setTimezone(timezone);
  }

  @override
  void setNtp(bool enabled) {
    if (_mayChange('o NTP')) services.time.setNtp(enabled);
  }

  @override
  void updateSettings(PsitoSettings settings) {
    if (_mayChange('as configurações')) store.update(settings);
  }
}
