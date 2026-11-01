// packages/psito_services/lib/network_service.dart
//
// Estado da rede pelo NetworkManager (pacote nm). O que precisa do caminho dos
// objetos (Enable, ativar conexões, as conexões guardadas) vai direto pelo
// D-Bus, porque o pacote não expõe os caminhos.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:nm/nm.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'dbus_names.dart';

abstract class NetworkService {
  ValueListenable<PsitoNetworkState> get state;

  /// Liga ou desliga toda a rede (modo avião do NetworkManager).
  Future<void> setEnabled(bool enabled);

  /// Liga ou desliga só o rádio de Wi-Fi.
  Future<void> setWifiEnabled(bool enabled);

  /// Pede uma busca. As redes chegam pelo [state].
  Future<void> scanWifi();

  /// Conecta e espera o resultado. Sem [password], só entra em rede aberta ou
  /// guardada. Uma conexão nova que falha não fica guardada. [hidden] é para a
  /// rede que não aparece na busca.
  Future<PsitoWifiResult> connectWifi(
    String ssid, {
    String? password,
    bool hidden = false,
  });

  Future<void> disconnectWifi();

  /// Apaga as conexões guardadas de [ssid], com a senha.
  Future<void> forgetWifi(String ssid);

  Future<void> dispose();
}

/// A ativa primeiro, depois as de sinal mais forte; no empate, pelo nome.
List<PsitoWifiNetwork> sortWifiNetworks(Iterable<PsitoWifiNetwork> networks) =>
    networks.toList()..sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      final bySignal = b.strength.compareTo(a.strength);
      return bySignal != 0 ? bySignal : a.ssid.compareTo(b.ssid);
    });

/// O que o motivo do dispositivo (`NMDeviceStateReason`) quer dizer para quem
/// está conectando. Senha errada aparece como falta de segredo, porque não há
/// agente para pedir outra, ou como queda no meio do aperto de mão.
PsitoWifiResult wifiFailure(int reason) => switch (reason) {
  7 || 8 || 9 || 10 || 11 => PsitoWifiResult.wrongPassword,
  53 => PsitoWifiResult.notFound,
  _ => PsitoWifiResult.failed,
};

class NetworkManagerService implements NetworkService {
  static const busName = 'org.freedesktop.NetworkManager';
  static final managerPath = DBusObjectPath('/org/freedesktop/NetworkManager');
  static final settingsPath = DBusObjectPath(
    '/org/freedesktop/NetworkManager/Settings',
  );
  static const _settingsInterface = '$busName.Settings';
  static const _connectionInterface = '$busName.Settings.Connection';
  static const _activeInterface = '$busName.Connection.Active';
  static const _deviceInterface = '$busName.Device';

  /// `NM_DEVICE_STATE_FAILED`.
  static const _deviceFailed = 120;

  /// Quanto esperar uma conexão ficar pronta, e de quanto em quanto olhar.
  static const _activationTimeout = Duration(seconds: 60);
  static const _activationPoll = Duration(milliseconds: 300);

  final DBusClient _bus;
  late final NetworkManagerClient _nm = NetworkManagerClient(bus: _bus);
  final _state = ValueNotifier(PsitoNetworkState.unavailable);
  bool _connected = false;

  /// Assinaturas que não mudam: objetos que entram e saem.
  final List<StreamSubscription<Object?>> _structure = [];

  /// Uma por objeto atual (dispositivos, conexões, IPs, pontos de acesso);
  /// refeitas quando a lista de objetos muda.
  final List<StreamSubscription<Object?>> _objects = [];
  bool _publishScheduled = false;

  /// As conexões de Wi-Fi guardadas, por nome da rede.
  Map<String, List<DBusObjectPath>> _saved = const {};

  /// Completa depois da primeira leitura, com ou sem sucesso.
  late final Future<void> ready;

  NetworkManagerService(this._bus) {
    ready = _load();
  }

  @override
  ValueListenable<PsitoNetworkState> get state => _state;

