import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/disks_service.dart';

import 'dbus_test_bus.dart';

const _udisks = 'org.freedesktop.UDisks2';
const _base = '/org/freedesktop/UDisks2';

DBusObjectPath _path(String sub) => DBusObjectPath('$_base/$sub');
final _none = DBusObjectPath('/');

DBusValue _text(String text) => DBusArray.byte([...text.codeUnits, 0]);

Map<String, Map<String, DBusValue>> _block(
  String device, {
  String usage = 'filesystem',
  String type = 'vfat',
  String label = '',
  String? mount,
  bool system = false,
  bool ignore = false,
  String? drive = 'drives/usb',
  String? backing,
  String? cleartext,
  bool crypto = false,
}) => {
  '$_udisks.Block': {
    'Device': _text(device),
    'IdUsage': DBusString(usage),
    'IdType': DBusString(type),
    'IdLabel': DBusString(label),
    'Size': const DBusUint64(1000),
    'ReadOnly': const DBusBoolean(false),
    'HintSystem': DBusBoolean(system),
    'HintIgnore': DBusBoolean(ignore),
    'Drive': drive == null ? _none : _path(drive),
    'CryptoBackingDevice': backing == null ? _none : _path(backing),
  },
  if (!crypto && usage == 'filesystem')
    '$_udisks.Filesystem': {
      'MountPoints': DBusArray(DBusSignature('ay'), [
        ?mount == null ? null : _text(mount),
      ]),
    },
  if (crypto)
    '$_udisks.Encrypted': {
      'CleartextDevice': cleartext == null ? _none : _path(cleartext),
    },
};

Map<String, Map<String, DBusValue>> _drive({
  bool powerOff = true,
  bool ejectable = false,
}) => {
  '$_udisks.Drive': {
    'CanPowerOff': DBusBoolean(powerOff),
    'Ejectable': DBusBoolean(ejectable),
  },
};

