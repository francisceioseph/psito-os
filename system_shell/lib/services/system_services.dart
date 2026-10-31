// system_shell/lib/services/system_services.dart
//
// Os serviços do sistema que o shell consome. Reais via D-Bus ou falsos,
// para testes e para rodar onde os serviços não existem
// (PSITO_SERVICES=fake).
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import 'audio_service.dart';
import 'network_service.dart';
import 'system_info_service.dart';

class SystemServices {
  final SystemInfoService systemInfo;
  final NetworkService network;
  final AudioService audio;

  /// Conexão com o barramento de sistema; null nos falsos.
  final DBusClient? _systemBus;

  SystemServices._({
    required this.systemInfo,
    required this.network,
    required this.audio,
    this._systemBus,
  });

  SystemServices.fake({
    SystemInfoService? systemInfo,
    NetworkService? network,
    AudioService? audio,
  }) : this._(
         systemInfo: systemInfo ?? FakeSystemInfoService(),
         network: network ?? FakeNetworkService(),
         audio: audio ?? FakeAudioService(),
       );

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
    final network = NetworkManagerService(bus);
    final audio = PipewireAudioService();
    Future.wait([systemInfo.ready, network.ready, audio.ready]).then((_) {
      String status(bool ok) => ok ? 'ok' : 'indisponível';
      debugPrint(
        '🦜 serviços: '
        'systemInfo=${status(systemInfo.info.value.available)} '
        'network=${status(network.state.value.available)} '
        'audio=${status(audio.state.value.available)}',
      );
    });
    return SystemServices._(
      systemInfo: systemInfo,
      network: network,
      audio: audio,
      systemBus: bus,
    );
  }

  Future<void> dispose() async {
    await systemInfo.dispose();
    await network.dispose();
    await audio.dispose();
    await _systemBus?.close();
  }
}