  Future<void> _load() async {
    try {
      if (!await busNameAvailable(_bus, busName)) {
        debugPrint('🦜 $busName não está no barramento');
        return;
      }
      await _nm.connect();
      _connected = true;
      void restructure(Object? _) {
        _watchObjects();
        _schedulePublish();
      }

      _structure.addAll([
        _nm.propertiesChanged.listen(restructure),
        _nm.deviceAdded.listen(restructure),
        _nm.deviceRemoved.listen(restructure),
        _nm.activeConnectionAdded.listen(restructure),
        _nm.activeConnectionRemoved.listen(restructure),
      ]);
      final settings = DBusRemoteObject(
        _bus,
        name: busName,
        path: settingsPath,
      );
      for (final name in ['NewConnection', 'ConnectionRemoved']) {
        _structure.add(
          DBusRemoteObjectSignalStream(
            object: settings,
            interface: _settingsInterface,
            name: name,
          ).listen((_) => unawaited(_loadSaved())),
        );
      }
      _watchObjects();
      _publish();
      await _loadSaved();
    } catch (e) {
      debugPrint('🦜 Erro lendo $busName: $e');
    }
  }

  Future<void> _loadSaved() async {
    final saved = <String, List<DBusObjectPath>>{};
    try {
      final list =
          await DBusRemoteObject(
            _bus,
            name: busName,
            path: settingsPath,
          ).callMethod(
            _settingsInterface,
            'ListConnections',
            const [],
            replySignature: DBusSignature('ao'),
          );
      final paths = list.returnValues[0].asObjectPathArray();
      for (final path in paths) {
        final settings = await _connectionSettings(path);
        final ssid = settings['802-11-wireless']?['ssid'];
        if (ssid == null) continue;
        final name = _ssidName(ssid.asByteArray().toList());
        (saved[name] ??= []).add(path);
      }
    } catch (e) {
      debugPrint('🦜 Erro lendo as conexões guardadas: $e');
      return;
    }
    _saved = saved;
    if (_connected) _publish();
  }

