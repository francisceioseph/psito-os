import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_shell/l10n/shell_localizations.dart';
import 'package:psito_shell/polkit_agent.dart';
import 'package:psito_shell/polkit_dialog.dart';

const _passwd =
    'root:x:0:0:root:/root:/bin/bash\n'
    'ana:x:1000:1000::/home/ana:/bin/bash\n'
    'bia:x:1001:1001::/home/bia:/bin/bash\n';

/// Um helper de verdade em processo, com o protocolo do polkit: a senha certa
/// é "certa", e o log guarda o cookie e o usuário de cada subida.
const _helperScript = r'''#!/bin/bash
read -r cookie
echo "$1 $cookie" >> "$(dirname "$0")/calls"
echo "PAM_PROMPT_ECHO_OFF Senha: "
read -r password
if [ "$password" = certa ]; then echo SUCCESS; else
  echo "PAM_ERROR_MSG nope"; echo FAILURE; fi
''';

const _brokenHelper = '#!/bin/bash\nread -r cookie\necho FAILURE\n';

void main() {
  late Directory dir;

  String helper([String script = _helperScript]) {
    final file = File('${dir.path}/helper')..writeAsStringSync(script);
    Process.runSync('chmod', ['+x', file.path]);
    return file.path;
  }

  setUp(() => dir = Directory.systemTemp.createTempSync('psito_polkit'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> promptOf(PolkitRequest request) async {
    while (request.prompt == null) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  DBusMethodCall begin(
    String cookie,
    List<int> uids, {
    String sender = ':1.1',
  }) => DBusMethodCall(
    sender: sender,
    interface: polkitAgentInterface,
    name: 'BeginAuthentication',
    values: [
      const DBusString('org.example.action'),
      const DBusString('Mudar o fuso'),
      const DBusString(''),
      DBusDict(DBusSignature('s'), DBusSignature('s'), const {}),
      DBusString(cookie),
      DBusArray(DBusSignature('(sa{sv})'), [
        for (final uid in uids)
          DBusStruct([
            const DBusString('unix-user'),
            DBusDict.stringVariant({'uid': DBusUint32(uid)}),
          ]),
      ]),
    ],
  );

  PolkitAgent agent0(String helperPath) =>
      PolkitAgent(passwd: () => _passwd, me: 'ana', helper: helperPath)
        ..isAuthority = (sender) async => sender == ':1.1';

  test('a conta é a de quem está na sessão, ou a primeira', () {
    expect(pickPolkitUser([0, 1000], _passwd, 'ana'), 'ana');
    expect(pickPolkitUser([1001, 0], _passwd, 'ana'), 'bia');
    expect(pickPolkitUser([4242], _passwd, 'ana'), isNull);
  });

  test('a língua do polkitd segue a do Psito', () {
    expect(polkitLocale('pt', 'en_US.UTF-8'), 'pt_BR.UTF-8');
    expect(polkitLocale('', 'de_DE.UTF-8'), 'de_DE.UTF-8');
    expect(polkitLocale('', ''), 'C');
  });

  test('senha errada sobe outro helper, e a certa conclui', () async {
    final agent = agent0(helper());
    final reply = agent.handleMethodCall(begin('c1', [1000]));
    await Future<void>.delayed(Duration.zero);
    final request = agent.current.value!;
    expect(request.user, 'ana');
    expect(request.message, 'Mudar o fuso');
    await promptOf(request);
    request.answer('errada');
    expect(request.prompt, isNull);
    while (!request.wrong || request.prompt == null) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    request.answer('certa');
    expect(await reply, isA<DBusMethodSuccessResponse>());
    expect(agent.current.value, isNull);
    expect(File('${dir.path}/calls').readAsLinesSync(), ['ana c1', 'ana c1']);
  });

  test('só o polkitd pede senha', () async {
    final agent = agent0(helper());
    final reply = await agent.handleMethodCall(
      begin('c1', [1000], sender: ':1.99'),
    );
    expect(
      (reply as DBusMethodErrorResponse).errorName,
      'org.freedesktop.DBus.Error.AccessDenied',
    );
    expect(agent.current.value, isNull);
  });

  test('um pedido por vez, e o seguinte aparece depois', () async {
    final agent = agent0(helper());
    final first = agent.handleMethodCall(begin('c1', [1000]));
    await Future<void>.delayed(Duration.zero);
    final second = agent.handleMethodCall(begin('c2', [1000]));
    await Future<void>.delayed(Duration.zero);
    expect(agent.current.value!.cookie, 'c1');
    agent.current.value!.cancel();
    final cancelled = await first;
    expect(cancelled, isA<DBusMethodErrorResponse>());
    expect(
      (cancelled as DBusMethodErrorResponse).errorName,
      'org.freedesktop.PolicyKit1.Error.Cancelled',
    );
    expect(agent.current.value!.cookie, 'c2');
    agent.cancelAll();
    await second;
    expect(agent.current.value, isNull);
  });

  test('o polkitd pode cancelar', () async {
    final agent = agent0(helper());
    final reply = agent.handleMethodCall(begin('c1', [1000]));
    await Future<void>.delayed(Duration.zero);
    await agent.handleMethodCall(
      DBusMethodCall(
        sender: ':1.1',
        interface: polkitAgentInterface,
        name: 'CancelAuthentication',
        values: const [DBusString('c1')],
      ),
    );
    expect(await reply, isA<DBusMethodErrorResponse>());
  });

  test('um helper que falha sem perguntar não sobe para sempre', () async {
    final agent = agent0(helper(_brokenHelper));
    final reply = await agent.handleMethodCall(begin('c1', [1000]));
    expect(reply, isA<DBusMethodErrorResponse>());
  });

  testWidgets('o diálogo mostra o pedido e leva a senha', (tester) async {
    final request = PolkitRequest(
      message: 'Mudar o fuso',
      user: 'ana',
      cookie: 'c1',
    );
    final l10n = lookupShellLocalizations(const Locale('pt'));
    await tester.pumpWidget(
      MaterialApp(
        theme: psitoTheme(PsitoSettings.defaults.accent),
        home: Scaffold(
          body: PolkitDialog(request: request, l10n: l10n),
        ),
      ),
    );
    expect(find.text('Mudar o fuso'), findsOneWidget);
    expect(find.text('Senha de ana'), findsOneWidget);
    final field = find.byKey(const ValueKey('polkit-password'));
    expect(tester.widget<TextField>(field).readOnly, isTrue);
    request.prompt = 'Senha:';
    request.wrong = true;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    request.notifyListeners();
    await tester.pump();
    expect(find.text('Senha incorreta.'), findsOneWidget);
    expect(tester.widget<TextField>(field).readOnly, isFalse);
  });
}
