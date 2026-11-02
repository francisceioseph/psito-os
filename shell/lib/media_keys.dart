// shell/lib/media_keys.dart
//
// As teclas de mídia: o shell é cliente do MPRIS, e manda ao player da vez o que
// foi apertado. Os players publicam org.mpris.MediaPlayer2.<nome> na sessão.
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

const _prefix = 'org.mpris.MediaPlayer2.';
const _player = 'org.mpris.MediaPlayer2.Player';
final _path = DBusObjectPath('/org/mpris/MediaPlayer2');

enum MediaCommand { playPause, next, previous }

class MediaKeys {
  final DBusClient _bus;

  /// O último que recebeu um comando: com nada tocando, é ele que continua.
  String? _last;

  MediaKeys(this._bus);

  Future<String?> _status(String name) async {
    try {
      final value = await DBusRemoteObject(
        _bus,
        name: name,
        path: _path,
      ).getProperty(_player, 'PlaybackStatus');
      return value.asString();
    } on DBusMethodResponseException {
      return null;
    }
  }

  /// O que está tocando, o último a receber um comando, um pausado, ou o primeiro.
  Future<String?> _target() async {
    final names = (await _bus.listNames())
        .where((name) => name.startsWith(_prefix))
        .toList();
    if (names.isEmpty) return null;
    final statuses = {for (final name in names) name: await _status(name)};
    for (final name in names) {
      if (statuses[name] == 'Playing') return name;
    }
    if (names.contains(_last)) return _last;
    for (final name in names) {
      if (statuses[name] == 'Paused') return name;
    }
    return names.first;
  }

  Future<void> send(MediaCommand command) async {
    try {
      final name = await _target();
      if (name == null) return;
      _last = name;
      await DBusRemoteObject(_bus, name: name, path: _path).callMethod(
        _player,
        switch (command) {
          MediaCommand.playPause => 'PlayPause',
          MediaCommand.next => 'Next',
          MediaCommand.previous => 'Previous',
        },
        const [],
        replySignature: DBusSignature(''),
      );
    } catch (e) {
      debugPrint('🦜 tecla de mídia: $e');
    }
  }
}
