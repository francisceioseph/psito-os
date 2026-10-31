import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/services/session_service.dart';

import 'dbus_test_bus.dart';

void main() {
  late DBusTestBus bus;
  late LogindSessionService service;
  late FakeDBusObject manager;

  setUp(() async {
    bus = await DBusTestBus.start();
    manager = FakeDBusObject.single(
      LogindSessionService.path,
      LogindSessionService.interface,
      {},
    );
    manager.replies.addAll({
      'CanPowerOff': [const DBusString('yes')],
      'CanReboot': [const DBusString('challenge')],
      'CanSuspend': [const DBusString('no')],
    });
  });

  tearDown(() async {
    await service.dispose();
    await bus.close();
  });

  Future<void> start() async {
    await bus.publish(LogindSessionService.busName, manager);
    service = LogindSessionService(bus.shell);
    await service.ready;
  }

  test('só "yes" habilita; challenge exigiria senha', () async {
    await start();
    expect(
      service.capabilities.value,
      const SessionCapabilities(canPowerOff: true),
    );
    expect('${service.capabilities.value}', 'poweroff');
  });

  test('as ações chamam o logind sem interação', () async {
    await start();
    manager.calls.clear();
    await service.powerOff();
    await service.reboot();
    await service.suspend();

    expect(manager.calls.map((c) => c.name), ['PowerOff', 'Reboot', 'Suspend']);
    for (final call in manager.calls) {
      expect(call.interface, LogindSessionService.interface);
      expect(call.values, [const DBusBoolean(false)]);
    }
  });

  test('sem logind nada fica habilitado', () async {
    service = LogindSessionService(bus.shell);
    await service.ready;
    expect(service.capabilities.value, SessionCapabilities.none);
    expect('${service.capabilities.value}', 'nenhuma');
  });
}