  Future<Map<String, Map<String, DBusValue>>> _connectionSettings(
    DBusObjectPath path,
  ) async {
    final reply = await DBusRemoteObject(_bus, name: busName, path: path)
        .callMethod(
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

  static String _ssidName(List<int> ssid) =>
      utf8.decode(ssid, allowMalformed: true);

  void _watchObjects() {
    for (final sub in _objects) {
      sub.cancel();
    }
    _objects.clear();
    void changed(Object? _) => _schedulePublish();

    for (final device in _nm.devices) {
      _objects.add(device.propertiesChanged.listen(changed));
      if (device.ip4Config case final ip?) {
        _objects.add(ip.propertiesChanged.listen(changed));
      }
      if (device.wireless case final wireless?) {
        // A lista de pontos de acesso muda aqui: os novos precisam de assinatura
        _objects.add(
          wireless.propertiesChanged.listen((_) {
            _watchObjects();
            _schedulePublish();
          }),
        );
        for (final ap in wireless.accessPoints) {
          _objects.add(ap.propertiesChanged.listen(changed));
        }
      }
    }
    for (final connection in _nm.activeConnections) {
      _objects.add(connection.propertiesChanged.listen(changed));
      if (connection.ip4Config case final ip?) {
        _objects.add(ip.propertiesChanged.listen(changed));
      }
    }
  }

  // Um sinal costuma vir junto de outros: publica uma vez só
  void _schedulePublish() {
    if (_publishScheduled) return;
    _publishScheduled = true;
    scheduleMicrotask(() {
      _publishScheduled = false;
      if (_connected) _publish();
    });
  }

  PsitoNetworkDevice _describeDevice(
    NetworkManagerDevice device, {
    String? connection,
    PsitoNetworkKind? kind,
    NetworkManagerIP4Config? ip,
  }) => PsitoNetworkDevice(
    interface: kind != null && device.ipInterface.isNotEmpty
        ? device.ipInterface
        : device.interface,
    kind: kind ?? _kindOfDevice(device.deviceType),
    state: _deviceState(device.state),
    connection: connection ?? device.activeConnection?.id,
    ipv4: _address(ip ?? device.ip4Config),
    wifiStrength: _strength(device),
  );

  void _publish() {
    final primary = _nm.primaryConnection;
    final primaryDevice = primary?.devices.firstOrNull;
    final devices = [
      for (final device in _nm.devices)
        if (device.interface != 'lo') _describeDevice(device),
    ];
    _state.value = PsitoNetworkState(
      available: true,
      enabled: _nm.networkingEnabled,
      connectivity: _connectivity(_nm.connectivity),
      connecting:
          _nm.state == NetworkManagerState.connecting ||
          primary?.state == NetworkManagerActiveConnectionState.activating,
      primary: primary == null || primaryDevice == null
          // Numa rede sem rota padrão o NetworkManager não aponta a principal,
          // mas continua conectado nela
          ? devices
                .where(
                  (d) =>
                      d.state == PsitoDeviceState.connected &&
                      d.connection != null,
                )
                .firstOrNull
          : _describeDevice(
              primaryDevice,
              connection: primary.id,
              kind: _kindOfConnection(primary.type),
              ip: primary.ip4Config,
            ),
      devices: devices,
      wifi: _wifiState(),
    );
  }

  /// O primeiro rádio que o NetworkManager gerencia.
  NetworkManagerDevice? get _wifiDevice {
    for (final device in _nm.devices) {
      if (device.wireless != null &&
          device.state != NetworkManagerDeviceState.unmanaged) {
        return device;
      }
    }
    return null;
  }

  PsitoWifiState? _wifiState() {
    final device = _wifiDevice;
    final wireless = device?.wireless;
    if (wireless == null) return null;
    // O ponto de acesso já é o ativo durante o aperto de mão
    final connected = device!.state == NetworkManagerDeviceState.activated;
    final active = wireless.activeAccessPoint?.ssid;
    final activeName = active == null ? null : _ssidName(active);
    final best = <String, NetworkManagerAccessPoint>{};
    for (final ap in wireless.accessPoints) {
      // Sem nome é uma rede oculta, que não dá para listar
      if (ap.ssid.isEmpty) continue;
      final name = _ssidName(ap.ssid);
      if (ap.strength > (best[name]?.strength ?? -1)) best[name] = ap;
    }
    return PsitoWifiState(
      enabled: _nm.wirelessEnabled,
      networks: sortWifiNetworks([
        for (final MapEntry(key: ssid, value: ap) in best.entries)
          PsitoWifiNetwork(
            ssid: ssid,
            strength: ap.strength,
            security: _security(ap),
            active: connected && ssid == activeName,
            saved: _saved.containsKey(ssid),
          ),
      ]),
    );
  }

  static List<NetworkManagerWifiAccessPointSecurityFlag> _securityFlags(
    NetworkManagerAccessPoint ap,
  ) => [...ap.wpaFlags, ...ap.rsnFlags];

  static PsitoWifiSecurity _security(NetworkManagerAccessPoint ap) {
    final flags = _securityFlags(ap);
    if (flags.contains(
      NetworkManagerWifiAccessPointSecurityFlag.keyManagement802_1X,
    )) {
      return PsitoWifiSecurity.unsupported;
    }
    if (flags.contains(
          NetworkManagerWifiAccessPointSecurityFlag.keyManagementPsk,
        ) ||
        flags.contains(
          NetworkManagerWifiAccessPointSecurityFlag.keyManagementSae,
        )) {
      return PsitoWifiSecurity.personal;
    }
    // Criptografia sem WPA é WEP
    return ap.flags.contains(NetworkManagerWifiAccessPointFlag.privacy) &&
            flags.isEmpty
        ? PsitoWifiSecurity.unsupported
        : PsitoWifiSecurity.open;
  }

  /// WPA3 puro é `sae`. Numa rede mista, ou numa oculta, vai `wpa-psk`.
  static String _keyManagement(NetworkManagerAccessPoint? ap) {
    if (ap == null) return 'wpa-psk';
    final flags = _securityFlags(ap);
    return flags.contains(
              NetworkManagerWifiAccessPointSecurityFlag.keyManagementSae,
            ) &&
            !flags.contains(
              NetworkManagerWifiAccessPointSecurityFlag.keyManagementPsk,
            )
        ? 'sae'
        : 'wpa-psk';
  }

  static PsitoConnectivity _connectivity(NetworkManagerConnectivityState c) =>
      switch (c) {
        NetworkManagerConnectivityState.none => PsitoConnectivity.none,
        NetworkManagerConnectivityState.portal => PsitoConnectivity.portal,
        NetworkManagerConnectivityState.limited => PsitoConnectivity.limited,
        NetworkManagerConnectivityState.full => PsitoConnectivity.full,
        _ => PsitoConnectivity.unknown,
      };

  static PsitoNetworkKind _kindOfConnection(String type) => switch (type) {
    '802-3-ethernet' => PsitoNetworkKind.ethernet,
    '802-11-wireless' => PsitoNetworkKind.wifi,
    _ => PsitoNetworkKind.other,
  };

  static PsitoNetworkKind _kindOfDevice(NetworkManagerDeviceType type) =>
      switch (type) {
        NetworkManagerDeviceType.ethernet => PsitoNetworkKind.ethernet,
        NetworkManagerDeviceType.wifi => PsitoNetworkKind.wifi,
        _ => PsitoNetworkKind.other,
      };

  static PsitoDeviceState _deviceState(NetworkManagerDeviceState s) =>
      switch (s) {
        NetworkManagerDeviceState.unavailable => PsitoDeviceState.unavailable,
        NetworkManagerDeviceState.disconnected ||
        NetworkManagerDeviceState.deactivating ||
        NetworkManagerDeviceState.failed => PsitoDeviceState.disconnected,
        NetworkManagerDeviceState.prepare ||
        NetworkManagerDeviceState.config ||
        NetworkManagerDeviceState.needAuth ||
        NetworkManagerDeviceState.ipConfig ||
        NetworkManagerDeviceState.ipCheck ||
        NetworkManagerDeviceState.secondaries => PsitoDeviceState.connecting,
        NetworkManagerDeviceState.activated => PsitoDeviceState.connected,
        _ => PsitoDeviceState.other,
      };

  static String? _address(NetworkManagerIP4Config? config) {
    final first = config?.addressData.firstOrNull;
    if (first == null) return null;
    return '${first['address']}/${first['prefix']}';
  }

  static int? _strength(NetworkManagerDevice device) =>
      device.wireless?.activeAccessPoint?.strength;

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await DBusRemoteObject(_bus, name: busName, path: managerPath).callMethod(
        busName,
        'Enable',
        [DBusBoolean(enabled)],
        replySignature: DBusSignature(''),
      );
    } catch (e) {
      debugPrint('🦜 Erro ao ${enabled ? 'ligar' : 'desligar'} a rede: $e');
    }
  }

