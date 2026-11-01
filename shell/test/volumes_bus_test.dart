// O org.psito.Volumes num barramento privado, pelo cliente de verdade.
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/disks_service.dart';
import 'package:psito_services/volumes_client.dart';
import 'package:psito_shell/volumes_bus.dart';

void main() {
  late Directory dir;
  late DBusAddress address;
  late DBusServer server;
  late DBusClient shellBus;
  late DBusClient appBus;
  late FakeDisksService disks;
  late VolumesBusObject object;
  late VolumesClient client;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('psito_volumes_');
    server = DBusServer();
    address = await server.listenAddress(DBusAddress.unix(dir: dir));
    shellBus = DBusClient(address);
    appBus = DBusClient(address);
    disks = FakeDisksService([FakeDisksService.sample]);
    object = VolumesBusObject(disks);
    await publishVolumes(shellBus, object);
    client = VolumesClient(appBus);
    await client.ready;
  });

  tearDown(() async {
    await client.dispose();
    object.detach();
    await disks.dispose();
    await appBus.close();
    await shellBus.close();
    await server.close();
    await dir.delete(recursive: true);
  });

  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('o app vê o volume igual ao que o shell tem', () {
    expect(client.volumes.value, [FakeDisksService.sample]);
  });

  test('um disco novo chega pelo sinal', () async {
    const novo = PsitoVolume(id: 'novo', label: 'NOVO', device: '/dev/sdc1');
    disks.volumes.value = [...disks.volumes.value, novo];
    await until(() => client.volumes.value.length == 2);
    expect(client.volumes.value.last, novo);
  });

  test('um volume sem montar continua nulo do outro lado', () async {
    expect(await client.unmount('pendrive'), PsitoDiskResult.ok);
    await until(() => client.volumes.value.single.mountPoint == null);
    expect(client.volumes.value.single.mountPoint, isNull);
    expect(await client.mount('pendrive'), '/media/ana/pendrive');
  });

  test('sem conseguir montar, o app recebe null', () async {
    disks.answer = PsitoDiskResult.failed;
    expect(await client.mount('pendrive'), isNull);
  });

  test('ocupado chega ao app', () async {
    disks.answer = PsitoDiskResult.busy;
    expect(await client.eject('pendrive'), PsitoDiskResult.busy);
  });

  test('destrancar não leva senha, e devolve onde montou', () async {
    disks.askUnlock = (id) async => '/media/ana/$id';
    expect(await client.unlock('cofre'), '/media/ana/cofre');
  });

  test('desistir de destrancar chega como null', () async {
    disks.askUnlock = (_) async => null;
    expect(await client.unlock('cofre'), isNull);
  });

  test('sem o shell, a lista fica vazia e nada trava', () async {
    final alone = DBusClient(address);
    addTearDown(alone.close);
    await shellBus.releaseName(volumesBusName);
    final orphan = VolumesClient(alone);
    addTearDown(orphan.dispose);
    await orphan.ready;
    expect(orphan.volumes.value, isEmpty);
    expect(await orphan.eject('x'), PsitoDiskResult.failed);
  });
}
