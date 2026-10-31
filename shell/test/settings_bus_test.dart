import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/settings_client.dart';
import 'package:psito_shell/settings_bus.dart';
import 'package:system_shell/shell/settings_store.dart';

void main() {
  late Directory dir;
  late DBusServer server;
  late DBusClient shellBus;
  late DBusClient appBus;
  late SettingsStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('psito_settings_bus_');
    server = DBusServer();
    final address = await server.listenAddress(DBusAddress.unix(dir: dir));
    shellBus = DBusClient(address);
    appBus = DBusClient(address);
    store = SettingsStore.memory(
      PsitoSettings.defaults.copyWith(use24h: false),
    );
    await publishSettings(shellBus, SettingsBusObject(store));
  });

  tearDown(() async {
    await appBus.close();
    await shellBus.close();
    await server.close();
    await dir.delete(recursive: true);
  });

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 50 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('o app lê, grava e acompanha as configurações do shell', () async {
    final client = SettingsClient(appBus);
    await client.ready;
    expect(client.value.use24h, isFalse);

    // O app grava: o shell guarda e o Changed volta para o app
    final blue = client.value.copyWith(accent: const Color(0xFF2196F3));
    expect(await client.update(blue), isTrue);
    expect(store.value, blue);
    await until(() => client.value == blue);
    expect(client.value, blue);

    // O shell muda por outro caminho (o arquivo): o app vê
    await store.update(blue.copyWith(showSeconds: true));
    await until(() => client.value.showSeconds);
    expect(client.value.showSeconds, isTrue);
    client.dispose();
  });

  test('JSON inválido é recusado', () async {
    final reply = DBusRemoteObject(
      appBus,
      name: settingsBusName,
      path: settingsPath,
    ).callMethod(settingsInterface, 'Update', [const DBusString('[1]')]);
    await expectLater(reply, throwsA(isA<DBusInvalidArgsException>()));
  });

  test('sem o shell, o app fica com os padrões', () async {
    await shellBus.close();
    final client = SettingsClient(appBus);
    await client.ready;
    expect(client.value, PsitoSettings.defaults);
    client.dispose();
  });
}
