import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/network_service.dart';

import 'dbus_test_bus.dart';

const _nm = 'org.freedesktop.NetworkManager';
const _device = '$_nm.Device';
const _wireless = '$_nm.Device.Wireless';
const _active = '$_nm.Connection.Active';
const _ip4 = '$_nm.IP4Config';
const _ap = '$_nm.AccessPoint';

DBusObjectPath _path(String suffix) =>
    DBusObjectPath('/org/freedesktop/NetworkManager$suffix');

final _none = DBusObjectPath('/');

/// NetworkManager falso: cabo (ens3) conectado, ou Wi-Fi com [wifiStrength].
class _FakeNM {
  final root = DBusObject(
    DBusObjectPath('/org/freedesktop'),
    isObjectManager: true,
  );
  late final FakeDBusObject manager;
  late final FakeDBusObject device;
  late final FakeDBusObject connection;
  final List<FakeDBusObject> others = [];

  _FakeNM({int? wifiStrength}) {
    final wifi = wifiStrength != null;
    final ip = FakeDBusObject.single(_path('/IP4Config/1'), _ip4, {
      'AddressData': DBusArray(DBusSignature('a{sv}'), [
        DBusDict.stringVariant({
          'address': const DBusString('10.0.2.15'),
          'prefix': const DBusUint32(24),
        }),
      ]),
    });
    connection = FakeDBusObject.single(_path('/ActiveConnection/1'), _active, {
      'Id': DBusString(wifi ? 'Calopsita' : 'Wired connection 1'),
      'Type': DBusString(wifi ? '802-11-wireless' : '802-3-ethernet'),
      'State': const DBusUint32(2),
      'Devices': DBusArray.objectPath([_path('/Devices/1')]),
      'Ip4Config': ip.path,
    });
    device = FakeDBusObject(_path('/Devices/1'), {
      _device: {
        'Interface': DBusString(wifi ? 'wlan0' : 'ens3'),
        'IpInterface': DBusString(wifi ? 'wlan0' : 'ens3'),
        'DeviceType': DBusUint32(wifi ? 2 : 1),
        'State': const DBusUint32(100),
        'ActiveConnection': connection.path,
        'Ip4Config': ip.path,
      },
      if (wifi) _wireless: {'ActiveAccessPoint': _path('/AccessPoint/1')},
    });
    final loopback = FakeDBusObject.single(_path('/Devices/0'), _device, {
      'Interface': const DBusString('lo'),
      'DeviceType': const DBusUint32(32),
      'State': const DBusUint32(100),
      'ActiveConnection': _none,
      'Ip4Config': _none,
    });
    manager = FakeDBusObject.single(_path(''), _nm, {
      'Devices': DBusArray.objectPath([loopback.path, device.path]),
      'ActiveConnections': DBusArray.objectPath([connection.path]),
      'PrimaryConnection': connection.path,
      'PrimaryConnectionType': connection.interfaces[_active]!['Type']!,
      'Connectivity': const DBusUint32(4),
      'State': const DBusUint32(70),
      'NetworkingEnabled': const DBusBoolean(true),
    });
    others.addAll([ip, loopback]);
    if (wifi) {
      others.add(
        FakeDBusObject.single(_path('/AccessPoint/1'), _ap, {
          'Strength': DBusByte(wifiStrength),
        }),
      );
    }
  }

  Future<void> publish(DBusTestBus bus) async {
    await bus.service.registerObject(root);
    for (final o in [manager, device, connection, ...others]) {
      await bus.service.registerObject(o);
    }
    await bus.service.requestName(_nm);
  }
}

void main() {
  late DBusTestBus bus;
  late NetworkManagerService service;

  setUp(() async => bus = await DBusTestBus.start());
  tearDown(() async {
    await service.dispose();
    await bus.close();
  });

  Future<_FakeNM> start({int? wifiStrength}) async {
    final nm = _FakeNM(wifiStrength: wifiStrength);
    await nm.publish(bus);
    service = NetworkManagerService(bus.shell);
    await service.ready;
    return nm;
  }

  test('cabo conectado vira a conexão principal; lo fica de fora', () async {
    await start();
    const ens3 = PsitoNetworkDevice(
      interface: 'ens3',
      kind: PsitoNetworkKind.ethernet,
      state: PsitoDeviceState.connected,
      connection: 'Wired connection 1',
      ipv4: '10.0.2.15/24',
    );
    expect(
      service.state.value,
      const PsitoNetworkState(
        available: true,
        connectivity: PsitoConnectivity.full,
        primary: ens3,
        devices: [ens3],
      ),
    );
  });

  test('cabo desligado tira a conexão principal', () async {
    final nm = await start();
    await nm.device.change(_device, {
      'State': const DBusUint32(20),
      'ActiveConnection': _none,
      'Ip4Config': _none,
    });
    await nm.manager.change(_nm, {
      'PrimaryConnection': _none,
      'ActiveConnections': DBusArray.objectPath([]),
      'Connectivity': const DBusUint32(1),
      'State': const DBusUint32(20),
    });
    await until(() => service.state.value.primary == null);

    final state = service.state.value;
    expect(state.primary, isNull);
    expect(state.connectivity, PsitoConnectivity.none);
    expect(state.devices.single.state, PsitoDeviceState.unavailable);
  });

  test('NetworkingEnabled falso desliga', () async {
    final nm = await start();
    await nm.manager.change(_nm, {
      'NetworkingEnabled': const DBusBoolean(false),
    });
    await until(() => !service.state.value.enabled);
    expect(service.state.value.enabled, isFalse);
  });

  test('Wi-Fi traz o sinal do ponto de acesso', () async {
    await start(wifiStrength: 55);
    final primary = service.state.value.primary!;
    expect(primary.kind, PsitoNetworkKind.wifi);
    expect(primary.connection, 'Calopsita');
    expect(primary.wifiStrength, 55);
  });

  test('setEnabled chama Enable no NetworkManager', () async {
    final nm = await start();
    await service.setEnabled(false);
    final call = nm.manager.calls.single;
    expect((call.interface, call.name), (_nm, 'Enable'));
    expect(call.values, [const DBusBoolean(false)]);
  });

  test('sem NetworkManager fica indisponível', () async {
    service = NetworkManagerService(bus.shell);
    await service.ready;
    expect(service.state.value, PsitoNetworkState.unavailable);
  });
}
