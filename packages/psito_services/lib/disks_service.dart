// packages/psito_services/lib/disks_service.dart
//
// Os discos externos pelo UDisks2, que monta e desmonta em /media/<conta>.
// Só o shell fala com ele: os apps no sandbox nem veem o barramento.
import 'dart:async';
import 'dart:convert';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'dbus_names.dart';

const _busName = 'org.freedesktop.UDisks2';
const _blockInterface = '$_busName.Block';
const _filesystemInterface = '$_busName.Filesystem';
const _encryptedInterface = '$_busName.Encrypted';
const _driveInterface = '$_busName.Drive';

typedef UDisksObjects =
    Map<DBusObjectPath, Map<String, Map<String, DBusValue>>>;

/// O texto de uma propriedade `ay`, que vem com um zero no fim.
String _bytes(DBusValue? value) {
  if (value == null) return '';
  final bytes = value.asByteArray().takeWhile((b) => b != 0).toList();
  return utf8.decode(bytes, allowMalformed: true);
}

DBusObjectPath? _path(DBusValue? value) {
  final path = value?.asObjectPath();
  return path == null || path.value == '/' ? null : path;
}

/// Os volumes que aparecem para quem usa: partições e discos com sistema de
/// arquivos, e os criptografados ainda trancados. Um destrancado vira o volume
/// de dentro dele. Fica de fora o que o UDisks2 diz que é do sistema, como o
/// disco em que o Debian está.
List<PsitoVolume> volumesFrom(UDisksObjects objects) {
  final found = <PsitoVolume>[];
  for (final MapEntry(key: path, value: interfaces) in objects.entries) {
    final block = interfaces[_blockInterface];
    if (block == null) continue;
    final encrypted = interfaces[_encryptedInterface];
    final filesystem = interfaces[_filesystemInterface];
    final usage = block['IdUsage']?.asString() ?? '';
    final locked = encrypted != null && usage == 'crypto';
    if (locked && _path(encrypted['CleartextDevice']) != null) continue;
    if (!locked && (filesystem == null || usage != 'filesystem')) continue;
    // As dicas e o disco de um destrancado são os do trancado
    final backing = objects[_path(block['CryptoBackingDevice'])];
    final outer = backing?[_blockInterface] ?? block;
    if (outer['HintSystem']?.asBoolean() ?? true) continue;
    if (outer['HintIgnore']?.asBoolean() ?? false) continue;
    final drivePath = _path(outer['Drive']);
    final drive = objects[drivePath]?[_driveInterface];
    final mounts = filesystem?['MountPoints']?.asArray() ?? const <DBusValue>[];
    found.add(
      PsitoVolume(
        id: path.value,
        label: (block['IdLabel'] ?? outer['IdLabel'])?.asString() ?? '',
        device: _bytes(block['Device']),
        mountPoint: mounts.isEmpty ? null : _bytes(mounts.first),
        size: (block['Size'] ?? outer['Size'])?.asUint64() ?? 0,
        fileSystem: block['IdType']?.asString() ?? '',
        readOnly: block['ReadOnly']?.asBoolean() ?? false,
        locked: locked,
        unlocked: backing != null,
        drive: drivePath?.value,
        canEject:
            (drive?['Ejectable']?.asBoolean() ?? false) ||
            (drive?['CanPowerOff']?.asBoolean() ?? false),
      ),
    );
  }
  return found..sort((a, b) {
    final byName = a.label.toLowerCase().compareTo(b.label.toLowerCase());
    return byName != 0 ? byName : a.device.compareTo(b.device);
  });
}

abstract class DisksService implements PsitoVolumes {
  Future<void> dispose();
}

class UDisks2Service implements DisksService {
  static final managerPath = DBusObjectPath('/org/freedesktop/UDisks2');

  final DBusClient _bus;
  final _volumes = ValueNotifier<List<PsitoVolume>>(const []);
  final List<StreamSubscription<Object?>> _subscriptions = [];
  late final DBusRemoteObjectManager _manager = DBusRemoteObjectManager(
    _bus,
    name: _busName,
    path: managerPath,
  );
  UDisksObjects _objects = const {};
  bool _reloadScheduled = false;