  @override
  Future<void> setWifiEnabled(bool enabled) async {
    try {
      await _nm.setWirelessEnabled(enabled);
    } catch (e) {
      debugPrint('🦜 Erro ao ${enabled ? 'ligar' : 'desligar'} o Wi-Fi: $e');
    }
  }

  @override
  Future<void> scanWifi() async {
    try {
      await _wifiDevice?.wireless?.requestScan();
    } catch (e) {
      // O NetworkManager recusa a busca logo depois de outra
      debugPrint('🦜 Busca de Wi-Fi recusada: $e');
    }
  }

  NetworkManagerAccessPoint? _accessPoint(String ssid) {
    NetworkManagerAccessPoint? best;
    for (final ap in _wifiDevice?.wireless?.accessPoints ?? const []) {
      if (_ssidName(ap.ssid) == ssid && ap.strength > (best?.strength ?? -1)) {
        best = ap;
      }
    }
    return best;
  }

  @override
  Future<PsitoWifiResult> connectWifi(
    String ssid, {
    String? password,
    bool hidden = false,
  }) async {
    final device = _wifiDevice;
    if (device == null) return PsitoWifiResult.failed;
    final ap = _accessPoint(ssid);
    final saved = _saved[ssid]?.firstOrNull;
    final secured = ap != null && _security(ap) != PsitoWifiSecurity.open;
    if (saved == null) {
      if (ap == null && !hidden) return PsitoWifiResult.notFound;
      if (secured && password == null) return PsitoWifiResult.needsPassword;
    }
    final manager = DBusRemoteObject(_bus, name: busName, path: managerPath);
    try {
      final reply = await manager.callMethod(busName, 'GetDeviceByIpIface', [
        DBusString(device.interface),
      ], replySignature: DBusSignature('o'));
      final devicePath = reply.returnValues[0].asObjectPath();
      final none = DBusObjectPath('/');
      // O motivo só vale no instante da falha: logo em seguida o dispositivo
      // passa para desconectado, com o motivo zerado
      int? failure;
      final watch =
          DBusRemoteObjectSignalStream(
            object: DBusRemoteObject(_bus, name: busName, path: devicePath),
            interface: _deviceInterface,
            name: 'StateChanged',
            signature: DBusSignature('uuu'),
          ).listen((signal) {
            if (signal.values[0].asUint32() == _deviceFailed) {
              failure = signal.values[2].asUint32();
            }
          });
      try {
        Future<PsitoWifiResult> wait(DBusObjectPath active) async {
          final connected = await _waitForActivation(active);
          if (connected) return PsitoWifiResult.connected;
          final result = wifiFailure(
            failure ?? await _deviceReason(devicePath),
          );
          // O WPA3 recusa a senha antes de associar, e o NetworkManager diz que
          // não achou a rede. Só que ela está ali
          return result == PsitoWifiResult.notFound && secured
              ? PsitoWifiResult.wrongPassword
              : result;
        }

        if (saved != null) {
          if (password != null) await _setPassword(saved, password, ap);
          final activated = await manager.callMethod(
            busName,
            'ActivateConnection',
            [saved, devicePath, none],
            replySignature: DBusSignature('o'),
          );
          return await wait(activated.returnValues[0].asObjectPath());
        }
        // O ponto de acesso fica por conta do NetworkManager, pelo nome
        final added = await manager.callMethod(
          busName,
          'AddAndActivateConnection',
          [
            _settingsDict(_newConnection(ssid, password, ap, hidden)),
            devicePath,
            none,
          ],
          replySignature: DBusSignature('oo'),
        );
        final result = await wait(added.returnValues[1].asObjectPath());
        if (result != PsitoWifiResult.connected) {
          await _deleteConnection(added.returnValues[0].asObjectPath());
        }
        return result;
      } finally {
        await watch.cancel();
      }
    } catch (e) {
      debugPrint('🦜 Erro ao conectar no Wi-Fi: $e');
      return PsitoWifiResult.failed;
    }
  }

