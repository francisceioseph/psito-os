// packages/psito_services/lib/storage_client.dart
//
// O uso dos discos para as Configurações (org.psito.Storage na sessão). No
// sandbox, só passa quem tem `settings`. O servidor é o
// shell/lib/storage_bus.dart.
import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';

const storageBusName = 'org.psito.Storage';
const storageInterface = 'org.psito.Storage';
final storagePath = DBusObjectPath('/org/psito/Storage');

/// Como o uso de um disco vai pelo barramento.
DBusValue diskUsageToDBus(PsitoDiskUsage d) => DBusDict.stringVariant({
  'id': DBusString(d.id),
  'name': DBusString(d.name),
  'path': DBusString(d.path ?? ''),
  'total': DBusInt64(d.total),
  'free': DBusInt64(d.free ?? -1),
});

PsitoDiskUsage diskUsageFromDBus(DBusValue value) {
  final map = value.asStringVariantDict();
  final path = map['path']?.asString() ?? '';
  final free = map['free']?.asInt64() ?? -1;
  return PsitoDiskUsage(
    id: map['id']?.asString() ?? '',
    name: map['name']?.asString() ?? '',
    path: path.isEmpty ? null : path,
    total: map['total']?.asInt64() ?? 0,
    free: free < 0 ? null : free,
  );
}

class StorageClient implements PsitoStorage {
  late final DBusRemoteObject _object = DBusRemoteObject(
    _bus,
    name: storageBusName,
    path: storagePath,
  );
  final DBusClient _bus;
  final _disks = ValueNotifier<List<PsitoDiskUsage>>(const []);
  StreamSubscription<DBusSignal>? _changed;

  StorageClient(this._bus) {
    _changed = DBusSignalStream(
      _bus,
      interface: storageInterface,
      name: 'Changed',
      path: storagePath,
    ).listen((_) => unawaited(_load()));
    unawaited(refresh());
  }

  Future<void> dispose() async {
    await _changed?.cancel();
    _disks.dispose();
  }

  @override
  ValueListenable<List<PsitoDiskUsage>> get disks => _disks;

  Future<void> _load() async {
    try {
      final reply = await _object.callMethod(
        storageInterface,
        'List',
        const [],
        replySignature: DBusSignature('aa{sv}'),
      );
      _disks.value = reply.returnValues[0]
          .asArray()
          .map(diskUsageFromDBus)
          .toList();
    } catch (e) {
      debugPrint('🦜 Sem o uso dos discos: $e');
    }
  }

  @override
  Future<void> refresh() async {
    try {
      await _object.callMethod(
        storageInterface,
        'Refresh',
        const [],
        replySignature: DBusSignature(''),
      );
    } catch (e) {
      debugPrint('🦜 Sem medir os discos: $e');
    }
    await _load();
  }

  @override
  Future<List<PsitoFolderSize>> largestFolders(String path) async {
    try {
      final reply = await _object.callMethod(
        storageInterface,
        'LargestFolders',
        [DBusString(path)],
        replySignature: DBusSignature('a(sx)'),
      );
      return [
        for (final item in reply.returnValues[0].asArray())
          PsitoFolderSize(
            item.asStruct()[0].asString(),
            item.asStruct()[1].asInt64(),
          ),
      ];
    } catch (e) {
      debugPrint('🦜 Sem as maiores pastas: $e');
      return const [];
    }
  }

  @override
  Future<int> trashSize() async {
    try {
      final reply = await _object.callMethod(
        storageInterface,
        'TrashSize',
        const [],
        replySignature: DBusSignature('x'),
      );
      return reply.returnValues[0].asInt64();
    } catch (e) {
      debugPrint('🦜 Sem o tamanho da lixeira: $e');
      return 0;
    }
  }

  Future<void> _send(String method, List<DBusValue> args) async {
    try {
      await _object.callMethod(
        storageInterface,
        method,
        args,
        replySignature: DBusSignature(''),
      );
    } catch (e) {
      debugPrint('🦜 Erro em $method: $e');
    }
  }

  @override
  Future<void> emptyTrash() => _send('EmptyTrash', const []);

  @override
  Future<void> openFolder(String path) =>
      _send('OpenFolder', [DBusString(path)]);

  @override
  Future<PsitoDiskResult> format(
    String id,
    PsitoDiskFormat type,
    String label,
  ) async {
    try {
      final reply = await _object.callMethod(storageInterface, 'Format', [
        DBusString(id),
        DBusString(type.name),
        DBusString(label),
      ], replySignature: DBusSignature('s'));
      final name = reply.returnValues[0].asString();
      return PsitoDiskResult.values.asNameMap()[name] ?? PsitoDiskResult.failed;
    } catch (e) {
      debugPrint('🦜 Erro formatando: $e');
      return PsitoDiskResult.failed;
    }
  }
}