  /// Completa depois da primeira leitura, com ou sem sucesso.
  late final Future<void> ready;

  UDisks2Service(this._bus) {
    ready = _load();
  }

  @override
  ValueListenable<List<PsitoVolume>> get volumes => _volumes;

  Future<void> _load() async {
    try {
      if (!await busNameAvailable(_bus, _busName)) {
        debugPrint('🦜 $_busName não está no barramento');
        return;
      }
      _subscriptions.add(_manager.signals.listen((_) => _scheduleReload()));
      await _reload();
    } catch (e) {
      debugPrint('🦜 Erro lendo $_busName: $e');
    }
  }

  // Um disco que entra manda um sinal por partição: lê uma vez só
  void _scheduleReload() {
    if (_reloadScheduled) return;
    _reloadScheduled = true;
    scheduleMicrotask(() {
      _reloadScheduled = false;
      unawaited(_reload());
    });
  }

  Future<void> _reload() async {
    try {
      _objects = await _manager.getManagedObjects();
    } catch (e) {
      debugPrint('🦜 Erro lendo os discos: $e');
      return;
    }
    final found = volumesFrom(_objects);
    if (listEquals(found, _volumes.value)) return;
    debugPrint(
      '🦜 discos: ${found.map((v) => '${v.device}=${v.mountPoint}').join(' ')}',
    );
    _volumes.value = found;
  }

  DBusRemoteObject _object(DBusObjectPath path) =>
      DBusRemoteObject(_bus, name: _busName, path: path);

  static final _noOptions = DBusDict.stringVariant(const {});

  static PsitoDiskResult _resultOf(DBusMethodResponseException e) {
    final name = e.errorName;
    final message = e.response.values.firstOrNull?.toNative().toString() ?? '';
    if (name.endsWith('.DeviceBusy')) return PsitoDiskResult.busy;
    if (name.endsWith('.NotMounted')) return PsitoDiskResult.ok;
    // O motivo só vem no texto, que é do cryptsetup
    if (message.toLowerCase().contains('passphrase')) {
      return PsitoDiskResult.wrongPassword;
    }
    debugPrint('🦜 Erro no disco: $name $message');
    return PsitoDiskResult.failed;
  }

  @override
  Future<String?> mount(String id) async {
    try {
      final reply = await _object(DBusObjectPath(id)).callMethod(
        _filesystemInterface,
        'Mount',
        [_noOptions],
        replySignature: DBusSignature('s'),
      );
      return reply.returnValues[0].asString();
    } on DBusMethodResponseException catch (e) {
      // Já estava montado, por exemplo pela montagem automática
      if (e.errorName.endsWith('.AlreadyMounted')) {
        return _volumes.value.where((v) => v.id == id).firstOrNull?.mountPoint;
      }
      debugPrint('🦜 Erro montando $id: $e');
      return null;
    }
  }

  @override
  Future<PsitoDiskResult> unmount(String id) async {
    try {
      await _object(DBusObjectPath(id)).callMethod(
        _filesystemInterface,
        'Unmount',
        [_noOptions],
        replySignature: DBusSignature(''),
      );
      return PsitoDiskResult.ok;
    } on DBusMethodResponseException catch (e) {
      return _resultOf(e);
    }
  }

  @override
  Future<PsitoDiskResult> eject(String id) async {
    await _reload();
    final volume = _volumes.value.where((v) => v.id == id).firstOrNull;
    final drive = volume?.drive;
    if (volume == null) return PsitoDiskResult.failed;
    final siblings = drive == null
        ? [volume]
        : _volumes.value.where((v) => v.drive == drive).toList();
    for (final sibling in siblings) {
      if (sibling.mountPoint != null) {
        final result = await unmount(sibling.id);
        if (result != PsitoDiskResult.ok) return result;
      }
      if (sibling.unlocked) {
        final result = await _lock(sibling.id);
        if (result != PsitoDiskResult.ok) return result;
      }
    }
    if (drive == null) return PsitoDiskResult.ok;
    final properties =
        _objects[DBusObjectPath(drive)]?[_driveInterface] ?? const {};
    // O pendrive desliga, e assim a luz apaga. O Eject é o que serve num leitor
    // de cartão ou de CD, em que a mídia sai e o aparelho fica
    final method = properties['CanPowerOff']?.asBoolean() ?? false
        ? 'PowerOff'
        : properties['Ejectable']?.asBoolean() ?? false
        ? 'Eject'
        : null;
    if (method == null) return PsitoDiskResult.ok;
    try {
      await _object(DBusObjectPath(drive)).callMethod(_driveInterface, method, [
        _noOptions,
      ], replySignature: DBusSignature(''));
      return PsitoDiskResult.ok;
    } on DBusMethodResponseException catch (e) {
      return _resultOf(e);
    }
  }