  /// A conexão fica só para esta conta: guardar uma para o sistema inteiro
  /// pediria a senha de administrador.
  static Map<String, Map<String, DBusValue>> _newConnection(
    String ssid,
    String? password,
    NetworkManagerAccessPoint? ap,
    bool hidden,
  ) {
    final user = Platform.environment['USER'];
    return {
      'connection': {
        'id': DBusString(ssid),
        'type': const DBusString('802-11-wireless'),
        if (user != null && user.isNotEmpty)
          'permissions': DBusArray.string(['user:$user']),
      },
      '802-11-wireless': {
        'ssid': DBusArray.byte(utf8.encode(ssid)),
        if (hidden) 'hidden': const DBusBoolean(true),
      },
      if (password != null)
        '802-11-wireless-security': _securitySettings(password, ap),
    };
  }

  static Map<String, DBusValue> _securitySettings(
    String password,
    NetworkManagerAccessPoint? ap,
  ) => {
    'key-mgmt': DBusString(_keyManagement(ap)),
    'psk': DBusString(password),
  };

  static DBusDict _settingsDict(Map<String, Map<String, DBusValue>> settings) =>
      DBusDict(DBusSignature('s'), DBusSignature('a{sv}'), {
        for (final MapEntry(key: group, value: values) in settings.entries)
          DBusString(group): DBusDict.stringVariant(values),
      });

