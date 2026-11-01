// packages/psito_services/lib/network_service.dart
//
// Estado da rede pelo NetworkManager (pacote nm). Ligar e desligar usa o
// método Enable direto pelo D-Bus, que o pacote não expõe.
import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:nm/nm.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'dbus_names.dart';

abstract class NetworkService {
  ValueListenable<PsitoNetworkState> get state;

  /// Liga ou desliga toda a rede (modo avião do NetworkManager).
  Future<void> setEnabled(bool enabled);

  Future<void> dispose();
}

class NetworkManagerService implements NetworkService {
  static const busName = 'org.freedesktop.NetworkManager';
  static final managerPath = DBusObjectPath('/org/freedesktop/NetworkManager');

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
      _watchObjects();
      _publish();
    } catch (e) {
      debugPrint('🦜 Erro lendo $busName: $e');
    }
  }

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
        _objects.add(wireless.propertiesChanged.listen(changed));
        if (wireless.activeAccessPoint case final ap?) {
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

  void _publish() {
    final primary = _nm.primaryConnection;
    final primaryDevice = primary?.devices.firstOrNull;
    _state.value = PsitoNetworkState(
      available: true,
      enabled: _nm.networkingEnabled,
      connectivity: _connectivity(_nm.connectivity),
      connecting:
          _nm.state == NetworkManagerState.connecting ||
          primary?.state == NetworkManagerActiveConnectionState.activating,
      primary: primary == null || primaryDevice == null
          ? null
          : PsitoNetworkDevice(
              interface: primaryDevice.ipInterface.isNotEmpty
                  ? primaryDevice.ipInterface
                  : primaryDevice.interface,
              kind: _kindOfConnection(primary.type),
              state: _deviceState(primaryDevice.state),
              connection: primary.id,
              ipv4: _address(primary.ip4Config),
              wifiStrength: _strength(primaryDevice),
            ),
      devices: [
        for (final device in _nm.devices)
          if (device.interface != 'lo')
            PsitoNetworkDevice(
              interface: device.interface,
              kind: _kindOfDevice(device.deviceType),
              state: _deviceState(device.state),
              connection: device.activeConnection?.id,
              ipv4: _address(device.ip4Config),
              wifiStrength: _strength(device),
            ),
      ],
    );
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

  static const sample = PsitoNetworkState(
    available: true,
    connectivity: PsitoConnectivity.full,
    primary: ethernet,
    devices: [ethernet],
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
    );
  }

  @override
  Future<void> dispose() async => _state.dispose();
}
