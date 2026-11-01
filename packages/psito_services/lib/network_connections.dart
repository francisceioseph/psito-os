// packages/psito_services/lib/network_connections.dart
//
// As conexões guardadas no NetworkManager, para as Configurações. Fica à parte
// do network_service porque só quem pode mudar o sistema precisa.
import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';

const _busName = 'org.freedesktop.NetworkManager';
const _settingsInterface = '$_busName.Settings';
const _connectionInterface = '$_busName.Settings.Connection';
const _activeInterface = '$_busName.Connection.Active';
const _deviceInterface = '$_busName.Device';

typedef NmSettings = Map<String, Map<String, DBusValue>>;

/// O que as Configurações mostram de uma conexão, ou null se não mostram: o
/// NetworkManager guarda até o lo.
PsitoSavedConnection? savedConnectionFrom(NmSettings settings) {
  final connection = settings['connection'];
  final uuid = connection?['uuid']?.asString();
  if (connection == null || uuid == null) return null;
  final kind = switch (connection['type']?.asString()) {
    '802-3-ethernet' => PsitoNetworkKind.ethernet,
    '802-11-wireless' => PsitoNetworkKind.wifi,
    'vpn' || 'wireguard' => PsitoNetworkKind.vpn,
    _ => null,
  };
  if (kind == null) return null;
  final ipv4 = settings['ipv4'] ?? const {};
  final method = switch (ipv4['method']?.asString()) {
    'auto' || null => PsitoIpMethod.auto,
    'manual' => PsitoIpMethod.manual,
    _ => PsitoIpMethod.other,
  };
  return PsitoSavedConnection(
    uuid: uuid,
    name: connection['id']?.asString() ?? '',
    kind: kind,
    autoconnect: connection['autoconnect']?.asBoolean() ?? true,
    priority: connection['autoconnect-priority']?.asInt32() ?? 0,
    metered: switch (connection['metered']?.asInt32()) {
      1 || 3 => PsitoMetered.yes,
      2 || 4 => PsitoMetered.no,
      _ => PsitoMetered.auto,
    },
    ipv4Method: method,
    address: _firstAddress(ipv4),
    gateway: ipv4['gateway']?.asString() ?? '',
    dns: _dnsServers(ipv4),
  );
}

String _firstAddress(Map<String, DBusValue> ipv4) {
  final data = ipv4['address-data'];
  if (data == null) return '';
  final first = data.asArray().firstOrNull?.asStringVariantDict();
  if (first == null) return '';
  return '${first['address']?.asString()}/${first['prefix']?.asUint32()}';
}

List<String> _dnsServers(Map<String, DBusValue> ipv4) {
  if (ipv4['dns-data'] case final data?) return data.asStringArray().toList();
  // O formato antigo: cada endereço é um inteiro, com o primeiro byte embaixo
  return [
    for (final n in ipv4['dns']?.asUint32Array() ?? const <int>[])
      [for (var shift = 0; shift < 32; shift += 8) (n >> shift) & 255]
          .join('.'),
  ];
}

int _dnsLegacy(String address) {
  final bytes = address.split('.').map(int.parse).toList();
  return bytes[0] | bytes[1] << 8 | bytes[2] << 16 | bytes[3] << 24;
}

