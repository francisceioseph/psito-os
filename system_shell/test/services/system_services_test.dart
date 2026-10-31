import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/services/audio_service.dart';
import 'package:system_shell/services/battery_service.dart';
import 'package:system_shell/services/session_service.dart';
import 'package:system_shell/services/system_info_service.dart';
import 'package:system_shell/services/system_services.dart';

import 'dbus_test_bus.dart';

void main() {
  test('PSITO_SERVICES=fake não abre o barramento', () async {
    final services = SystemServices.start(
      environment: {'PSITO_SERVICES': 'fake'},
    );
    expect(services.systemInfo, isA<FakeSystemInfoService>());
    expect(services.systemInfo.info.value, FakeSystemInfoService.sample);
    await services.dispose();
  });

  test('sem nenhum serviço o boot segue e tudo fica indisponível', () async {
    final bus = await DBusTestBus.start();
    addTearDown(bus.close);
    final audio = PipewireAudioService(
      run: (_, _) async => ProcessResult(0, 1, '', 'wpctl: no server'),
      subscribe: () => const Stream.empty(),
    );

    final services = SystemServices.start(
      environment: const {},
      systemBus: bus.shell,
      audio: audio,
    );
    await services.ready;

    expect(services.systemInfo.info.value, PsitoSystemInfo.unavailable);
    expect(services.network.state.value, PsitoNetworkState.unavailable);
    expect(services.audio.state.value, AudioState.unavailable);
    expect(services.battery.state.value, BatteryState.unavailable);
    expect(services.session.capabilities.value, SessionCapabilities.none);
    expect(services.time.state.value, PsitoTimeState.unavailable);
    expect(services.time.now(), isA<DateTime>());

    await services.dispose();
  });
}
