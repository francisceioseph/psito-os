import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/accounts_service.dart';
import 'package:psito_settings/l10n/settings_localizations.dart';
import 'package:psito_settings/users_section.dart';

const _ana = PsitoUserAccount(
  uid: 1000,
  login: 'ana',
  name: 'Ana',
  isAdmin: true,
  isCurrent: true,
);
const _bia = PsitoUserAccount(uid: 1001, login: 'bia', name: 'Bia');

void main() {
  late FakeAccountsService accounts;

  setUp(() => accounts = FakeAccountsService(const [_ana, _bia]));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: psitoTheme(PsitoSettings.defaults.accent),
        localizationsDelegates: psitoLocalizationsDelegates(const [
          SettingsLocalizations.delegate,
        ]),
        supportedLocales: psitoLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: UsersSection(accounts: accounts)),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> enter(WidgetTester tester, String key, String text) =>
      tester.enterText(find.byKey(ValueKey(key)), text);

  test('o login segue o que o useradd aceita', () {
    expect(isValidLogin('ana'), isTrue);
    expect(isValidLogin('ana-maria_2'), isTrue);
    expect(isValidLogin(''), isFalse);
    expect(isValidLogin('Ana'), isFalse);
    expect(isValidLogin('2ana'), isFalse);
    expect(isValidLogin('ana maria'), isFalse);
    expect(isValidLogin('a' * 33), isFalse);
  });

  testWidgets('sem contas, diz que não há a lista', (tester) async {
    accounts = FakeAccountsService(const []);
    await pump(tester);
    expect(
      find.text('A lista de usuários não está disponível.'),
      findsOneWidget,
    );
  });

  testWidgets('a própria conta não tem o apagar', (tester) async {
    await pump(tester);
    expect(find.text('ana · Administrador · você'), findsOneWidget);
    expect(find.text('bia · Padrão'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('user-ana')));
    await tester.pump();
    expect(find.text('Apagar a conta'), findsNothing);
  });

  testWidgets('mudar o nome e a senha', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('user-bia')));
    await tester.pump();
    await enter(tester, 'user-name', 'Beatriz');
    await tester.tap(find.text('Salvar o nome'));
    await tester.pump();
    expect(find.text('Beatriz'), findsWidgets);

    await enter(tester, 'user-password', 'um');
    await enter(tester, 'user-confirm', 'dois');
    await tester.tap(find.text('Mudar a senha'));
    await tester.pump();
    expect(find.text('As senhas não são iguais.'), findsOneWidget);
    expect(accounts.passwords, isEmpty);

    await enter(tester, 'user-confirm', 'um');
    await tester.tap(find.text('Mudar a senha'));
    await tester.pump();
    await tester.pump();
    expect(accounts.passwords, {1001: 'um'});
    expect(find.text('Salvo.'), findsOneWidget);
  });

  testWidgets('cancelar o diálogo de senha vira um aviso', (tester) async {
    accounts.answer = false;
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('user-bia')));
    await tester.pump();
    await tester.tap(find.text('Salvar o nome'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Não deu certo, ou foi cancelado.'), findsOneWidget);
  });

  testWidgets('apagar pergunta antes', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('user-bia')));
    await tester.pump();
    await tester.tap(find.text('Apagar a conta'));
    await tester.pump();
    expect(
      find.text('Apagar bia e todos os arquivos da conta?'),
      findsOneWidget,
    );
    expect(accounts.users.value, hasLength(2));
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar a conta'));
    await tester.pump();
    await tester.pump();
    expect(accounts.users.value.map((u) => u.login), ['ana']);
  });

  testWidgets('criar confere o login e a senha', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Adicionar usuário'));
    await tester.pump();
    await enter(tester, 'new-login', 'Nome Errado');
    await enter(tester, 'new-password', 'segredo');
    await enter(tester, 'new-confirm', 'segredo');
    await tester.tap(find.text('Criar a conta'));
    await tester.pump();
    expect(
      find.text(
        'Use letras minúsculas, números, - e _, começando com uma letra.',
      ),
      findsOneWidget,
    );
    expect(accounts.users.value, hasLength(2));

    await enter(tester, 'new-login', 'cida');
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('Criar a conta'));
    await tester.pump();
    await tester.pump();
    final created = accounts.users.value.last;
    expect(created.login, 'cida');
    expect(created.name, 'cida');
    expect(created.isAdmin, isTrue);
    expect(accounts.passwords[created.uid], 'segredo');
    expect(find.text('Criar a conta'), findsNothing);
  });
}