/// [settings] com o que [c] muda. O resto da conexão (a senha não vem junto, e
/// o NetworkManager mantém a guardada) fica como está.
NmSettings applySavedConnection(NmSettings settings, PsitoSavedConnection c) {
  final ipv4 = {...?settings['ipv4']};
  // O endereço de uma VPN vem do arquivo dela, às vezes mais de um, e a tela não
  // mexe nele
  if (c.ipv4Method != PsitoIpMethod.other && c.kind != PsitoNetworkKind.vpn) {
    final oldAddresses = _firstAddress(ipv4) == c.address
        ? ipv4['address-data']
        : null;
    // Os dois formatos convivem na leitura, e o antigo pode contrariar o novo
    for (final key in [
      'addresses',
      'address-data',
      'gateway',
      'dns',
      'dns-data',
      'ignore-auto-dns',
    ]) {
      ipv4.remove(key);
    }
    ipv4['method'] = DBusString(
      c.ipv4Method == PsitoIpMethod.manual ? 'manual' : 'auto',
    );
    if (c.ipv4Method == PsitoIpMethod.manual) {
      // Sem mudar o primeiro, os outros (de um `nmcli`, digamos) continuam
      if (oldAddresses != null) {
        ipv4['address-data'] = oldAddresses;
      } else {
        final [address, prefix] = c.address.split('/');
        ipv4['address-data'] = DBusArray(DBusSignature('a{sv}'), [
          DBusDict.stringVariant({
            'address': DBusString(address),
            'prefix': DBusUint32(int.parse(prefix)),
          }),
        ]);
      }
      if (c.gateway.isNotEmpty) ipv4['gateway'] = DBusString(c.gateway);
    }
    if (c.dns.isNotEmpty) {
      ipv4['dns'] = DBusArray.uint32(c.dns.map(_dnsLegacy));
      ipv4['ignore-auto-dns'] = const DBusBoolean(true);
    }
  }
  return {
    ...settings,
    'connection': {
      ...?settings['connection'],
      'autoconnect': DBusBoolean(c.autoconnect),
      'autoconnect-priority': DBusInt32(c.priority),
      'metered': DBusInt32(switch (c.metered) {
        PsitoMetered.auto => 0,
        PsitoMetered.yes => 1,
        PsitoMetered.no => 2,
      }),
    },
    'ipv4': ipv4,
  };
}

/// O uuid na resposta do `nmcli connection import`.
String? importedUuid(String output) =>
    RegExp(r'[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}').stringMatch(output);

/// O tipo do `nmcli connection import` para um arquivo.
String vpnImportType(String path) =>
    path.toLowerCase().endsWith('.ovpn') ? 'openvpn' : 'wireguard';

/// Importa um arquivo de VPN pelo `nmcli` e devolve o uuid da conexão, ou null
/// se ele recusou. Num app no sandbox isso não funciona: lá dentro os arquivos do
/// root são de outro dono, e o `nmcli` não carrega o plugin do OpenVPN. Quem roda
/// é o shell, pelo `org.psito.Launcher`.
Future<String?> importVpnFile(
  String path, {
  Future<ProcessResult> Function(String, List<String>) run = Process.run,
}) async {
  final result = await run('nmcli', [
    'connection',
    'import',
    'type',
    vpnImportType(path),
    'file',
    path,
  ]);
  if (result.exitCode != 0) {
    debugPrint('🦜 nmcli: ${result.stderr}');
    return null;
  }
  return importedUuid('${result.stdout}');
}

class NetworkManagerConnections implements PsitoNetworkConnections {
  /// Passa um arquivo de VPN ao NetworkManager e devolve o uuid da conexão.
  final Future<String?> Function(String path) _import;
  final String? _user;

  static final _managerPath = DBusObjectPath('/org/freedesktop/NetworkManager');
  static final _settingsPath = DBusObjectPath(
    '/org/freedesktop/NetworkManager/Settings',
  );

  final DBusClient _bus;
  late final _settings = DBusRemoteObject(
    _bus,
    name: _busName,
    path: _settingsPath,
  );
  final _subscriptions = <StreamSubscription<DBusSignal>>[];
  final _connections = ValueNotifier<List<PsitoSavedConnection>>(const []);

  /// O caminho de cada conexão, pelo uuid.
  Map<String, DBusObjectPath> _paths = const {};

  /// Cada leitura invalida as anteriores: uma lenta não sobrescreve uma nova.
  int _generation = 0;

  /// Completa depois da primeira leitura, com ou sem sucesso.
  late final Future<void> ready;

