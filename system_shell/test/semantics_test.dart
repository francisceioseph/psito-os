// Quem usa um leitor de tela só acha o que tem nome: um clique feito à mão com
// um ícone dentro é invisível para ele. Cada superfície passa por aqui, como os
// textos pelo `l10n_boundary_test` e as cores pelo `theme_boundary_test`.
//
// Um clique sem nome se resolve com `Semantics(label:)` ou um `Tooltip`. O que
// não é um controle (clicar fora para fechar, arrastar a moldura) leva o
// `excludeFromSemantics: true`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/battery_service.dart';
import 'package:psito_services/system_services.dart';
import 'package:system_shell/shell/app_registry.dart';
import 'package:system_shell/widgets/psito_window.dart';

import 'helpers.dart';

ValueKey<String> _key(String name) => ValueKey(name);

void main() {
  Future<void> openApp(WidgetTester tester, PsitoApp app) async {
    await pumpOS(tester);
    await tester.pump();
    await tester.tap(find.byIcon(app.icon).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final wm = tester.widget<PsitoWindow>(find.byType(PsitoWindow)).manager;
    wm.toggleMaximize(wm.focusedId!);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a área de trabalho', (tester) async {
    await pumpOS(tester);
    await tester.pump();
    await expectAllLabeled(tester);
  });

  testWidgets('o launcher', (tester) async {
    await pumpOS(tester);
    await tester.pump();
    await tester.tap(find.text('Menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectAllLabeled(tester);
  });

  for (final panel in [
    'notifications-bell',
    'network-indicator',
    'volume-indicator',
    'power-button',
  ]) {
    testWidgets('o painel de $panel', (tester) async {
      await pumpOS(tester);
      await tester.pump();
      await tester.tap(find.byKey(_key(panel)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await expectAllLabeled(tester);
    });
  }

  testWidgets('o painel da bateria', (tester) async {
    final services = SystemServices.fake(
      battery: FakeBatteryService(
        const BatteryState(available: true, present: true, percentage: 40),
      ),
    );
    addTearDown(services.dispose);
    await pumpOS(tester, services: services);
    await tester.pump();
    await tester.tap(find.byKey(_key('battery-indicator')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectAllLabeled(tester);
  });

  for (final mode in [Icons.view_list_rounded, Icons.view_column_rounded]) {
    testWidgets('o Files no modo $mode', (tester) async {
      await openApp(tester, registeredApps.firstWhere((a) => a.id == 'files'));
      await tester.tap(find.byIcon(mode));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await expectAllLabeled(tester);
    });
  }

  for (final app in registeredApps) {
    testWidgets('a janela de ${app.name}', (tester) async {
      await openApp(tester, app);
      await expectAllLabeled(tester);
    });
  }

  for (final section in [
    'Dock',
    'Área de trabalho',
    'Data e hora',
    'Rede',
    'Notificações',
    'Energia',
    'Atalhos',
    'Usuários',
    'Privacidade',
    'Idioma',
  ]) {
    testWidgets('a seção $section das Configurações', (tester) async {
      await openApp(
        tester,
        registeredApps.firstWhere((a) => a.id == 'settings'),
      );
      await tester.tap(find.widgetWithText(ListTile, section).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await expectAllLabeled(tester);
    });
  }
}
