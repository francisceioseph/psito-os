// system_shell/lib/services/system_services.dart
//
// Os serviços do sistema que o shell consome. Reais via D-Bus ou falsos,
// para testes e para rodar onde os serviços não existem
// (PSITO_SERVICES=fake).
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import 'system_info_service.dart';

class SystemServices {
  final SystemInfoService systemInfo;

  /// Conexão com o barramento de sistema; null nos falsos.
  final DBusClient? _systemBus;

  SystemServices._({required this.systemInfo, this._systemBus});

  SystemServices.fake({SystemInfoService? systemInfo})
    : this._(systemInfo: systemInfo ?? FakeSystemInfoService());

  /// Não bloqueia o boot: cada serviço conecta e carrega em segundo plano e
  /// fica indisponível se o serviço não responder.
  static SystemServices start({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    if (env['PSITO_SERVICES'] == 'fake') {
      debugPrint('🦜 serviços: falsos (PSITO_SERVICES=fake)');
      return SystemServices.fake();
    }
    final bus = DBusClient.system();
    final systemInfo = HostnamedSystemInfoService(bus);
    systemInfo.ready.then((_) {
      final ok = systemInfo.info.value.available;
      debugPrint('🦜 serviços: systemInfo=${ok ? 'ok' : 'indisponível'}');
    });
    return SystemServices._(systemInfo: systemInfo, systemBus: bus);
  }

  Future<void> dispose() async {
    await systemInfo.dispose();
    await _systemBus?.close();
  }
}
