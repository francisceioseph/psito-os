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

  group('Wi-Fi', () {
    late FakeDBusObject manager;
    late FakeDBusObject settings;
    late FakeDBusObject device;
    late FakeDBusObject active;
    late FakeDBusObject newConnection;
    final savedByKey = <String, FakeDBusObject>{};

    List<String> savedCalls(String id) => [
      for (final c in savedByKey[id]!.calls) c.name,
    ];

    FakeDBusObject accessPoint(
      int n,
      String ssid,
      int strength, {
      int rsn = 0,
      int privacy = 0,
    }) => FakeDBusObject.single(_path('/AccessPoint/$n'), _ap, {
      'Ssid': DBusArray.byte(ssid.codeUnits),
      'Strength': DBusByte(strength),
      'Flags': DBusUint32(privacy),
      'WpaFlags': const DBusUint32(0),
      'RsnFlags': DBusUint32(rsn),
    });

    const psk = 0x100;
    const sae = 0x400;
    const eap = 0x200;

    Future<void> startWifi({Map<String, String> saved = const {}}) async {
      final root = DBusObject(
        DBusObjectPath('/org/freedesktop'),
        isObjectManager: true,
      );
      final aps = [
        accessPoint(1, 'Fraca', 20),
        accessPoint(2, 'Casa', 40, rsn: psk),
        accessPoint(3, 'Casa', 90, rsn: psk),
        accessPoint(4, '', 99),
        accessPoint(5, 'WPA3', 70, rsn: sae),
        accessPoint(6, 'Firma', 60, rsn: eap),
        accessPoint(7, 'Velha', 50, privacy: 1),
      ];
      device = FakeDBusObject(_path('/Devices/1'), {
        _device: {
          'Interface': const DBusString('wlan0'),
          'IpInterface': const DBusString('wlan0'),
          'DeviceType': const DBusUint32(2),
          'State': const DBusUint32(30),
          'StateReason': DBusStruct([DBusUint32(30), DBusUint32(0)]),
          'ActiveConnection': _none,
          'Ip4Config': _none,
        },
        _wireless: {
          'AccessPoints': DBusArray.objectPath([for (final a in aps) a.path]),
          'ActiveAccessPoint': _none,
        },
      });
      active = FakeDBusObject.single(_path('/ActiveConnection/9'), _active, {
        'Id': const DBusString('nova'),
        'Type': const DBusString('802-11-wireless'),
        'State': const DBusUint32(2),
        'Devices': DBusArray.objectPath([device.path]),
        'Ip4Config': _none,
      });
      newConnection = FakeDBusObject.single(
        _path('/Settings/9'),
        '$_nm.Settings.Connection',
        {},
      );
      final savedObjects = <FakeDBusObject>[];
      saved.forEach((ssid, id) {
        final object =
            FakeDBusObject.single(
                _path('/Settings/$id'),
                '$_nm.Settings.Connection',
                {},
              )
              ..replies['GetSettings'] = [
                DBusDict(DBusSignature('s'), DBusSignature('a{sv}'), {
                  const DBusString('802-11-wireless'): DBusDict.stringVariant({
                    'ssid': DBusArray.byte(ssid.codeUnits),
                  }),
                }),
              ];
        savedByKey[id] = object;
        savedObjects.add(object);
      });
      settings =
          FakeDBusObject.single(_path('/Settings'), '$_nm.Settings', {
              'Connections': DBusArray.objectPath([
                for (final o in savedObjects) o.path,
              ]),
            })
            ..replies['ListConnections'] = [
              DBusArray.objectPath([for (final o in savedObjects) o.path]),
            ];
      manager =
          FakeDBusObject.single(_path(''), _nm, {
              'Devices': DBusArray.objectPath([device.path]),
              'ActiveConnections': DBusArray.objectPath(const []),
              'PrimaryConnection': _none,
              'PrimaryConnectionType': const DBusString(''),
              'Connectivity': const DBusUint32(1),
              'State': const DBusUint32(20),
              'NetworkingEnabled': const DBusBoolean(true),
              'WirelessEnabled': const DBusBoolean(true),
            })
            ..replies['GetDeviceByIpIface'] = [device.path]
            ..replies['AddAndActivateConnection'] = [
              newConnection.path,
              active.path,
            ]
            ..replies['ActivateConnection'] = [active.path];
      await bus.service.registerObject(root);
      for (final o in [
        manager,
        settings,
        device,
        active,
        newConnection,
        ...savedObjects,
        ...aps,
      ]) {
        await bus.service.registerObject(o);
      }
      await bus.service.requestName(_nm);
      service = NetworkManagerService(bus.shell);
      await service.ready;
    }

    Map<String, DBusValue> group(DBusMethodCall call, String name) {
      final dict = call.values[0].asDict();
      return dict[DBusString(name)]!.asStringVariantDict();
    }

    test('lista cada nome uma vez, pelo sinal, sem as ocultas', () async {
      await startWifi(saved: {'Fraca': '1'});
      final wifi = service.state.value.wifi!;
      expect(wifi.enabled, isTrue);
      expect(wifi.networks.map((n) => n.ssid), [
        'Casa',
        'WPA3',
        'Firma',
        'Velha',
        'Fraca',
      ]);
      PsitoWifiNetwork named(String ssid) =>
          wifi.networks.firstWhere((n) => n.ssid == ssid);
      expect(named('Casa').strength, 90);
      expect(named('Casa').security, PsitoWifiSecurity.personal);
      expect(named('WPA3').security, PsitoWifiSecurity.personal);
      expect(named('Firma').security, PsitoWifiSecurity.unsupported);
      expect(named('Velha').security, PsitoWifiSecurity.unsupported);
      expect(named('Fraca').security, PsitoWifiSecurity.open);
      expect(named('Fraca').saved, isTrue);
      expect(named('Casa').saved, isFalse);
    });

    test('rede com senha não tenta sem ela', () async {
      await startWifi();
      expect(await service.connectWifi('Casa'), PsitoWifiResult.needsPassword);
      expect(
        manager.calls.map((c) => c.name),
        isNot(contains('AddAndActivateConnection')),
      );
    });

    test('rede que não existe nem é oculta não tenta', () async {
      await startWifi();
      expect(await service.connectWifi('Nada'), PsitoWifiResult.notFound);
    });

    test('conexão nova vai com a senha, só para esta conta', () async {
      await startWifi();
      expect(
        await service.connectWifi('WPA3', password: 'segredo'),
        PsitoWifiResult.connected,
      );
      final call = manager.calls.firstWhere(
        (c) => c.name == 'AddAndActivateConnection',
      );
      final security = group(call, '802-11-wireless-security');
      expect(security['key-mgmt'], const DBusString('sae'));
      expect(security['psk'], const DBusString('segredo'));
      expect(
        group(call, 'connection')['permissions']!.asStringArray().single,
        startsWith('user:'),
      );
      expect(
        group(call, '802-11-wireless')['ssid']!.asByteArray().toList(),
        'WPA3'.codeUnits,
      );
      expect(newConnection.calls, isEmpty);
    });

    test('rede oculta vai marcada, sem precisar aparecer', () async {
      await startWifi();
      expect(
        await service.connectWifi('Sumida', password: 'segredo', hidden: true),
        PsitoWifiResult.connected,
      );
      final call = manager.calls.firstWhere(
        (c) => c.name == 'AddAndActivateConnection',
      );
      expect(group(call, '802-11-wireless')['hidden'], const DBusBoolean(true));
      expect(
        group(call, '802-11-wireless-security')['key-mgmt'],
        const DBusString('wpa-psk'),
      );
    });

    test('senha errada apaga a conexão nova', () async {
      await startWifi();
      active.interfaces[_active]!['State'] = const DBusUint32(4);
      device.interfaces[_device]!['StateReason'] = DBusStruct([
        DBusUint32(120),
        DBusUint32(7),
      ]);
      expect(
        await service.connectWifi('Casa', password: 'errada'),
        PsitoWifiResult.wrongPassword,
      );
      expect(newConnection.calls.single.name, 'Delete');
    });

    test('o motivo vem do instante da falha, antes de zerar', () async {
      await startWifi();
      active.interfaces[_active]!['State'] = const DBusUint32(1);
      final result = service.connectWifi('Casa', password: 'errada');
      await until(
        () => manager.calls.any((c) => c.name == 'AddAndActivateConnection'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await device.emitSignal(_device, 'StateChanged', const [
        DBusUint32(120),
        DBusUint32(60),
        DBusUint32(7),
      ]);
      await active.change(_active, {'State': const DBusUint32(4)});
      expect(await result, PsitoWifiResult.wrongPassword);
    });

    test('sem achar uma rede que está na lista, foi a senha', () async {
      await startWifi(saved: {'Casa': '1'});
      active.interfaces[_active]!['State'] = const DBusUint32(4);
      device.interfaces[_device]!['StateReason'] = DBusStruct([
        const DBusUint32(120),
        const DBusUint32(53),
      ]);
      expect(await service.connectWifi('Casa'), PsitoWifiResult.wrongPassword);
    });

    test('rede sem rota padrão ainda aparece como a conexão', () async {
      await startWifi();
      await device.change(_device, {
        'State': const DBusUint32(100),
        'ActiveConnection': active.path,
      });
      await until(() => service.state.value.primary != null);
      expect(service.state.value.primary!.connection, 'nova');
      expect(service.state.value.primary!.kind, PsitoNetworkKind.wifi);
    });

    test('rede guardada ativa sem pedir senha e não some na falha', () async {
      await startWifi(saved: {'Fraca': '1'});
      active.interfaces[_active]!['State'] = const DBusUint32(4);
      device.interfaces[_device]!['StateReason'] = DBusStruct([
        DBusUint32(120),
        DBusUint32(53),
      ]);
      expect(await service.connectWifi('Fraca'), PsitoWifiResult.notFound);
      final call = manager.calls.firstWhere(
        (c) => c.name == 'ActivateConnection',
      );
      expect(call.values[0], _path('/Settings/1'));
      expect(newConnection.calls, isEmpty);
    });

    test('esquecer apaga as conexões guardadas daquele nome', () async {
      await startWifi(saved: {'Casa': '1', 'Fraca': '2'});
      await service.forgetWifi('Casa');
      expect(savedCalls('1'), ['GetSettings', 'Delete']);
      expect(savedCalls('2'), ['GetSettings']);
    });
  });

  test('motivos de falha', () async {
    service = NetworkManagerService(bus.shell);
    await service.ready;
    expect(wifiFailure(7), PsitoWifiResult.wrongPassword);
    expect(wifiFailure(11), PsitoWifiResult.wrongPassword);
    expect(wifiFailure(53), PsitoWifiResult.notFound);
    expect(wifiFailure(1), PsitoWifiResult.failed);
  });

  test('o falso segue as mesmas regras', () async {
    final fake = FakeNetworkService();
    service = NetworkManagerService(bus.shell);
    await service.ready;
    addTearDown(fake.dispose);
    expect(await fake.connectWifi('Vizinho'), PsitoWifiResult.needsPassword);
    expect(
      await fake.connectWifi('Vizinho', password: 'x'),
      PsitoWifiResult.wrongPassword,
    );
    expect(
      await fake.connectWifi(
        'Vizinho',
        password: FakeNetworkService.wifiPassword,
      ),
      PsitoWifiResult.connected,
    );
    final first = fake.state.value.wifi!.networks.first;
    expect(first.ssid, 'Vizinho');
    expect(first.active, isTrue);
    await fake.disconnectWifi();
    expect(fake.state.value.wifi!.networks.first.ssid, 'Casa');
  });

  test('sem NetworkManager fica indisponível', () async {
    service = NetworkManagerService(bus.shell);
    await service.ready;
    expect(service.state.value, PsitoNetworkState.unavailable);
  });
}