  /// Troca a senha de uma conexão guardada, com o resto como está.
  Future<void> _setPassword(
    DBusObjectPath connection,
    String password,
    NetworkManagerAccessPoint? ap,
  ) async {
    final settings = await _connectionSettings(connection);
    settings['802-11-wireless-security'] = {
      ...?settings['802-11-wireless-security'],
      ..._securitySettings(password, ap),
    };
    await DBusRemoteObject(_bus, name: busName, path: connection).callMethod(
      _connectionInterface,
      'Update',
      [_settingsDict(settings)],
      replySignature: DBusSignature(''),
    );
  }

  /// Se a conexão ficou pronta. O estado é lido de tempos em tempos, porque o
  /// sinal podia passar antes da assinatura, e a conexão ativa que some falhou.
  /// A leitura seguinte ao fim dá tempo de o sinal com o motivo chegar.
  Future<bool> _waitForActivation(DBusObjectPath active) async {
    final object = DBusRemoteObject(_bus, name: busName, path: active);
    final deadline = DateTime.now().add(_activationTimeout);
    while (DateTime.now().isBefore(deadline)) {
      int? state;
      try {
        final value = await object.getProperty(
          _activeInterface,
          'State',
          signature: DBusSignature('u'),
        );
        state = value.asUint32();
      } on DBusMethodResponseException {
        state = null;
      }
      if (state == 2) return true;
      await Future<void>.delayed(_activationPoll);
      // 3 é desativando, e 4 desativada
      if (state == null || state > 2) return false;
    }
    await DBusRemoteObject(_bus, name: busName, path: managerPath).callMethod(
      busName,
      'DeactivateConnection',
      [active],
      replySignature: DBusSignature(''),
    );
    return false;
  }

  Future<int> _deviceReason(DBusObjectPath device) async {
    try {
      final value = await DBusRemoteObject(_bus, name: busName, path: device)
          .getProperty(
            _deviceInterface,
            'StateReason',
            signature: DBusSignature('(uu)'),
          );
      return value.asStruct()[1].asUint32();
    } catch (e) {
      debugPrint('🦜 Erro lendo o motivo da falha: $e');
      return 0;
    }
  }

  Future<void> _deleteConnection(DBusObjectPath connection) async {
    try {
      await DBusRemoteObject(_bus, name: busName, path: connection).callMethod(
        _connectionInterface,
        'Delete',
        const [],
        replySignature: DBusSignature(''),
      );
    } catch (e) {
      debugPrint('🦜 Erro apagando a conexão: $e');
    }
  }

  @override
  Future<void> disconnectWifi() async {
    try {
      await _wifiDevice?.disconnect();
    } catch (e) {
      debugPrint('🦜 Erro ao desconectar o Wi-Fi: $e');
    }
  }

  @override
  Future<void> forgetWifi(String ssid) async {
    for (final connection in _saved[ssid] ?? const <DBusObjectPath>[]) {
      await _deleteConnection(connection);
    }
  }

  @override
  Future<void> dispose() async {
    for (final sub in [..._structure, ..._objects]) {
      await sub.cancel();
    }
    _connected = false;
    await _nm.close();
    _state.dispose();
  }
}

class FakeNetworkService implements NetworkService {
  final ValueNotifier<PsitoNetworkState> _state;

  FakeNetworkService([PsitoNetworkState initial = sample])
    : _state = ValueNotifier(initial);

  static const ethernet = PsitoNetworkDevice(
    interface: 'ens3',
    kind: PsitoNetworkKind.ethernet,
    state: PsitoDeviceState.connected,
    connection: 'Wired connection 1',
    ipv4: '10.0.2.15/24',
  );

  /// A senha que as redes falsas aceitam.
  static const wifiPassword = 'calopsita';

  static const sample = PsitoNetworkState(
    available: true,
    connectivity: PsitoConnectivity.full,
    primary: ethernet,
    devices: [ethernet],
    wifi: PsitoWifiState(
      networks: [
        PsitoWifiNetwork(
          ssid: 'Casa',
          strength: 80,
          security: PsitoWifiSecurity.personal,
          saved: true,
        ),
        PsitoWifiNetwork(ssid: 'Cafeteria', strength: 55),
        PsitoWifiNetwork(
          ssid: 'Vizinho',
          strength: 30,
          security: PsitoWifiSecurity.personal,
        ),
        PsitoWifiNetwork(
          ssid: 'Firma',
          strength: 20,
          security: PsitoWifiSecurity.unsupported,
        ),
      ],
    ),
  );

