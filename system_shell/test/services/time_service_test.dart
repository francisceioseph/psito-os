import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/services/time_service.dart';

import 'dbus_test_bus.dart';

const _iface = TimedatedTimeService.interface;

FakeDBusObject _timedate1(String timezone) {
  final object = FakeDBusObject.single(TimedatedTimeService.path, _iface, {
    'Timezone': DBusString(timezone),
    'NTP': const DBusBoolean(true),
    'NTPSynchronized': const DBusBoolean(true),
    'CanNTP': const DBusBoolean(true),
  });
  object.replies['ListTimezones'] = [
    DBusArray.string(['America/Fortaleza', 'Asia/Tokyo']),
  ];
  return object;
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late DBusTestBus bus;
  late TimedatedTimeService service;

  setUp(() async => bus = await DBusTestBus.start());
  tearDown(() async {
    await service.dispose();
    await bus.close();
  });

  Future<FakeDBusObject> start([String timezone = 'America/Fortaleza']) async {
    final object = _timedate1(timezone);
    await bus.publish(TimedatedTimeService.busName, object);
    service = TimedatedTimeService(bus.shell);
    await service.ready;
    return object;
  }

  test('lê fuso e NTP do timedated', () async {
    await start();
    expect(
      service.state.value,
      const PsitoTimeState(
        available: true,
        timezone: 'America/Fortaleza',
        ntp: true,
        ntpSynchronized: true,
        canNtp: true,
      ),
    );
  });

  test('now() segue o fuso do sistema, inclusive quando muda', () async {
    final object = await start();
    expect(service.now().timeZoneOffset, const Duration(hours: -3));

    await object.change(_iface, {'Timezone': const DBusString('Asia/Tokyo')});
    await _until(() => service.state.value.timezone == 'Asia/Tokyo');
    expect(service.now().timeZoneOffset, const Duration(hours: 9));

    // O instante é o mesmo; só o fuso muda
    final drift = service.now().toUtc().difference(DateTime.now().toUtc());
    expect(drift.inSeconds.abs(), lessThan(2));
  });

  test('setTimezone e setNtp chamam o timedated sem interação', () async {
    final object = await start();
    await service.setTimezone('Europe/Lisbon');
    await service.setNtp(false);

    final calls = object.calls.where((c) => c.name.startsWith('Set')).toList();
    expect(calls.map((c) => c.name), ['SetTimezone', 'SetNTP']);
    expect(calls[0].values, [
      const DBusString('Europe/Lisbon'),
      const DBusBoolean(false),
    ]);
    expect(calls[1].values, [
      const DBusBoolean(false),
      const DBusBoolean(false),
    ]);
  });

  test('timezones() vem do ListTimezones', () async {
    await start();
    expect(await service.timezones(), ['America/Fortaleza', 'Asia/Tokyo']);
  });

  test('fuso desconhecido cai no relógio local', () async {
    await start('Marte/Olympus_Mons');
    expect(service.state.value.timezone, 'Marte/Olympus_Mons');
    expect(service.now().timeZoneOffset, DateTime.now().timeZoneOffset);
  });

  test('sem timedated fica indisponível', () async {
    service = TimedatedTimeService(bus.shell);
    await service.ready;
    expect(service.state.value, PsitoTimeState.unavailable);
  });
}
