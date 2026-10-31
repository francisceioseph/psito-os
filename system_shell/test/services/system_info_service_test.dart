import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/services/system_info_service.dart';
import 'package:system_shell/services/system_services.dart';

import 'dbus_test_bus.dart';

FakePropertiesObject _hostname1({String pretty = ''}) => FakePropertiesObject(
  HostnamedSystemInfoService.path,
  HostnamedSystemInfoService.interface,
  {
    'Hostname': const DBusString('psito-os'),
    'PrettyHostname': DBusString(pretty),
    'OperatingSystemPrettyName': const DBusString(
      'Debian GNU/Linux 13 (trixie)',
    ),
    'KernelRelease': const DBusString('6.12.107+deb13-amd64'),
    'HardwareVendor': const DBusString('QEMU'),
    'HardwareModel': const DBusString('Standard PC (i440FX + PIIX, 1996)'),
  },
);

/// Espera o estado mudar (sinais chegam de forma assíncrona).
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late DBusTestBus bus;

  setUp(() async => bus = await DBusTestBus.start());
  tearDown(() => bus.close());

  test('lê o hostnamed e usa Hostname quando PrettyHostname é vazio', () async {
    await bus.publish(HostnamedSystemInfoService.busName, _hostname1());
    final service = HostnamedSystemInfoService(bus.shell);
    await service.ready;

    expect(
      service.info.value,
      const PsitoSystemInfo(
        available: true,
        hostname: 'psito-os',
        osName: 'Debian GNU/Linux 13 (trixie)',
        kernel: '6.12.107+deb13-amd64',
        hardware: 'QEMU Standard PC (i440FX + PIIX, 1996)',
      ),
    );
    await service.dispose();
  });

  test('PrettyHostname tem prioridade e mudanças chegam na hora', () async {
    final object = _hostname1(pretty: 'Calopsita');
    await bus.publish(HostnamedSystemInfoService.busName, object);
    final service = HostnamedSystemInfoService(bus.shell);
    await service.ready;
    expect(service.info.value.hostname, 'Calopsita');

    await object.change({'PrettyHostname': const DBusString('Psito Teste')});
    await _until(() => service.info.value.hostname == 'Psito Teste');
    expect(service.info.value.hostname, 'Psito Teste');
    await service.dispose();
  });

  test('sem hostnamed no barramento fica indisponível', () async {
    final service = HostnamedSystemInfoService(bus.shell);
    await service.ready;
    expect(service.info.value, PsitoSystemInfo.unavailable);
    await service.dispose();
  });

  test('PSITO_SERVICES=fake não abre o barramento', () async {
    final services = SystemServices.start(
      environment: {'PSITO_SERVICES': 'fake'},
    );
    expect(services.systemInfo, isA<FakeSystemInfoService>());
    expect(services.systemInfo.info.value, FakeSystemInfoService.sample);
    await services.dispose();
  });
}
