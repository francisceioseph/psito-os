import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_settings/settings_app.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/system_info_service.dart';
import 'package:psito_services/system_services.dart';
import 'package:psito_services/time_service.dart';
import 'package:system_shell/widgets/launcher.dart';
import 'package:system_shell/widgets/top_bar.dart';

import 'helpers.dart';

/// Abre Configurações pela busca do launcher, sem acento.
Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Menu'));
  await tester.pump();
  await tester.enterText(
    find.descendant(
      of: find.byType(Launcher),
      matching: find.byType(TextField),
    ),
    'configuracoes',
  );
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

final _topBarClock = find.descendant(
  of: find.byType(TopBar),
  matching: find.textContaining(RegExp(r' (AM|PM)$')),
);

class _SectionContext implements PsitoAppContext {
  @override
  final List<String> openedPaths;

  _SectionContext(this.openedPaths);

  @override
  final settings = ValueNotifier(const PsitoSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('o argumento abre as Configurações na seção pedida', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testL10nDelegates,
        supportedLocales: psitoLocales,

        home: Scaffold(
          body: SettingsView(
            appContext: _SectionContext([
              '${psitoSettingsSectionPrefix}desktop',
            ]),
          ),
        ),
      ),
    );
    expect(find.text('Mostrar os ícones'), findsOneWidget);
  });

  testWidgets('desligar 24 horas muda o relógio da top bar', (tester) async {
    final store = await pumpOS(tester);
    await _openSettings(tester);
    expect(find.text('Configurações'), findsOneWidget);

    await tester.tap(find.text('Data e hora').first);
    await tester.pump();
    expect(_topBarClock, findsNothing);

    await tester.tap(find.text('Formato 24 horas'));
    await tester.pump();
    expect(store.value.use24h, isFalse);
    expect(_topBarClock, findsOneWidget);
  });

  testWidgets('a cor de destaque muda o tema', (tester) async {
    final store = await pumpOS(tester);
    await _openSettings(tester);

    const blue = Color(0xFF2196F3);
    await tester.tap(find.byKey(ValueKey('accent-${blue.toARGB32()}')));
    expect(store.value.accent, blue);
    // O MaterialApp anima a troca de tema: um frame inicia, outro termina
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final theme = Theme.of(tester.element(find.byType(TopBar)));
    expect(theme.colorScheme.primary, blue);
  });

  testWidgets('o papel de parede muda o fundo', (tester) async {
    await pumpOS(tester);
    await _openSettings(tester);

    await tester.tap(find.byKey(const ValueKey('wallpaper-card-oceano')));
    await tester.pump();
    expect(find.byKey(const ValueKey('wallpaper-oceano')), findsOneWidget);
  });

  testWidgets('Não perturbe guarda a notificação sem toast', (tester) async {
    await pumpOS(tester);
    await _openSettings(tester);

    await tester.tap(find.text('Notificações').first);
    await tester.pump();
    await tester.tap(find.text('Não perturbe'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.access_time_rounded).first);
    await tester.pump();
    await tester.tap(find.text('Iniciar timer'));
    for (var i = 0; i < 11; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text('Timer concluído'), findsNothing);
    final bell = find.byKey(const ValueKey('notifications-bell'));
    expect(find.descendant(of: bell, matching: find.text('1')), findsOneWidget);
    expect(
      find.descendant(of: bell, matching: find.byIcon(Icons.notifications_off)),
      findsOneWidget,
    );
  });

  testWidgets('Sobre mostra o sistema e acompanha mudanças', (tester) async {
    final info = FakeSystemInfoService();
    final services = SystemServices.fake(systemInfo: info);
    addTearDown(services.dispose);
    await pumpOS(tester, services: services);
    await _openSettings(tester);
    // O item "Dock" sai da árvore ao rolar: o Scrollable fica guardado
    final sidebar = tester.widget(
      find
          .ancestor(of: find.text('Dock'), matching: find.byType(Scrollable))
          .first,
    );
    await tester.scrollUntilVisible(
      find.text('Sobre'),
      50,
      scrollable: find.byWidget(sidebar),
    );
    await tester.pump();
    await tester.tap(find.text('Sobre'));
    await tester.pump();

    expect(find.text('psito-fake'), findsOneWidget);
    expect(find.text('0.0.0-fake'), findsOneWidget);

    info.set(PsitoSystemInfo.unavailable);
    await tester.pump();
    expect(find.text('psito-fake'), findsNothing);
    expect(
      find.text('Informações do sistema indisponíveis (hostnamed)'),
      findsOneWidget,
    );
  });

  testWidgets('Data e hora: NTP e troca de fuso', (tester) async {
    final time = FakeTimeService();
    final services = SystemServices.fake(time: time);
    addTearDown(services.dispose);
    await pumpOS(tester, services: services);
    await _openSettings(tester);
    await tester.tap(find.text('Data e hora').first);
    await tester.pump();

    expect(find.text('America · Fortaleza'), findsOneWidget);
    expect(find.text('Sincronizado com a internet'), findsOneWidget);

    await tester.tap(find.text('Ajustar automaticamente'));
    await tester.pump();
    expect(time.state.value.ntp, isFalse);
    expect(find.text('Desligado'), findsOneWidget);

    await tester.tap(find.text('Alterar'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar fuso (ex.: sao paulo)'),
      'sao paulo',
    );
    await tester.pump();
    expect(find.text('Asia · Tokyo'), findsNothing);

    await tester.tap(find.text('America · Sao Paulo'));
    await tester.pump();
    expect(time.state.value.timezone, 'America/Sao_Paulo');
    expect(find.text('America · Sao Paulo'), findsOneWidget);
    expect(find.text('Alterar'), findsOneWidget);
  });

  testWidgets('Data e hora sem timedated mostra a nota', (tester) async {
    final services = SystemServices.fake(
      time: FakeTimeService(initial: PsitoTimeState.unavailable),
    );
    addTearDown(services.dispose);
    await pumpOS(tester, services: services);
    await _openSettings(tester);
    await tester.tap(find.text('Data e hora').first);
    await tester.pump();
    expect(
      find.text('Data e hora do sistema indisponíveis (timedated)'),
      findsOneWidget,
    );
  });

  testWidgets('top bar e Clock usam a hora do sistema', (tester) async {
    final fixed = DateTime(2026, 10, 30, 16, 41);
    final services = SystemServices.fake(
      time: FakeTimeService(clock: () => fixed),
    );
    addTearDown(services.dispose);
    await pumpOS(tester, services: services);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('sex., 30 de out., 16:41'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.access_time_rounded).first);
    await tester.pump();
    expect(find.text('16:41:00'), findsOneWidget);
  });

  testWidgets('Configurações abre uma janela só', (tester) async {
    await pumpOS(tester);
    await _openSettings(tester);
    await _openSettings(tester);
    expect(find.text('Configurações'), findsOneWidget);
  });

  test('formatClock em 12h e com segundos', () {
    final t = DateTime(2026, 10, 30, 16, 41, 7);
    expect(TopBar.formatClock(t, 'pt'), 'sex., 30 de out., 16:41');
    expect(
      TopBar.formatClock(t, 'pt', use24h: false, showSeconds: true),
      'sex., 30 de out., 4:41:07 PM',
    );
    expect(
      TopBar.formatClock(DateTime(2026, 10, 30, 0, 5), 'pt', use24h: false),
      'sex., 30 de out., 12:05 AM',
    );
  });
}
