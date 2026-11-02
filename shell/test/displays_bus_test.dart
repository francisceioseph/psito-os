// O org.psito.Displays num barramento privado, pelo cliente de verdade.
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/displays_client.dart';
import 'package:psito_shell/displays_bus.dart';

void main() {
  late Directory dir;
  late DBusServer server;
  late DBusClient shellBus;
  late DBusClient appBus;
  late FakeDisplays displays;
  late DisplaysBusObject object;
  late DisplaysClient client;
  var allowed = true;

  setUp(() async {
    allowed = true;
    dir = await Directory.systemTemp.createTemp('psito_displays_');
    server = DBusServer();
    final address = await server.listenAddress(DBusAddress.unix(dir: dir));
    shellBus = DBusClient(address);
    appBus = DBusClient(address);
    displays = FakeDisplays();
    object = DisplaysBusObject(displays, mayChange: (_) async => allowed);
    await publishDisplays(shellBus, object);
    client = DisplaysClient(appBus);
    await client.load();
  });

  tearDown(() async {
    await client.dispose();
    object.detach();
    await appBus.close();
    await shellBus.close();
    await server.close();
    await dir.delete(recursive: true);
  });

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('o app vê os monitores, com os modos', () async {
    final [laptop, monitor] = client.displays.value;
    expect(laptop.name, 'eDP-1');
    expect(laptop.primary, isTrue);
    expect(laptop.mode, FakeDisplays.laptopModes.first);
    expect(monitor.x, 1920);
    expect(monitor.modes, FakeDisplays.modes);
    expect(monitor.modes.first.preferred, isTrue);
  });

  test('um monitor desligado, sem modo, vai e volta', () async {
    displays.list.value = const [PsitoDisplay(name: 'a', enabled: false)];
    await until(() => client.displays.value.length == 1);
    expect(client.displays.value.single.mode, isNull);
    expect(client.displays.value.single.enabled, isFalse);
  });

  test('aplicar leva a configuração e traz a resposta', () async {
    final [laptop, monitor] = client.displays.value;
    final changed = monitor.copyWith(
      scale: 1.5,
      transform: 1,
      mode: FakeDisplays.modes[1],
    );
    expect(await client.apply([laptop, changed]), PsitoDisplaysResult.ok);
    final sent = displays.applied.single.last;
    expect(sent.scale, 1.5);
    expect(sent.transform, 1);
    expect(sent.mode!.refresh, 144000);

    await until(() => client.displays.value.last.scale == 1.5);
    expect(client.displays.value.last.scale, 1.5);

    displays.result = PsitoDisplaysResult.busy;
    expect(await client.apply([laptop]), PsitoDisplaysResult.busy);
  });

  test('trocar o principal', () async {
    await client.setPrimary('HDMI-A-1');
    expect(displays.list.value.last.primary, isTrue);
  });

  test('sem a segunda trava, nada muda', () async {
    allowed = false;
    expect(
      await client.apply(client.displays.value),
      PsitoDisplaysResult.failed,
    );
    expect(displays.applied, isEmpty);
    await client.setPrimary('HDMI-A-1');
    expect(displays.list.value.first.primary, isTrue);
  });
}