  @override
  ValueListenable<PsitoNetworkState> get state => _state;

  void set(PsitoNetworkState state) => _state.value = state;

  /// Estado de antes de desligar, para religar como estava.
  PsitoNetworkState? _beforeDisable;

  @override
  Future<void> setEnabled(bool enabled) async {
    final s = _state.value;
    if (enabled == s.enabled) return;
    if (enabled) {
      _state.value = _beforeDisable ?? sample;
      return;
    }
    _beforeDisable = s;
    _state.value = PsitoNetworkState(
      available: s.available,
      enabled: false,
      connectivity: PsitoConnectivity.none,
      devices: s.devices,
      wifi: s.wifi,
    );
  }

  int scans = 0;

  void _setWifi(PsitoWifiState wifi) {
    final s = _state.value;
    _state.value = PsitoNetworkState(
      available: s.available,
      enabled: s.enabled,
      connectivity: s.connectivity,
      connecting: s.connecting,
      primary: s.primary,
      devices: s.devices,
      wifi: wifi,
    );
  }

  void _setNetworks(
    PsitoWifiNetwork Function(PsitoWifiNetwork network) change,
  ) {
    final wifi = _state.value.wifi;
    if (wifi == null) return;
    _setWifi(
      PsitoWifiState(
        enabled: wifi.enabled,
        networks: sortWifiNetworks(wifi.networks.map(change)),
      ),
    );
  }

  static PsitoWifiNetwork _copy(
    PsitoWifiNetwork n, {
    required bool active,
    required bool saved,
  }) => PsitoWifiNetwork(
    ssid: n.ssid,
    strength: n.strength,
    security: n.security,
    active: active,
    saved: saved,
  );

  @override
  Future<void> setWifiEnabled(bool enabled) async {
    final wifi = _state.value.wifi;
    if (wifi != null) {
      _setWifi(PsitoWifiState(enabled: enabled, networks: wifi.networks));
    }
  }

  @override
  Future<void> scanWifi() async => scans++;

  @override
  Future<PsitoWifiResult> connectWifi(
    String ssid, {
    String? password,
    bool hidden = false,
  }) async {
    final network = _state.value.wifi?.networks
        .where((n) => n.ssid == ssid)
        .firstOrNull;
    if (network == null) {
      if (!hidden) return PsitoWifiResult.notFound;
      if (password != wifiPassword) return PsitoWifiResult.wrongPassword;
      final wifi = _state.value.wifi!;
      _setWifi(
        PsitoWifiState(
          enabled: wifi.enabled,
          networks: sortWifiNetworks([
            for (final n in wifi.networks)
              _copy(n, active: false, saved: n.saved),
            PsitoWifiNetwork(
              ssid: ssid,
              strength: 60,
              security: PsitoWifiSecurity.personal,
              active: true,
              saved: true,
            ),
          ]),
        ),
      );
      return PsitoWifiResult.connected;
    }
    if (network.security != PsitoWifiSecurity.open && !network.saved) {
      if (password == null) return PsitoWifiResult.needsPassword;
      if (password != wifiPassword) return PsitoWifiResult.wrongPassword;
    }
    _setNetworks(
      (n) => n.ssid == ssid
          ? _copy(n, active: true, saved: true)
          : _copy(n, active: false, saved: n.saved),
    );
    return PsitoWifiResult.connected;
  }

  @override
  Future<void> disconnectWifi() async =>
      _setNetworks((n) => _copy(n, active: false, saved: n.saved));

  @override
  Future<void> forgetWifi(String ssid) async => _setNetworks(
    (n) => n.ssid == ssid ? _copy(n, active: n.active, saved: false) : n,
  );

  @override
  Future<void> dispose() async => _state.dispose();
}
