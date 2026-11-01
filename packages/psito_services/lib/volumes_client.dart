// packages/psito_services/lib/volumes_client.dart
//
// Os discos externos para os apps (org.psito.Volumes na sessão). Só o shell fala
// com o UDisks2, e no sandbox só passa quem tem `files:removable`: sem ela, o
// proxy recusa, e a lista fica vazia. O servidor é o shell/lib/volumes_bus.dart.
import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';

const volumesBusName = 'org.psito.Volumes';
const volumesInterface = 'org.psito.Volumes';
final volumesPath = DBusObjectPath('/org/psito/Volumes');

/// Como um volume vai pelo barramento.
DBusValue volumeToDBus(PsitoVolume v) => DBusDict.stringVariant({
  'id': DBusString(v.id),
  'label': DBusString(v.label),
  'device': DBusString(v.device),
  'mountPoint': DBusString(v.mountPoint ?? ''),
  'size': DBusInt64(v.size),
  'fileSystem': DBusString(v.fileSystem),
  'readOnly': DBusBoolean(v.readOnly),
  'locked': DBusBoolean(v.locked),
  'unlocked': DBusBoolean(v.unlocked),
  'drive': DBusString(v.drive ?? ''),
  'canEject': DBusBoolean(v.canEject),
  'autoMount': DBusBoolean(v.autoMount),
});

PsitoVolume volumeFromDBus(DBusValue value) {
  final map = value.asStringVariantDict();
  String text(String key) => map[key]?.asString() ?? '';
  bool flag(String key) => map[key]?.asBoolean() ?? false;
  String? optional(String key) => text(key).isEmpty ? null : text(key);
  return PsitoVolume(
    id: text('id'),
    label: text('label'),
    device: text('device'),
    mountPoint: optional('mountPoint'),
    size: map['size']?.asInt64() ?? 0,
    fileSystem: text('fileSystem'),
    readOnly: flag('readOnly'),
    locked: flag('locked'),
    unlocked: flag('unlocked'),
    drive: optional('drive'),
    canEject: flag('canEject'),
    autoMount: flag('autoMount'),
  );
}

class VolumesClient implements PsitoVolumes {
  final DBusClient _bus;
  late final DBusRemoteObject _object = DBusRemoteObject(
    _bus,
    name: volumesBusName,
    path: volumesPath,
  );
  final _volumes = ValueNotifier<List<PsitoVolume>>(const []);
  StreamSubscription<DBusSignal>? _changed;

  /// Completa depois da primeira leitura, com ou sem sucesso.
  late final Future<void> ready;

  VolumesClient(this._bus) {
    _changed = DBusSignalStream(
      _bus,
      interface: volumesInterface,
      name: 'Changed',
      path: volumesPath,
    ).listen((_) => unawaited(_load()));
    ready = _load();
  }

  @override
  ValueListenable<List<PsitoVolume>> get volumes => _volumes;

  Future<void> _load() async {
    try {
      final reply = await _object.callMethod(
        volumesInterface,
        'List',
        const [],
        replySignature: DBusSignature('aa{sv}'),
      );
      _volumes.value = reply.returnValues[0]
          .asArray()
          .map(volumeFromDBus)
          .toList();
    } catch (e) {
      // Sem a permissão, ou sem o shell
      debugPrint('🦜 Sem os discos externos: $e');
    }
  }

  Future<PsitoDiskResult> _call(String method, List<DBusValue> args) async {
    try {
      final reply = await _object.callMethod(
        volumesInterface,
        method,
        args,
        replySignature: DBusSignature('s'),
      );
      final name = reply.returnValues[0].asString();
      return PsitoDiskResult.values.asNameMap()[name] ?? PsitoDiskResult.failed;
    } catch (e) {
      debugPrint('🦜 Erro em $method: $e');
      return PsitoDiskResult.failed;
    }
  }

  @override
  Future<String?> mount(String id) async {
    try {
      final reply = await _object.callMethod(volumesInterface, 'Mount', [
        DBusString(id),
      ], replySignature: DBusSignature('s'));
      final where = reply.returnValues[0].asString();
      return where.isEmpty ? null : where;
    } catch (e) {
      debugPrint('🦜 Erro montando: $e');
      return null;
    }
  }

  @override
  Future<PsitoDiskResult> unmount(String id) =>
      _call('Unmount', [DBusString(id)]);

  @override
  Future<PsitoDiskResult> eject(String id) => _call('Eject', [DBusString(id)]);

  @override
  Future<PsitoDiskResult> unlock(String id, String password) =>
      _call('Unlock', [DBusString(id), DBusString(password)]);

  Future<void> dispose() async {
    await _changed?.cancel();
    _volumes.dispose();
  }
}
