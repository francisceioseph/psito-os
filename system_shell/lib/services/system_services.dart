// system_shell/lib/services/system_services.dart
//
// Os serviços do sistema que o shell consome. Reais via D-Bus ou falsos,
// para testes e para rodar onde os serviços não existem
// (PSITO_SERVICES=fake).
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import 'audio_service.dart';
import 'battery_service.dart';
import 'network_service.dart';
import 'session_service.dart';
import 'system_info_service.dart';

class SystemServices {
  final SystemInfoService systemInfo;
  final NetworkService network;
  final AudioService audio;
  final BatteryService battery;
  final SessionService session;

  /// Conexão com o barramento de sistema; null nos falsos.
  final DBusClient? _systemBus;

  SystemServices._({
    required this.systemInfo,
    required this.network,
    required this.audio,
    required this.battery,
    required this.session,
    this._systemBus,
  });

  SystemServices.fake({
    SystemInfoService? systemInfo,
    NetworkService? network,
    AudioService? audio,
    BatteryService? battery,
    SessionService? session,
  }) : this._(
         systemInfo: systemInfo ?? FakeSystemInfoService(),
         network: network ?? FakeNetworkService(),
         audio: audio ?? FakeAudioService(),
         battery: battery ?? FakeBatteryService(),
         session: session ?? FakeSessionService(),
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
    final battery = UPowerBatteryService(bus);
    final session = LogindSessionService(bus);
    Future.wait([
      systemInfo.ready,
      network.ready,
      audio.ready,
      battery.ready,
      session.ready,
    ]).then((_) {
      String status(bool ok) => ok ? 'ok' : 'indisponível';
      debugPrint(
        '🦜 serviços: '
        'systemInfo=${status(systemInfo.info.value.available)} '
        'network=${status(network.state.value.available)} '
        'audio=${status(audio.state.value.available)} '
        'battery=${status(battery.state.value.available)} '
        'session=${session.capabilities.value}',
      );
    });
    return SystemServices._(
      systemInfo: systemInfo,
      network: network,
      audio: audio,
      battery: battery,
      session: session,
      systemBus: bus,
    );
  }

  Future<void> dispose() async {
    await systemInfo.dispose();
    await network.dispose();
    await audio.dispose();
    await battery.dispose();
    await session.dispose();
    await _systemBus?.close();
  }
}
