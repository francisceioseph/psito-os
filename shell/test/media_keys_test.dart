// As teclas de mídia num barramento privado, com players de mentira.
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_shell/media_keys.dart';

class _Player extends DBusObject {
  String status;
  final calls = <String>[];

  _Player(this.status) : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    calls.add(methodCall.name);
    return DBusMethodSuccessResponse();
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async =>
      DBusGetPropertyResponse(DBusString(status));
}

void main() {
  late Directory dir;
  late DBusServer server;
  late DBusAddress address;
  late DBusClient shell;
  final clients = <DBusClient>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('psito_media_');
    server = DBusServer();
    address = await server.listenAddress(DBusAddress.unix(dir: dir));
    shell = DBusClient(address);
  });

  tearDown(() async {
    for (final client in clients) {
      await client.close();
    }
    clients.clear();
    await shell.close();
    await server.close();
    await dir.delete(recursive: true);
  });

  Future<_Player> publish(String name, String status) async {
    final client = DBusClient(address);
    clients.add(client);
    final player = _Player(status);
    await client.registerObject(player);
    await client.requestName('org.mpris.MediaPlayer2.$name');
    return player;
  }

  test('sem player, não faz nada', () async {
    await MediaKeys(shell).send(MediaCommand.playPause);
  });

  test('vai para o que está tocando, com o comando certo', () async {
    final paused = await publish('a', 'Paused');
    final playing = await publish('b', 'Playing');
    final keys = MediaKeys(shell);
    await keys.send(MediaCommand.playPause);
    await keys.send(MediaCommand.next);
    await keys.send(MediaCommand.previous);
    expect(playing.calls, ['PlayPause', 'Next', 'Previous']);
    expect(paused.calls, isEmpty);
  });

  test('com nada tocando, continua no último, e não em outro', () async {
    final first = await publish('a', 'Stopped');
    final second = await publish('b', 'Paused');
    final keys = MediaKeys(shell);
    await keys.send(MediaCommand.playPause);
    expect(second.calls, [
      'PlayPause',
    ], reason: 'um pausado antes de um parado');

    second.status = 'Stopped';
    first.status = 'Paused';
    await keys.send(MediaCommand.playPause);
    expect(second.calls, hasLength(2));
    expect(first.calls, isEmpty);
  });

  test('ignora os outros nomes do barramento', () async {
    final client = DBusClient(address);
    clients.add(client);
    await client.requestName('org.example.Other');
    await MediaKeys(shell).send(MediaCommand.next);
  });
}
