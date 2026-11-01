import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_greeter/greetd_client.dart';
import 'package:psito_greeter/greeter_screen.dart';
import 'package:psito_greeter/l10n/greeter_localizations.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/session_service.dart';

/// Um greetd de mentira: a senha certa é "certa".
class FakeGreetd {
  final sent = <Map<String, Object?>>[];

  Future<Map<String, Object?>> call(Map<String, Object?> message) async {
    sent.add(message);
    switch (message['type']) {
      case 'create_session':
        return {
          'type': 'auth_message',
          'auth_message_type': 'secret',
          'auth_message': 'Password: ',
        };
      case 'post_auth_message_response':
        if (message['response'] == 'certa') return {'type': 'success'};
        if (message['response'] == 'aviso') {
          return {
            'type': 'auth_message',
            'auth_message_type': 'info',
            'auth_message': 'Conta expira logo',
          };
        }
        if (message['response'] == null) return {'type': 'success'};
        return {
          'type': 'error',
          'error_type': 'auth_error',
          'description': 'nope',
        };
    }
    return {'type': 'success'};
  }

  List<Object?> get types => [for (final m in sent) m['type']];
}

const _passwd =
    'root:x:0:0:root:/root:/bin/bash\n'
    '_greetd:x:103:106::/var/lib/greetd:/usr/sbin/nologin\n'
    'ana:x:1000:1000:Ana Souza,,,:/home/ana:/bin/bash\n'
    'bia:x:1001:1001::/home/bia:/bin/bash\n'
    'robo:x:1002:1002::/home/robo:/usr/sbin/nologin\n'
    'nobody:x:65534:65534::/nonexistent:/bin/sh\n';

void main() {
  late FakeGreetd greetd;
  late LoginFlow flow;

  setUp(() {
    greetd = FakeGreetd();
    flow = LoginFlow(
      greetd.call,
      command: const ['psito-session'],
      environment: const ['A=1'],
    );
  });

  test('só as contas de pessoas entram na lista', () {
    final users = loginUsers(_passwd);
    expect(users.map((u) => u.login), ['ana', 'bia']);
    expect(users.first.name, 'Ana Souza');
    expect(users.last.name, 'bia');
  });

  test('a senha certa abre a sessão com o comando e o ambiente', () async {
    await flow.select('ana');
    expect(flow.state, LoginState.asking);
    expect(flow.secret, isTrue);
    await flow.answer('certa');
    expect(flow.state, LoginState.started);
    expect(greetd.sent.last, {
      'type': 'start_session',
      'cmd': ['psito-session'],
      'env': ['A=1'],
    });
  });

  test('a senha errada refaz a sessão e continua perguntando', () async {
    await flow.select('ana');
    await flow.answer('errada');
    expect(flow.state, LoginState.wrong);
    expect(greetd.types, [
      'create_session',
      'post_auth_message_response',
      'cancel_session',
      'create_session',
    ]);
    await flow.answer('certa');
    expect(flow.state, LoginState.started);
  });

  test('um aviso do PAM segue sem resposta', () async {
    await flow.select('ana');
    await flow.answer('aviso');
    expect(flow.detail, 'Conta expira logo');
    expect(flow.state, LoginState.started);
    expect(greetd.sent[2]['response'], isNull);
  });

  test('trocar de conta cancela a sessão aberta', () async {
    await flow.select('ana');
    await flow.cancel();
    expect(flow.user, isNull);
    expect(greetd.types.last, 'cancel_session');
  });

  test('o protocolo: tamanho e JSON, mesmo em pedaços', () async {
    final dir = Directory.systemTemp.createTempSync('psito_greetd');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/sock';
    final server = await ServerSocket.bind(
      InternetAddress(path, type: InternetAddressType.unix),
      0,
    );
    addTearDown(server.close);
    final received = <int>[];
    server.listen((socket) {
      socket.listen((data) async {
        received.addAll(data);
        final body = utf8.encode('{"type":"success"}');
        final size = ByteData(4)..setUint32(0, body.length, Endian.host);
        final reply = [...size.buffer.asUint8List(), ...body];
        // Em dois pedaços, como um socket pode entregar
        socket.add(reply.sublist(0, 6));
        await socket.flush();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        socket.add(reply.sublist(6));
      });
    });
    final client = await GreetdClient.connect(path);
    final reply = await client.request({'type': 'cancel_session'});
    expect(reply, {'type': 'success'});
    final sent = Uint8List.fromList(received);
    final size = ByteData.sublistView(sent, 0, 4).getUint32(0, Endian.host);
    expect(jsonDecode(utf8.decode(sent.sublist(4))), {
      'type': 'cancel_session',
    });
    expect(size, sent.length - 4);
    await client.close();
  });

  Future<void> pump(WidgetTester tester, List<LoginUser> users) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: psitoTheme(PsitoSettings.defaults.accent),
        localizationsDelegates: psitoLocalizationsDelegates(const [
          GreeterLocalizations.delegate,
        ]),
        supportedLocales: psitoLocales,
        home: GreeterScreen(
          flow: flow,
          users: users,
          session: FakeSessionService(),
          now: () => DateTime(2026, 11, 1, 13, 30),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pump();
  }

  final field = find.byKey(const ValueKey('greeter-password'));
  const ana = LoginUser('ana', 'Ana Souza');
  const bia = LoginUser('bia', 'bia');

  testWidgets('com uma conta só, já pede a senha', (tester) async {
    await pump(tester, const [ana]);
    await tester.pump();
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(field, findsOneWidget);
  });

  testWidgets('com várias, escolhe e pode voltar', (tester) async {
    await pump(tester, const [ana, bia]);
    expect(field, findsNothing);
    await tester.tap(find.text('bia'));
    await tester.pump();
    await tester.pump();
    expect(field, findsOneWidget);
    await tester.tap(find.text('Escolher outro usuário'));
    await tester.pump();
    await tester.pump();
    expect(field, findsNothing);
    expect(find.text('Ana Souza'), findsOneWidget);
  });

  testWidgets('a senha errada avisa, limpa e mantém o foco', (tester) async {
    await pump(tester, const [ana]);
    await tester.pump();
    await tester.enterText(field, 'errada');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(find.text('Senha incorreta.'), findsOneWidget);
    final text = tester.widget<TextField>(field);
    expect(text.controller!.text, isEmpty);
    expect(text.focusNode!.hasFocus, isTrue);
  });
}
