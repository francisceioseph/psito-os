// packages/psito_services/lib/system_services.dart
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
import 'time_service.dart';

class SystemServices {
  final SystemInfoService systemInfo;
  final NetworkService network;
  final AudioService audio;
  final BatteryService battery;
  final SessionService session;
  final TimeService time;

  /// Completa quando todos terminaram a primeira carga, com ou sem sucesso.
  final Future<void> ready;

  /// Conexão com o barramento de sistema aberta por [start]; fecha no
  /// [dispose]. Null nos falsos e quando o barramento vem de fora.
  final DBusClient? _ownedBus;

  SystemServices._({
    required this.systemInfo,
    required this.network,
    required this.audio,
    required this.battery,
    required this.session,
    required this.time,
    required this.ready,
    this._ownedBus,
  });

  SystemServices.fake({
    SystemInfoService? systemInfo,
    NetworkService? network,
    AudioService? audio,
    BatteryService? battery,
    SessionService? session,
    TimeService? time,
  }) : this._(
         systemInfo: systemInfo ?? FakeSystemInfoService(),
         network: network ?? FakeNetworkService(),
         audio: audio ?? FakeAudioService(),
         battery: battery ?? FakeBatteryService(),
         session: session ?? FakeSessionService(),
         time: time ?? FakeTimeService(),
         ready: Future.value(),
       );

  /// Não bloqueia o boot: cada serviço conecta e carrega em segundo plano e
  /// fica indisponível se o serviço não responder.
  ///
  /// [systemBus] e [audio] trocam o barramento de sistema e o PipeWire nos
  /// testes.
  static SystemServices start({
    Map<String, String>? environment,
    DBusClient? systemBus,
    PipewireAudioService? audio,
  }) {
    final env = environment ?? Platform.environment;
    if (env['PSITO_SERVICES'] == 'fake') {
      debugPrint('🦜 serviços: falsos (PSITO_SERVICES=fake)');
      return SystemServices.fake();
    }
    final bus = systemBus ?? DBusClient.system();
    final systemInfo = HostnamedSystemInfoService(bus);
    final network = NetworkManagerService(bus);
    audio ??= PipewireAudioService();
    final battery = UPowerBatteryService(bus);
    final session = LogindSessionService(bus);
    final time = TimedatedTimeService(bus);
    final ready = Future.wait([
      systemInfo.ready,
      network.ready,
      audio.ready,
      battery.ready,
      session.ready,
      time.ready,
    ]);
    ready.then((_) {
      String status(bool ok) => ok ? 'ok' : 'unavailable';
      debugPrint(
        '🦜 serviços: '
        'systemInfo=${status(systemInfo.info.value.available)} '
        'network=${status(network.state.value.available)} '
        'audio=${status(audio!.state.value.available)} '
        'battery=${status(battery.state.value.available)} '
        'time=${status(time.state.value.available)} '
        'session=${session.capabilities.value}',
      );
    });
    return SystemServices._(
      systemInfo: systemInfo,
      network: network,
      audio: audio,
      battery: battery,
      session: session,
      time: time,
      ready: ready,
      ownedBus: systemBus == null ? bus : null,
    );
  }

  Future<void> dispose() async {
    await systemInfo.dispose();
    await network.dispose();
    await audio.dispose();
    await battery.dispose();
    await session.dispose();
    await time.dispose();
    await _ownedBus?.close();
  }
}