  /// [cleartext] é o volume de dentro: quem tranca é o de fora.
  Future<PsitoDiskResult> _lock(String cleartext) async {
    final backing = _path(
      _objects[DBusObjectPath(
        cleartext,
      )]?[_blockInterface]?['CryptoBackingDevice'],
    );
    if (backing == null) return PsitoDiskResult.failed;
    try {
      await _object(backing).callMethod(_encryptedInterface, 'Lock', [
        _noOptions,
      ], replySignature: DBusSignature(''));
      return PsitoDiskResult.ok;
    } on DBusMethodResponseException catch (e) {
      return _resultOf(e);
    }
  }

  @override
  Future<PsitoDiskResult> unlock(String id, String password) async {
    try {
      final reply = await _object(DBusObjectPath(id)).callMethod(
        _encryptedInterface,
        'Unlock',
        [DBusString(password), _noOptions],
        replySignature: DBusSignature('o'),
      );
      final inside = reply.returnValues[0].asObjectPath();
      return await mount(inside.value) == null
          ? PsitoDiskResult.failed
          : PsitoDiskResult.ok;
    } on DBusMethodResponseException catch (e) {
      return _resultOf(e);
    }
  }

  @override
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _volumes.dispose();
  }
}

class FakeDisksService implements DisksService {
  /// A senha que os falsos aceitam.
  static const password = 'calopsita';

  /// O nome que o disco tem: não é um texto da interface.
  static const _sampleName = 'PENDRIVE';

  static const sample = PsitoVolume(
    id: 'pendrive',
    label: _sampleName,
    device: '/dev/sdb1',
    mountPoint: '/media/ana/PENDRIVE',
    size: 16000000000,
    fileSystem: 'vfat',
    drive: 'sdb',
    canEject: true,
  );

  @override
  final ValueNotifier<List<PsitoVolume>> volumes;

  /// O que os próximos pedidos respondem.
  PsitoDiskResult answer = PsitoDiskResult.ok;

  FakeDisksService([List<PsitoVolume> initial = const []])
    : volumes = ValueNotifier(initial);

  void _replace(String id, PsitoVolume Function(PsitoVolume) change) {
    volumes.value = [for (final v in volumes.value) v.id == id ? change(v) : v];
  }

  @override
  Future<String?> mount(String id) async {
    if (answer != PsitoDiskResult.ok) return null;
    final where = '/media/ana/$id';
    _replace(id, (v) => v.copyWith(mountPoint: () => where));
    return where;
  }

  @override
  Future<PsitoDiskResult> unmount(String id) async {
    if (answer == PsitoDiskResult.ok) {
      _replace(id, (v) => v.copyWith(mountPoint: () => null));
    }
    return answer;
  }

  @override
  Future<PsitoDiskResult> eject(String id) async {
    if (answer != PsitoDiskResult.ok) return answer;
    final drive = volumes.value.where((v) => v.id == id).firstOrNull?.drive;
    volumes.value = [
      for (final v in volumes.value)
        if (v.id != id && (drive == null || v.drive != drive)) v,
    ];
    return answer;
  }

  @override
  Future<PsitoDiskResult> unlock(String id, String password) async {
    if (password != FakeDisksService.password) {
      return PsitoDiskResult.wrongPassword;
    }
    _replace(
      id,
      (v) => v.copyWith(
        locked: false,
        unlocked: true,
        mountPoint: () => '/media/ana/$id',
      ),
    );
    return PsitoDiskResult.ok;
  }

  @override
  Future<void> dispose() async => volumes.dispose();
}
