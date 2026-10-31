import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/services/battery_service.dart';

import 'dbus_test_bus.dart';

FakeDBusObject _displayDevice({bool present = true}) => FakeDBusObject.single(
  UPowerBatteryService.path,
  UPowerBatteryService.interface,
  {
    'IsPresent': DBusBoolean(present),
    'Percentage': const DBusDouble(57),
    'State': const DBusUint32(2),
    'TimeToEmpty': const DBusInt64(12000),
    'TimeToFull': const DBusInt64(0),
  },
);

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late DBusTestBus bus;
  late UPowerBatteryService service;

  setUp(() async => bus = await DBusTestBus.start());
  tearDown(() async {
    await service.dispose();
    await bus.close();
  });

  Future<FakeDBusObject> start({bool present = true}) async {
    final device = _displayDevice(present: present);
    await bus.publish(UPowerBatteryService.busName, device);
    service = UPowerBatteryService(bus.shell);
    await service.ready;
    return device;
  }

  test('descarregando: porcentagem e tempo restante', () async {
    await start();
    expect(
      service.state.value,
      const BatteryState(
        available: true,
        present: true,
        percentage: 57,
        timeToEmpty: Duration(hours: 3, minutes: 20),
      ),
    );
  });

  test('passar a carregar chega pelo PropertiesChanged', () async {
    final device = await start();
    await device.change(UPowerBatteryService.interface, {
      'State': const DBusUint32(1),
      'TimeToEmpty': const DBusInt64(0),
      'TimeToFull': const DBusInt64(2400),
    });
    await _until(() => service.state.value.charging);

    final state = service.state.value;
    expect(state.charging, isTrue);
    expect(state.timeToEmpty, isNull);
    expect(state.timeToFull, const Duration(minutes: 40));
  });

  test('sem bateria a UPower responde, mas present é falso', () async {
    await start(present: false);
    expect(service.state.value.available, isTrue);
    expect(service.state.value.present, isFalse);
  });

  test('sem UPower fica indisponível', () async {
    service = UPowerBatteryService(bus.shell);
    await service.ready;
    expect(service.state.value, BatteryState.unavailable);
  });
}
