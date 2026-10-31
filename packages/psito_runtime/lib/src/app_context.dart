// packages/psito_runtime/lib/src/app_context.dart
//
// O PsitoAppContext de um app no próprio processo: os serviços do sistema
// direto pelo D-Bus, as configurações pelo shell (org.psito.Settings) e as
// notificações pelo servidor do shell.
import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/launcher_client.dart';
import 'package:psito_services/network_service.dart';
import 'package:psito_services/system_info_service.dart';
import 'package:psito_services/time_service.dart';

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
  final AppServices services;
  final AppWindow window;

  @override
  final ValueListenable<PsitoSettings> settings;

  /// Pede ao shell para gravar as configurações.
  final void Function(PsitoSettings) onUpdateSettings;

  /// Manda a notificação ao shell.
  final void Function(PsitoNotification) onNotify;

  @override
  final String windowId;

  /// O shell que abre os arquivos. Null fora de uma sessão (nos testes).
  final LauncherClient? launcher;

  @override
  final List<String> openedPaths;

  @override
  final Stream<List<String>> openRequests;

  ProcessAppContext({
    required this.app,
    required this.settings,
    required this.services,
    required this.onUpdateSettings,
    required this.onNotify,
    this.window = const AppWindow(),
    required this.windowId,
    this.launcher,
    this.openedPaths = const [],
    this.openRequests = const Stream.empty(),
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
  ValueListenable<PsitoSystemInfo> get systemInfo => services.systemInfo.info;

  @override
  ValueListenable<PsitoNetworkState> get network => services.network.state;

  @override
  ValueListenable<PsitoTimeState> get time => services.time.state;

  @override
  DateTime now() => services.time.now();

  @override
  Future<List<String>> timezones() => services.time.timezones();

  /// Só apps com [PsitoApp.canChangeSettings] mexem no sistema. No sandbox,
  /// o filtro do D-Bus também barra os outros.
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
    if (_mayChange('as configurações')) onUpdateSettings(settings);
  }

  @override
  Future<void> open(List<String> paths, {String? withApp}) async {
    final launcher = this.launcher;
    if (launcher == null) {
      throw const PsitoOpenException('Sem o shell para abrir arquivos.');
    }
    await launcher.open(paths, withApp: withApp);
  }

  @override
  Future<List<PsitoAppChoice>> appsFor(String mimeType) async =>
      await launcher?.appsFor(mimeType) ?? const [];

  @override
  Future<void> setDefaultApp(String mimeType, String appId) async =>
      launcher?.setDefault(mimeType, appId);
}
