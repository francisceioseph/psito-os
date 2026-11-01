import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_lock/l10n/lock_localizations.dart';
import 'package:psito_lock/lock_screen.dart';
import 'package:psito_lock/main.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/session_service.dart';

void main() {
  late List<String> tried;
  late bool answer;

  setUp(() {
    tried = [];
    answer = false;
  });

  Future<void> pump(WidgetTester tester, {SessionService? session}) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: psitoLocalizationsDelegates(const [
          LockLocalizations.delegate,
        ]),
        supportedLocales: psitoLocales,
        home: LockScreen(
          settings: PsitoSettings.defaults,
          userName: 'Ana',
          session: session ?? FakeSessionService(),
          authenticate: (password) async {
            tried.add(password);
            return answer;
          },
        ),
      ),
    );
    // Sem isto, o relógio fica correndo depois do teste
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  final field = find.byKey(const ValueKey('lock-password'));

  Future<void> submit(WidgetTester tester, String password) async {
    await tester.enterText(field, password);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
  }

  test('a espera cresce com os erros', () {
    expect(lockDelay(1), Duration.zero);
    expect(lockDelay(2), Duration.zero);
    expect(lockDelay(3), const Duration(seconds: 5));
    expect(lockDelay(5), const Duration(seconds: 30));
    expect(lockDelay(50), const Duration(minutes: 1));
  });

  test('o nome sai do /etc/passwd, ou fica o login', () {
    const passwd =
        'ana:x:1000:1000:Ana Souza,,,:/home/ana:/bin/bash\n'
        'bia:x:1001:1001::/home/bia:/bin/bash\n';
    expect(displayName('ana', passwd), 'Ana Souza');
    expect(displayName('bia', passwd), 'bia');
    expect(displayName('cida', passwd), 'cida');
  });

  testWidgets('a senha vazia nem é conferida', (tester) async {
    await pump(tester);
    await submit(tester, '');
    expect(tried, isEmpty);
  });

  testWidgets('a senha errada avisa e limpa o campo', (tester) async {
    await pump(tester);
    await submit(tester, 'errada');
    expect(tried, ['errada']);
    expect(find.text('Senha incorreta.'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
  });

  testWidgets('depois de muitos erros, o campo espera', (tester) async {
    await pump(tester);
    for (var i = 0; i < 3; i++) {
      await submit(tester, 'errada');
    }
    expect(find.textContaining('Tente de novo em'), findsOneWidget);
    final waiting = tester.widget<TextField>(field);
    expect(waiting.readOnly, isTrue);
    expect(waiting.focusNode!.hasFocus, isTrue);
  });

  testWidgets('sem permissão, os botões de energia somem', (tester) async {
    await pump(tester, session: FakeSessionService(SessionCapabilities.none));
    expect(find.byIcon(Icons.power_settings_new), findsNothing);
    expect(find.byIcon(Icons.bedtime_outlined), findsNothing);
  });

  testWidgets('apagar a tela não deixa timer para trás', (tester) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
