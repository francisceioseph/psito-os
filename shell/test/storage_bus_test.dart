// O org.psito.Storage num barramento privado, pelo cliente de verdade.
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/storage_client.dart';
import 'package:psito_services/storage_service.dart';
import 'package:psito_shell/storage_bus.dart';

void main() {
  late Directory dir;
  late DBusServer server;
  late DBusClient shellBus;
  late DBusClient appBus;
  late FakeStorage storage;
  late StorageBusObject object;
  late StorageClient client;
  var allowed = true;

  setUp(() async {
    allowed = true;
    dir = await Directory.systemTemp.createTemp('psito_storage_');
    server = DBusServer();
    final address = await server.listenAddress(DBusAddress.unix(dir: dir));
    shellBus = DBusClient(address);
    appBus = DBusClient(address);
    storage = FakeStorage();
    object = StorageBusObject(storage, mayChange: (_) async => allowed);
    await publishStorage(shellBus, object);
    client = StorageClient(appBus);
    await client.refresh();
  });

  tearDown(() async {
    await client.dispose();
    object.detach();
    await appBus.close();
    await shellBus.close();
    await server.close();
    await dir.delete(recursive: true);
  });

  test('o app vê o uso, com um disco sem montar', () async {
    storage.usage.value = const [
      PsitoDiskUsage(path: '/h', total: 10, free: 4),
      PsitoDiskUsage(id: '/a', name: 'A', total: 5),
    ];
    await client.refresh();
    expect(client.disks.value, storage.usage.value);
    expect(client.disks.value.last.free, isNull);
    expect(client.disks.value.last.path, isNull);
  });

  test('o sinal leva a lista nova', () async {
    storage.usage.value = const [PsitoDiskUsage(path: '/h', total: 1, free: 1)];
    for (var i = 0; i < 100 && client.disks.value.length != 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(client.disks.value, hasLength(1));
  });

  test('as pastas e a lixeira', () async {
    final folders = await client.largestFolders('/home/ana');
    expect(folders.first.path, '/home/ana/Videos');
    expect(folders.first.size, 40000000000);
    expect(await client.trashSize(), storage.trash);
  });

  test('esvaziar só pede, e abrir vai ao shell', () async {
    await client.emptyTrash();
    await client.openFolder('/home/ana/x');
    await client.openFormat('/a');
    expect(storage.asksToEmpty, 1);
    expect(storage.opened, ['/home/ana/x', 'format:/a']);
  });

  test('formatar leva o tipo e o nome, e devolve o resultado', () async {
    storage.answer = PsitoDiskResult.busy;
    expect(
      await client.format('/a', PsitoDiskFormat.ext4, 'NOVO'),
      PsitoDiskResult.busy,
    );
    expect(storage.formatted.single, ('/a', PsitoDiskFormat.ext4, 'NOVO'));
  });

  test('sem permissão, nada muda nem é lido', () async {
    allowed = false;
    expect(
      await client.format('/a', PsitoDiskFormat.vfat, 'X'),
      PsitoDiskResult.failed,
    );
    await client.emptyTrash();
    await client.openFolder('/x');
    await client.openFormat('/a');
    expect(await client.largestFolders('/home/ana'), isEmpty);
    expect(storage.formatted, isEmpty);
    expect(storage.asksToEmpty, 0);
    expect(storage.opened, isEmpty);
  });
}
