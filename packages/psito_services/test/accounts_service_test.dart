import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_services/accounts_service.dart';

import 'dbus_test_bus.dart';

class _Manager extends DBusObject {
  final calls = <DBusMethodCall>[];
  bool refuse = false;

  _Manager() : super(DBusObjectPath(AccountsdService.path));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    calls.add(methodCall);
    if (refuse && methodCall.name != 'ListCachedUsers') {
      return DBusMethodErrorResponse(
        'org.freedesktop.Accounts.Error.PermissionDenied',
      );
    }
    return switch (methodCall.name) {
      'ListCachedUsers' => DBusMethodSuccessResponse([
        DBusArray.objectPath([
          DBusObjectPath('${AccountsdService.path}/User1000'),
          DBusObjectPath('${AccountsdService.path}/User998'),
        ]),
      ]),
      'FindUserById' => DBusMethodSuccessResponse([
        DBusObjectPath('${AccountsdService.path}/User1000'),
      ]),
      'CreateUser' => DBusMethodSuccessResponse([
        DBusObjectPath('${AccountsdService.path}/User1000'),
      ]),
      _ => DBusMethodSuccessResponse(),
    };
  }
}

FakeDBusObject _user(int uid, String login, {bool system = false}) {
  final object = FakeDBusObject.single(
    DBusObjectPath('${AccountsdService.path}/User$uid'),
    AccountsdService.userInterface,
    {
      'Uid': DBusUint64(uid),
      'UserName': DBusString(login),
      'RealName': DBusString('Nome de $login'),
      'AccountType': const DBusInt32(1),
      'SystemAccount': DBusBoolean(system),
    },
  );
  return object;
}

void main() {
  late DBusTestBus bus;
  late AccountsdService service;
  late _Manager manager;
  late FakeDBusObject ana;

  setUp(() async {
    bus = await DBusTestBus.start();
    manager = _Manager();
    ana = _user(1000, 'ana');
    await bus.publish(AccountsdService.busName, manager);
    await bus.publish(AccountsdService.busName, ana);
    await bus.publish(
      AccountsdService.busName,
      _user(998, 'sistema', system: true),
    );
    service = AccountsdService(
      bus.shell,
      me: 'ana',
      hash: (password) async => 'hash-de-$password',
    );
    await service.ready;
  });
  tearDown(() async {
    await service.dispose();
    await bus.close();
  });

  test('lista as contas, sem as de sistema', () {
    final users = service.users.value;
    expect(users.map((u) => u.login), ['ana']);
    expect(users.single.uid, 1000);
    expect(users.single.name, 'Nome de ana');
    expect(users.single.isAdmin, isTrue);
    expect(users.single.isCurrent, isTrue);
  });

  test('a senha vai como hash, nunca como veio', () async {
    expect(await service.setPassword(1000, 'segredo'), isTrue);
    final call = ana.calls.single;
    expect(call.name, 'SetPassword');
    expect(call.values.first, const DBusString('hash-de-segredo'));
  });

  test('criar passa o tipo e já põe a senha', () async {
    expect(
      await service.create(
        login: 'bia',
        name: 'Bia',
        admin: false,
        password: 'segredo',
      ),
      isTrue,
    );
    final create = manager.calls.firstWhere((c) => c.name == 'CreateUser');
    expect(create.values, [
      const DBusString('bia'),
      const DBusString('Bia'),
      const DBusInt32(0),
    ]);
    expect(ana.calls.single.name, 'SetPassword');
  });

  test('apagar leva os arquivos junto', () async {
    await service.delete(1000);
    final call = manager.calls.firstWhere((c) => c.name == 'DeleteUser');
    expect(call.values, [const DBusInt64(1000), const DBusBoolean(true)]);
  });

  test('uma recusa do polkit vira false', () async {
    manager.refuse = true;
    expect(await service.delete(1000), isFalse);
  });

  test('sem conseguir o hash, nada é pedido', () async {
    final noHash = AccountsdService(bus.shell, hash: (_) async => null);
    await noHash.ready;
    addTearDown(noHash.dispose);
    expect(await noHash.setPassword(1000, 'segredo'), isFalse);
    expect(ana.calls, isEmpty);
  });

  test('o hash sai no formato do shadow', () async {
    final hashed = await hashPassword('segredo');
    expect(hashed, startsWith(r'$6$'));
    expect(hashed, isNot(contains('segredo')));
  });
}