void main() {
  group('volumesFrom', () {
    test('mostra o pendrive, com o nome, o lugar e o disco', () {
      final volumes = volumesFrom({
        _path('drives/usb'): _drive(),
        _path('block_devices/sdb1'): _block(
          '/dev/sdb1',
          label: 'PENDRIVE',
          mount: '/run/media/ana/PENDRIVE',
        ),
      });
      final volume = volumes.single;
      expect(volume.id, '$_base/block_devices/sdb1');
      expect(volume.label, 'PENDRIVE');
      expect(volume.device, '/dev/sdb1');
      expect(volume.mountPoint, '/run/media/ana/PENDRIVE');
      expect(volume.drive, '$_base/drives/usb');
      expect(volume.canEject, isTrue);
      expect(volume.fileSystem, 'vfat');
    });

    test('deixa de fora o disco do sistema, o ignorado e o que não tem '
        'sistema de arquivos', () {
      expect(
        volumesFrom({
          _path('block_devices/sda1'): _block('/dev/sda1', system: true),
          _path('block_devices/sda2'): _block('/dev/sda2', ignore: true),
          _path('block_devices/sdb'): _block('/dev/sdb', usage: ''),
          _path('block_devices/swap'): _block('/dev/sdb2', usage: 'other'),
          _path('drives/usb'): _drive(),
        }),
        isEmpty,
      );
    });

    test('sem montar, o lugar fica nulo', () {
      final volume = volumesFrom({
        _path('block_devices/sdb1'): _block('/dev/sdb1'),
      }).single;
      expect(volume.mountPoint, isNull);
      expect(volume.canEject, isFalse);
    });

    test('um trancado aparece; destrancado, só o de dentro', () {
      final locked = volumesFrom({
        _path('drives/usb'): _drive(),
        _path('block_devices/sdb1'): _block(
          '/dev/sdb1',
          usage: 'crypto',
          type: 'crypto_LUKS',
          crypto: true,
        ),
      }).single;
      expect(locked.locked, isTrue);

      final inside = volumesFrom({
        _path('drives/usb'): _drive(),
        _path('block_devices/sdb1'): _block(
          '/dev/sdb1',
          usage: 'crypto',
          crypto: true,
          cleartext: 'block_devices/dm_2d0',
        ),
        _path('block_devices/dm_2d0'): _block(
          '/dev/dm-0',
          label: 'COFRE',
          type: 'ext4',
          system: true,
          drive: null,
          backing: 'block_devices/sdb1',
        ),
      }).single;
      expect(inside.label, 'COFRE');
      expect(inside.locked, isFalse);
      expect(inside.unlocked, isTrue);
      // As dicas e o disco vêm do de fora
      expect(inside.drive, '$_base/drives/usb');
    });

    test('um trancado do disco do sistema fica de fora', () {
      expect(
        volumesFrom({
          _path('block_devices/sda3'): _block(
            '/dev/sda3',
            usage: 'crypto',
            crypto: true,
            system: true,
          ),
        }),
        isEmpty,
      );
    });

    test('ordena pelo nome', () {
      final volumes = volumesFrom({
        _path('block_devices/a'): _block('/dev/a', label: 'zeta'),
        _path('block_devices/b'): _block('/dev/b', label: 'Alfa'),
      });
      expect(volumes.map((v) => v.label), ['Alfa', 'zeta']);
    });
  });

  group('no barramento', () {
    late DBusTestBus bus;
    late FakeDBusObject sdb1;
    late FakeDBusObject sdb2;
    late FakeDBusObject drive;
    late UDisks2Service service;

    setUp(() async {
      bus = await DBusTestBus.start();
      final root = DBusObject(DBusObjectPath(_base), isObjectManager: true);
      sdb1 = FakeDBusObject(
        _path('block_devices/sdb1'),
        _block('/dev/sdb1', label: 'UM', mount: '/run/media/ana/UM'),
      );
      sdb2 = FakeDBusObject(
        _path('block_devices/sdb2'),
        _block('/dev/sdb2', label: 'DOIS'),
      );
      drive = FakeDBusObject(_path('drives/usb'), _drive());
      await bus.service.registerObject(root);
      for (final object in [sdb1, sdb2, drive]) {
        await bus.service.registerObject(object);
      }
      await bus.service.requestName(_udisks);
      service = UDisks2Service(bus.shell);
      await service.ready;
    });

    tearDown(() async {
      await service.dispose();
      await bus.close();
    });

    test('lista e acompanha uma montagem', () async {
      expect(service.volumes.value.map((v) => v.label), ['DOIS', 'UM']);
      await sdb2.change('$_udisks.Filesystem', {
        'MountPoints': DBusArray(DBusSignature('ay'), [
          _text('/run/media/ana/DOIS'),
        ]),
      });
      await until(() => service.volumes.value.first.mountPoint != null);
      expect(service.volumes.value.first.mountPoint, '/run/media/ana/DOIS');
    });

    test('um disco ligado depois aparece', () async {
      await bus.service.registerObject(
        FakeDBusObject(
          _path('block_devices/sdc1'),
          _block('/dev/sdc1', label: 'NOVO'),
        ),
      );
      await until(() => service.volumes.value.length == 3);
      expect(service.volumes.value.map((v) => v.label), contains('NOVO'));
    });

    test('montar devolve o lugar', () async {
      sdb2.replies['Mount'] = [const DBusString('/run/media/ana/DOIS')];
      expect(await service.mount(sdb2.path.value), '/run/media/ana/DOIS');
      expect(sdb2.calls.single.name, 'Mount');
    });

    test('ejetar desmonta as partições do disco e desliga', () async {
      expect(await service.eject(sdb2.path.value), PsitoDiskResult.ok);
      // Só a montada recebe o Unmount, mesmo pedindo pela outra
      expect(sdb1.calls.map((c) => c.name), ['Unmount']);
      expect(sdb2.calls, isEmpty);
      expect(drive.calls.map((c) => c.name), ['PowerOff']);
    });

    test('sem poder desligar, ejeta', () async {
      await drive.change('$_udisks.Drive', {
        'CanPowerOff': const DBusBoolean(false),
        'Ejectable': const DBusBoolean(true),
      });
      expect(await service.eject(sdb2.path.value), PsitoDiskResult.ok);
      expect(drive.calls.map((c) => c.name), ['Eject']);
    });
  });

  group('respostas de erro', () {
    late DBusTestBus bus;
    late UDisks2Service service;
    late _Failing sdb1;

    setUp(() async {
      bus = await DBusTestBus.start();
      sdb1 = _Failing(
        _path('block_devices/sdb1'),
        _block('/dev/sdb1', label: 'UM', mount: '/run/media/ana/UM'),
      );
      final driveObject = FakeDBusObject(_path('drives/usb'), _drive());
      await bus.service.registerObject(
        DBusObject(DBusObjectPath(_base), isObjectManager: true),
      );
      await bus.service.registerObject(sdb1);
      await bus.service.registerObject(driveObject);
      await bus.service.requestName(_udisks);
      service = UDisks2Service(bus.shell);
      await service.ready;
    });

    tearDown(() async {
      await service.dispose();
      await bus.close();
    });

    test('ocupado vira busy, e o disco não desliga', () async {
      sdb1.error = '$_udisks.Error.DeviceBusy';
      expect(await service.unmount(sdb1.path.value), PsitoDiskResult.busy);
      expect(await service.eject(sdb1.path.value), PsitoDiskResult.busy);
    });

    test('já desmontado não é erro', () async {
      sdb1.error = '$_udisks.Error.NotMounted';
      expect(await service.unmount(sdb1.path.value), PsitoDiskResult.ok);
    });

    test('a senha errada se reconhece pelo texto', () async {
      sdb1.error = '$_udisks.Error.Failed';
      sdb1.message = 'Failed to activate device: Incorrect passphrase';
      expect(
        await service.unlock(sdb1.path.value, 'x'),
        PsitoDiskResult.wrongPassword,
      );
    });

    test('o resto é falha', () async {
      sdb1.error = '$_udisks.Error.Failed';
      expect(await service.unmount(sdb1.path.value), PsitoDiskResult.failed);
      expect(await service.mount(sdb1.path.value), isNull);
    });
  });

  group('sem o UDisks2', () {
    test('fica vazio e não trava', () async {
      final bus = await DBusTestBus.start();
      addTearDown(bus.close);
      final service = UDisks2Service(bus.shell);
      addTearDown(service.dispose);
      await service.ready;
      expect(service.volumes.value, isEmpty);
    });
  });

  test('o falso segue as mesmas regras', () async {
    final fake = FakeDisksService([
      FakeDisksService.sample,
      const PsitoVolume(
        id: 'cofre',
        label: 'COFRE',
        device: '/dev/sdc1',
        locked: true,
      ),
    ]);
    addTearDown(fake.dispose);
    expect(await fake.unlock('cofre', 'errada'), PsitoDiskResult.wrongPassword);
    expect(
      await fake.unlock('cofre', FakeDisksService.password),
      PsitoDiskResult.ok,
    );
    expect(fake.volumes.value.last.locked, isFalse);
    expect(fake.volumes.value.last.mountPoint, isNotNull);
    expect(await fake.unmount('pendrive'), PsitoDiskResult.ok);
    expect(fake.volumes.value.first.mountPoint, isNull);
    expect(await fake.eject('pendrive'), PsitoDiskResult.ok);
    expect(fake.volumes.value.map((v) => v.id), ['cofre']);
  });
}

class _Failing extends FakeDBusObject {
  String? error;
  String message = '';

  _Failing(super.path, super.interfaces);

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    final name = error;
    if (name == null) return super.handleMethodCall(call);
    return DBusMethodErrorResponse(name, [DBusString(message)]);
  }
}
