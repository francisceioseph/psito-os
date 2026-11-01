import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_psito/hello_app.dart';
import 'package:psito_sdk/psito_sdk.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Future<String?> Function()? probe,
    VoidCallback? onCrash,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: psitoLocalizationsDelegates(
        const HelloApp().localizationsDelegates,
      ),
      supportedLocales: psitoLocales,

      home: Scaffold(
        body: HelloView(
          network: ValueNotifier(PsitoNetworkState.unavailable),
          probe: probe ?? () async => null,
          onCrash: onCrash ?? () {},
        ),
      ),
    ),
  );

  testWidgets('cabe em 240x160', (tester) async {
    tester.view.physicalSize = const Size(240, 160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Rede indisponível para o app'), findsOneWidget);
  });

  testWidgets('o teste de conexão mostra o resultado', (tester) async {
    await pump(tester, probe: () async => 'Network is unreachable');
    await tester.tap(find.text('Testar conexão'));
    await tester.pump();
    expect(find.text('Sem conexão: Network is unreachable'), findsOneWidget);
  });

  testWidgets('sair com erro chama quem sai', (tester) async {
    var crashed = false;
    await pump(tester, onCrash: () => crashed = true);
    await tester.tap(find.text('Sair com erro'));
    expect(crashed, isTrue);
  });
}
