import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/network_connections.dart';

import 'dbus_test_bus.dart';

const _nm = 'org.freedesktop.NetworkManager';
const _base = '/org/freedesktop/NetworkManager';

DBusObjectPath _path(String sub) => DBusObjectPath('$_base$sub');

NmSettings _wifi(String uuid, String name, {Map<String, DBusValue>? ipv4}) => {
  'connection': {
    'uuid': DBusString(uuid),
    'id': DBusString(name),
    'type': const DBusString('802-11-wireless'),
    'permissions': DBusArray.string(['user:ana']),
  },
  '802-11-wireless': {'ssid': DBusArray.byte(name.codeUnits)},
  'ipv4': ipv4 ?? {'method': const DBusString('auto')},
};

DBusDict _dict(NmSettings settings) =>
    DBusDict(DBusSignature('s'), DBusSignature('a{sv}'), {
      for (final MapEntry(key: group, value: values) in settings.entries)
        DBusString(group): DBusDict.stringVariant(values),
    });

void main() {
  group('leitura', () {
    test('Wi-Fi com o padrão de tudo', () {
      expect(
        savedConnectionFrom(_wifi('u1', 'Casa')),
        const PsitoSavedConnection(
          uuid: 'u1',
          name: 'Casa',
          kind: PsitoNetworkKind.wifi,
        ),
      );
    });

    test('o que não é cabo nem Wi-Fi fica de fora', () {
      expect(
        savedConnectionFrom({
          'connection': {
            'uuid': const DBusString('lo'),
            'id': const DBusString('lo'),
            'type': const DBusString('loopback'),
          },
        }),
        isNull,
      );
    });

    test('manual, com DNS no formato antigo', () {
      final c = savedConnectionFrom(
        _wifi(
          'u1',
          'Casa',
          ipv4: {
            'method': const DBusString('manual'),
            'gateway': const DBusString('192.168.0.1'),
            'address-data': DBusArray(DBusSignature('a{sv}'), [
              DBusDict.stringVariant({
                'address': const DBusString('192.168.0.10'),
                'prefix': const DBusUint32(24),
              }),
            ]),
            // 1.1.1.1 e 8.8.4.4, com o primeiro byte embaixo
            'dns': DBusArray.uint32([0x01010101, 0x04040808]),
          },
        ),
      )!;
      expect(c.ipv4Method, PsitoIpMethod.manual);
      expect(c.address, '192.168.0.10/24');
      expect(c.gateway, '192.168.0.1');
      expect(c.dns, ['1.1.1.1', '8.8.4.4']);
    });

    test('WireGuard e OpenVPN são VPNs', () {
      for (final type in ['wireguard', 'vpn']) {
        expect(
          savedConnectionFrom({
            'connection': {
              'uuid': const DBusString('v'),
              'id': const DBusString('v'),
              'type': DBusString(type),
            },
          })!.kind,
          PsitoNetworkKind.vpn,
        );
      }
    });

    test('um modo que as Configurações não mudam', () {
      final c = savedConnectionFrom(
        _wifi('u1', 'Casa', ipv4: {'method': const DBusString('shared')}),
      )!;
      expect(c.ipv4Method, PsitoIpMethod.other);
    });
  });

  group('gravação', () {
    const base = PsitoSavedConnection(
      uuid: 'u1',
      name: 'Casa',
      kind: PsitoNetworkKind.wifi,
    );

    test('manual troca o endereço e tira os dois formatos antigos', () {
      final settings = applySavedConnection(
        _wifi(
          'u1',
          'Casa',
          ipv4: {
            'method': const DBusString('auto'),
            'addresses': DBusArray(DBusSignature('au'), const []),
            'dns': DBusArray.uint32([1]),
          },
        ),
        base.copyWith(
          ipv4Method: PsitoIpMethod.manual,
          address: '10.0.0.5/8',
          gateway: '10.0.0.1',
          dns: ['1.1.1.1'],
          priority: 7,
          autoconnect: false,
          metered: PsitoMetered.yes,
        ),
      );
      final ipv4 = settings['ipv4']!;
      expect(ipv4['method'], const DBusString('manual'));
      expect(ipv4.containsKey('addresses'), isFalse);
      expect(ipv4['gateway'], const DBusString('10.0.0.1'));
      expect(ipv4['ignore-auto-dns'], const DBusBoolean(true));
      final connection = settings['connection']!;
      expect(connection['autoconnect'], const DBusBoolean(false));
      expect(connection['autoconnect-priority'], const DBusInt32(7));
      expect(connection['metered'], const DBusInt32(1));
      // O resto fica
      expect(connection['permissions']!.asStringArray(), ['user:ana']);
      expect(settings['802-11-wireless'], isNotNull);
      // E relido dá o mesmo
      final again = savedConnectionFrom(settings)!;
      expect(again.address, '10.0.0.5/8');
      expect(again.dns, ['1.1.1.1']);
    });

    test('voltar para automático limpa o endereço', () {
      final settings = applySavedConnection(
        _wifi(
          'u1',
          'Casa',
          ipv4: {
            'method': const DBusString('manual'),
            'gateway': const DBusString('10.0.0.1'),
            'dns': DBusArray.uint32([1]),
            'ignore-auto-dns': const DBusBoolean(true),
          },
        ),
        base,
      );
      expect(settings['ipv4'], {'method': const DBusString('auto')});
    });

    test('o endereço de uma VPN é do arquivo dela', () {
      final ipv4 = {
        'method': const DBusString('manual'),
        'address-data': DBusArray(DBusSignature('a{sv}'), [
          DBusDict.stringVariant({
            'address': const DBusString('10.8.0.2'),
            'prefix': const DBusUint32(24),
          }),
          DBusDict.stringVariant({
            'address': const DBusString('10.9.0.2'),
            'prefix': const DBusUint32(24),
          }),
        ]),
      };
      final settings = applySavedConnection(
        {
          'connection': {
            'uuid': const DBusString('v'),
            'type': const DBusString('wireguard'),
          },
          'ipv4': ipv4,
        },
        const PsitoSavedConnection(
          uuid: 'v',
          name: 'wg',
          kind: PsitoNetworkKind.vpn,
          autoconnect: false,
        ),
      );
      expect(settings['ipv4'], ipv4);
      expect(settings['connection']!['autoconnect'], const DBusBoolean(false));
    });

    test('sem mudar o primeiro endereço, os outros ficam', () {
      final addresses = DBusArray(DBusSignature('a{sv}'), [
        DBusDict.stringVariant({
          'address': const DBusString('10.0.0.5'),
          'prefix': const DBusUint32(8),
        }),
        DBusDict.stringVariant({
          'address': const DBusString('10.0.0.6'),
          'prefix': const DBusUint32(8),
        }),
      ]);
      final settings = applySavedConnection(
        _wifi(
          'u1',
          'Casa',
          ipv4: {
            'method': const DBusString('manual'),
            'address-data': addresses,
          },
        ),
        base.copyWith(ipv4Method: PsitoIpMethod.manual, address: '10.0.0.5/8'),
      );
      expect(settings['ipv4']!['address-data'], addresses);
    });

    test('um modo que não mudamos fica como está', () {
      final settings = applySavedConnection(
        _wifi('u1', 'Casa', ipv4: {'method': const DBusString('shared')}),
        base.copyWith(ipv4Method: PsitoIpMethod.other),
      );
      expect(settings['ipv4'], {'method': const DBusString('shared')});
    });
  });

  group('no barramento', () {
    late DBusTestBus bus;
    late FakeDBusObject saved;
    late FakeDBusObject device;
    late FakeDBusObject manager;
    late FakeDBusObject settings;
    late FakeDBusObject active;
    late NetworkManagerConnections service;
    late List<String> imported;

    setUp(() async {
      imported = [];
      bus = await DBusTestBus.start();
      saved = FakeDBusObject.single(
        _path('/Settings/1'),
        '$_nm.Settings.Connection',
        const {},
      )..replies['GetSettings'] = [_dict(_wifi('u1', 'Casa'))];
      device = FakeDBusObject.single(
        _path('/Devices/1'),
        '$_nm.Device',
        const {},
      );
      active = FakeDBusObject.single(
        _path('/ActiveConnection/1'),
        '$_nm.Connection.Active',
        {
          'Uuid': const DBusString('u1'),
          'Devices': DBusArray.objectPath([device.path]),
        },
      );
      settings =
          FakeDBusObject.single(_path('/Settings'), '$_nm.Settings', const {})
            ..replies['ListConnections'] = [
              DBusArray.objectPath([saved.path]),
            ];
      manager = FakeDBusObject.single(DBusObjectPath(_base), _nm, {
        'ActiveConnections': DBusArray.objectPath([active.path]),
      });
      for (final object in [saved, device, active, settings]) {
        await bus.service.registerObject(object);
      }
      await bus.publish(_nm, manager);
      service = NetworkManagerConnections(bus.shell);
      await service.ready;
    });

    tearDown(() async {
      await service.dispose();
      await bus.close();
    });

    test('lista as conexões', () {
      expect(service.connections.value.map((c) => c.name), ['Casa']);
    });

    test('gravar vale na hora na conexão ativa', () async {
      final ok = await service.update(
        service.connections.value.single.copyWith(priority: 5),
      );
      expect(ok, isTrue);
      final update = saved.calls.singleWhere((c) => c.name == 'Update');
      final group = update.values[0].asDict()[const DBusString('connection')];
      expect(
        group!.asStringVariantDict()['autoconnect-priority'],
        const DBusInt32(5),
      );
      expect(device.calls.single.name, 'Reapply');
    });

    test('fora da conexão ativa só grava', () async {
      active.interfaces['$_nm.Connection.Active']!['Uuid'] = const DBusString(
        'outra',
      );
      expect(await service.update(service.connections.value.single), isTrue);
      expect(device.calls, isEmpty);
    });

    Future<NetworkManagerConnections> importing(String? uuid) async {
      await service.dispose();
      return service = NetworkManagerConnections(
        bus.shell,
        user: 'ana',
        importer: (path) async {
          imported.add(path);
          return uuid;
        },
      );
    }

    test('a conexão importada fica da conta e desligada', () async {
      settings.replies['GetConnectionByUuid'] = [saved.path];
      await importing('11111111-2222-3333-4444-555555555555');
      expect(await service.importVpn('/home/ana/x.ovpn'), isTrue);
      expect(imported, ['/home/ana/x.ovpn']);
      final group = saved.calls
          .singleWhere((c) => c.name == 'Update')
          .values[0]
          .asDict()[const DBusString('connection')]!
          .asStringVariantDict();
      expect(group['autoconnect'], const DBusBoolean(false));
      expect(group['permissions']!.asStringArray(), ['user:ana']);
    });

    test('importar não deixa a VPN ligada', () async {
      const uuid = '11111111-2222-3333-4444-555555555555';
      settings.replies['GetConnectionByUuid'] = [saved.path];
      active.interfaces['$_nm.Connection.Active']!['Uuid'] = const DBusString(
        uuid,
      );
      await importing(uuid);
      expect(await service.importVpn('/home/ana/x.conf'), isTrue);
      final call = manager.calls.singleWhere(
        (c) => c.name == 'DeactivateConnection',
      );
      expect(call.values[0], active.path);
    });

    test('arquivo recusado não dá certo', () async {
      await importing(null);
      expect(await service.importVpn('/home/ana/x.conf'), isFalse);
    });

    test('esquecer apaga', () async {
      expect(await service.forget('u1'), isTrue);
      expect(saved.calls.last.name, 'Delete');
      expect(await service.forget('nenhuma'), isFalse);
    });
  });

  test('o uuid na resposta do nmcli', () {
    expect(
      importedUuid(
        'Conexão “x” (11111111-2222-3333-4444-555555555555) adicionada.',
      ),
      '11111111-2222-3333-4444-555555555555',
    );
    expect(importedUuid('erro'), isNull);
  });

  test('o nmcli recebe o tipo pela extensão', () async {
    late List<String> args;
    Future<ProcessResult> Function(String, List<String>) answer(
      int code,
      String out,
    ) => (command, a) async {
      args = a;
      return ProcessResult(0, code, out, '');
    };
    expect(
      await importVpnFile(
        '/home/ana/x.OVPN',
        run: answer(0, '(11111111-2222-3333-4444-555555555555) added'),
      ),
      '11111111-2222-3333-4444-555555555555',
    );
    expect(args.sublist(2, 4), ['type', 'openvpn']);
    expect(await importVpnFile('/home/ana/x.conf', run: answer(1, '')), isNull);
    expect(args.sublist(2, 4), ['type', 'wireguard']);
  });

  test('o falso segue as mesmas regras', () async {
    final fake = FakeNetworkConnections();
    final casa = fake.connections.value.first;
    expect(await fake.update(casa.copyWith(priority: 3)), isTrue);
    expect(fake.connections.value.first.priority, 3);
    fake.answer = false;
    expect(await fake.forget(casa.uuid), isFalse);
    fake.answer = true;
    expect(await fake.forget(casa.uuid), isTrue);
    expect(fake.connections.value.map((c) => c.uuid), ['cabo']);
  });
}