  NetworkManagerConnections(
    this._bus, {
    Future<String?> Function(String path)? importer,
    String? user,
  }) : _import = importer ?? importVpnFile,
       _user = user ?? Platform.environment['USER'] {
    void reload(Object? _) => unawaited(_load());
    for (final name in ['NewConnection', 'ConnectionRemoved']) {
      _subscriptions.add(
        DBusRemoteObjectSignalStream(
          object: _settings,
          interface: _settingsInterface,
          name: name,
        ).listen(reload),
      );
    }
    _subscriptions.add(
      DBusSignalStream(
        _bus,
        sender: _busName,
        interface: _connectionInterface,
        name: 'Updated',
      ).listen(reload),
    );
    ready = _load();
  }

  @override
  ValueListenable<List<PsitoSavedConnection>> get connections => _connections;

  static DBusDict _dict(NmSettings settings) =>
      DBusDict(DBusSignature('s'), DBusSignature('a{sv}'), {
        for (final MapEntry(key: group, value: values) in settings.entries)
          DBusString(group): DBusDict.stringVariant(values),
      });

  DBusRemoteObject _object(DBusObjectPath path) =>
      DBusRemoteObject(_bus, name: _busName, path: path);

  Future<NmSettings> _read(DBusObjectPath path) async {
    final reply = await _object(path).callMethod(
      _connectionInterface,
      'GetSettings',
      const [],
      replySignature: DBusSignature('a{sa{sv}}'),
    );
    return {
      for (final group in reply.returnValues[0].asDict().entries)
        group.key.asString(): group.value.asStringVariantDict(),
    };
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final paths = <String, DBusObjectPath>{};
    final found = <PsitoSavedConnection>[];
    try {
      final reply = await _settings.callMethod(
        _settingsInterface,
        'ListConnections',
        const [],
        replySignature: DBusSignature('ao'),
      );
      for (final path in reply.returnValues[0].asObjectPathArray()) {
        final connection = savedConnectionFrom(await _read(path));
        if (connection == null) continue;
        paths[connection.uuid] = path;
        found.add(connection);
      }
    } catch (e) {
      debugPrint('🦜 Erro lendo as conexões: $e');
      return;
    }
    if (generation != _generation) return;
    found.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.uuid.compareTo(b.uuid);
    });
    _paths = paths;
    _connections.value = found;
  }

  @override
  Future<bool> update(PsitoSavedConnection connection) async {
    final path = _paths[connection.uuid];
    if (path == null) return false;
    try {
      final settings = applySavedConnection(await _read(path), connection);
      await _object(path).callMethod(_connectionInterface, 'Update', [
        _dict(settings),
      ], replySignature: DBusSignature(''));
    } catch (e) {
      debugPrint('🦜 Erro gravando a conexão: $e');
      return false;
    }
    await _applyIfActive(connection.uuid, path);
    return true;
  }

  /// As conexões ativas de [uuid].
  Future<List<DBusObjectPath>> _activeOf(String uuid) async {
    final active = await _object(_managerPath).getProperty(
      _busName,
      'ActiveConnections',
      signature: DBusSignature('ao'),
    );
    return [
      for (final path in active.asObjectPathArray())
        if ((await _object(path).getProperty(
              _activeInterface,
              'Uuid',
              signature: DBusSignature('s'),
            )).asString() ==
            uuid)
          path,
    ];
  }

  /// O NetworkManager só usa o que foi gravado na próxima ativação. O `Reapply`
  /// troca sem derrubar, e o que ele recusa vai com uma ativação nova.
  Future<void> _applyIfActive(String uuid, DBusObjectPath connection) async {
    try {
      for (final path in await _activeOf(uuid)) {
        final devices = await _object(path).getProperty(
          _activeInterface,
          'Devices',
          signature: DBusSignature('ao'),
        );
        for (final device in devices.asObjectPathArray()) {
          await _reapply(device, connection);
        }
      }
    } catch (e) {
      debugPrint('🦜 Erro aplicando a conexão: $e');
    }
  }

  Future<void> _reapply(
    DBusObjectPath device,
    DBusObjectPath connection,
  ) async {
    try {
      await _object(device).callMethod(_deviceInterface, 'Reapply', [
        DBusDict(DBusSignature('s'), DBusSignature('a{sv}'), const {}),
        const DBusUint64(0),
        const DBusUint32(0),
      ], replySignature: DBusSignature(''));
    } on DBusMethodResponseException catch (e) {
      debugPrint('🦜 Reapply recusado, ativando de novo: $e');
      await _object(_managerPath).callMethod(_busName, 'ActivateConnection', [
        connection,
        device,
        DBusObjectPath('/'),
      ], replySignature: DBusSignature('o'));
    }
  }

  @override
  Future<bool> forget(String uuid) async {
    final path = _paths[uuid];
    if (path == null) return false;
    try {
      await _object(path).callMethod(
        _connectionInterface,
        'Delete',
        const [],
        replySignature: DBusSignature(''),
      );
      return true;
    } catch (e) {
      debugPrint('🦜 Erro apagando a conexão: $e');
      return false;
    }
  }

  // O `nmcli` entende os dois formatos, mas não tem como dizer de quem é a
  // conexão nem que ela espere: o WireGuard já vem ligado. Importar não é pedir
  // para entrar na VPN, então ela é desligada aqui, e passa a esperar pedido
  @override
  Future<bool> importVpn(String path) async {
    final String? uuid;
    try {
      uuid = await _import(path);
    } catch (e) {
      debugPrint('🦜 Erro importando a VPN: $e');
      return false;
    }
    if (uuid == null) return false;
    try {
      final settingsPath = await _settings.callMethod(
        _settingsInterface,
        'GetConnectionByUuid',
        [DBusString(uuid)],
        replySignature: DBusSignature('o'),
      );
      final path = settingsPath.returnValues[0].asObjectPath();
      final settings = await _read(path);
      await _object(path).callMethod(_connectionInterface, 'Update', [
        _dict({
          ...settings,
          'connection': {
            ...?settings['connection'],
            'autoconnect': const DBusBoolean(false),
            if (_user case final user? when user.isNotEmpty)
              'permissions': DBusArray.string(['user:$user']),
          },
        }),
      ], replySignature: DBusSignature(''));
      for (final active in await _activeOf(uuid)) {
        await _object(_managerPath).callMethod(
          _busName,
          'DeactivateConnection',
          [active],
          replySignature: DBusSignature(''),
        );
      }
    } catch (e) {
      // Guardada ela está, só que do sistema
      debugPrint('🦜 Erro ajustando a VPN importada: $e');
    }
    return true;
  }

  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _connections.dispose();
  }
}

