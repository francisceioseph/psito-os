// packages/psito_services/lib/accounts_service.dart
//
// As contas de usuário pelo AccountsService no D-Bus. Quase tudo pede a senha
// de administrador, e quem pergunta é o agente do polkit no shell.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';

class AccountsdService implements PsitoAccounts {
  static const busName = 'org.freedesktop.Accounts';
  static const path = '/org/freedesktop/Accounts';
  static const interface = 'org.freedesktop.Accounts';
  static const userInterface = 'org.freedesktop.Accounts.User';

  final DBusClient _bus;
  final String _me;
  final Future<String?> Function(String password) _hash;
  late final DBusRemoteObject _manager = DBusRemoteObject(
    _bus,
    name: busName,
    path: DBusObjectPath(path),
  );
  final _subscriptions = <StreamSubscription<DBusSignal>>[];

  final _users = ValueNotifier<List<PsitoUserAccount>>(const []);

  @override
  ValueListenable<List<PsitoUserAccount>> get users => _users;

  late final Future<void> ready;

  AccountsdService(
    this._bus, {
    String? me,
    Future<String?> Function(String password)? hash,
  }) : _me = me ?? Platform.environment['USER'] ?? '',
       _hash = hash ?? hashPassword {
    for (final signal in ['UserAdded', 'UserDeleted']) {
      _subscriptions.add(
        DBusRemoteObjectSignalStream(
          object: _manager,
          interface: interface,
          name: signal,
        ).listen((_) => unawaited(_load())),
      );
    }
    ready = _load();
  }

  Future<void> _load() async {
    try {
      final reply = await _manager.callMethod(
        interface,
        'ListCachedUsers',
        [],
        replySignature: DBusSignature('ao'),
      );
      final found = <PsitoUserAccount>[];
      for (final path in reply.values.first.asObjectPathArray()) {
        final props = await _user(path).getAllProperties(userInterface);
        if (props['SystemAccount']?.asBoolean() ?? false) continue;
        final login = props['UserName']!.asString();
        found.add(
          PsitoUserAccount(
            uid: props['Uid']!.asUint64(),
            login: login,
            name: props['RealName']!.asString(),
            isAdmin: props['AccountType']!.asInt32() == 1,
            isCurrent: login == _me,
          ),
        );
      }
      found.sort((a, b) => a.uid.compareTo(b.uid));
      _users.value = found;
    } catch (e) {
      debugPrint('🦜 Erro lendo as contas: $e');
    }
  }

  DBusRemoteObject _user(DBusObjectPath path) =>
      DBusRemoteObject(_bus, name: busName, path: path);

  Future<DBusObjectPath> _find(int uid) async {
    final reply = await _manager.callMethod(interface, 'FindUserById', [
      DBusInt64(uid),
    ], replySignature: DBusSignature('o'));
    return reply.values.first.asObjectPath();
  }

  /// Uma recusa, ou o diálogo de senha cancelado, viram false.
  Future<bool> _try(String what, Future<void> Function() action) async {
    try {
      await action();
      await _load();
      return true;
    } catch (e) {
      debugPrint('🦜 Erro em $what: $e');
      return false;
    }
  }

  Future<void> _setPassword(DBusObjectPath user, String password) async {
    final hashed = await _hash(password);
    if (hashed == null) throw StateError('sem o hash da senha');
    await _user(user).callMethod(
      userInterface,
      'SetPassword',
      [DBusString(hashed), const DBusString('')],
      replySignature: DBusSignature(''),
      allowInteractiveAuthorization: true,
    );
  }

  @override
  Future<bool> setName(int uid, String name) => _try('mudar o nome', () async {
    await _user(await _find(uid)).callMethod(
      userInterface,
      'SetRealName',
      [DBusString(name)],
      replySignature: DBusSignature(''),
      allowInteractiveAuthorization: true,
    );
  });

  @override
  Future<bool> setPassword(int uid, String password) => _try(
    'mudar a senha',
    () async => _setPassword(await _find(uid), password),
  );

  @override
  Future<bool> create({
    required String login,
    required String name,
    required bool admin,
    required String password,
  }) => _try('criar a conta', () async {
    final reply = await _manager.callMethod(
      interface,
      'CreateUser',
      [DBusString(login), DBusString(name), DBusInt32(admin ? 1 : 0)],
      replySignature: DBusSignature('o'),
      allowInteractiveAuthorization: true,
    );
    await _setPassword(reply.values.first.asObjectPath(), password);
  });

  @override
  Future<bool> delete(int uid) => _try('apagar a conta', () async {
    await _manager.callMethod(
      interface,
      'DeleteUser',
      [DBusInt64(uid), const DBusBoolean(true)],
      replySignature: DBusSignature(''),
      allowInteractiveAuthorization: true,
    );
  });

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _users.dispose();
  }
}

/// O hash no formato do `/etc/shadow`, que é o que o AccountsService recebe. A
/// senha vai pela entrada, e não na linha de comando, que qualquer um lê.
Future<String?> hashPassword(String password) async {
  try {
    final process = await Process.start('openssl', ['passwd', '-6', '-stdin']);
    process.stdin.writeln(password);
    await process.stdin.close();
    final output = await process.stdout.transform(utf8.decoder).join();
    unawaited(process.stderr.drain<void>());
    if (await process.exitCode != 0) return null;
    return output.trim();
  } on ProcessException catch (e) {
    debugPrint('🦜 Sem o openssl: $e');
    return null;
  }
}

/// Para o laboratório e os testes: sem barramento, e guarda o que foi pedido.
class FakeAccountsService implements PsitoAccounts {
  @override
  final ValueNotifier<List<PsitoUserAccount>> users;

  /// O que as próximas ações respondem: false é o diálogo cancelado.
  bool answer = true;
  final passwords = <int, String>{};

  FakeAccountsService([List<PsitoUserAccount>? initial])
    : users = ValueNotifier(
        initial ??
            const [
              PsitoUserAccount(
                uid: 1000,
                login: 'ana',
                name: 'Ana',
                isAdmin: true,
                isCurrent: true,
              ),
            ],
      );

  @override
  Future<bool> setName(int uid, String name) async {
    if (!answer) return false;
    users.value = [
      for (final user in users.value)
        user.uid == uid ? user.copyWith(name: name) : user,
    ];
    return true;
  }

  @override
  Future<bool> setPassword(int uid, String password) async {
    if (answer) passwords[uid] = password;
    return answer;
  }

  @override
  Future<bool> create({
    required String login,
    required String name,
    required bool admin,
    required String password,
  }) async {
    if (!answer) return false;
    final uid = users.value.last.uid + 1;
    passwords[uid] = password;
    users.value = [
      ...users.value,
      PsitoUserAccount(uid: uid, login: login, name: name, isAdmin: admin),
    ];
    return true;
  }

  @override
  Future<bool> delete(int uid) async {
    if (!answer) return false;
    users.value = [
      for (final user in users.value)
        if (user.uid != uid) user,
    ];
    return true;
  }
}