class FakeNetworkConnections implements PsitoNetworkConnections {
  /// Os arquivos importados.
  final imported = <String>[];

  @override
  final ValueNotifier<List<PsitoSavedConnection>> connections;

  /// O que as próximas ações respondem: false é o diálogo cancelado.
  bool answer = true;

  FakeNetworkConnections([List<PsitoSavedConnection>? initial])
    : connections = ValueNotifier(
        initial ??
            const [
              PsitoSavedConnection(
                uuid: 'casa',
                name: 'Casa',
                kind: PsitoNetworkKind.wifi,
              ),
              PsitoSavedConnection(
                uuid: 'cabo',
                name: 'Wired connection 1',
                kind: PsitoNetworkKind.ethernet,
              ),
            ],
      );

  @override
  Future<bool> update(PsitoSavedConnection connection) async {
    if (!answer) return false;
    connections.value = [
      for (final c in connections.value)
        c.uuid == connection.uuid ? connection : c,
    ];
    return true;
  }

  @override
  Future<bool> forget(String uuid) async {
    if (!answer) return false;
    connections.value = [
      for (final c in connections.value)
        if (c.uuid != uuid) c,
    ];
    return true;
  }

  @override
  Future<bool> importVpn(String path) async {
    if (!answer) return false;
    imported.add(path);
    connections.value = [
      ...connections.value,
      PsitoSavedConnection(
        uuid: 'vpn-${imported.length}',
        name: path.split('/').last.split('.').first,
        kind: PsitoNetworkKind.vpn,
        autoconnect: false,
      ),
    ];
    return true;
  }
}
