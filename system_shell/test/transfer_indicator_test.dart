import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/widgets/top_bar.dart';
import 'package:system_shell/widgets/transfer_indicator.dart';

import 'helpers.dart';

import 'package:psito_sdk/psito_sdk.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    TransferStatus? status,
    VoidCallback? onCancel,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: testL10nDelegates,
      supportedLocales: psitoLocales,

      home: Scaffold(
        body: TopBar(transfer: status, onCancelTransfer: onCancel),
      ),
    ),
  );

  testWidgets('sem trabalho, não aparece', (tester) async {
    await pump(tester);
    expect(find.byType(TransferIndicator), findsNothing);
  });

  testWidgets('mostra o andamento, e o X cancela', (tester) async {
    var cancelled = 0;
    await pump(
      tester,
      status: const TransferStatus('Copiando "a.txt"', 0.25),
      onCancel: () => cancelled++,
    );
    expect(find.text('Copiando "a.txt"'), findsOneWidget);
    await expectAllLabeled(tester);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      0.25,
    );
    await tester.tap(find.byKey(const ValueKey('transfer-cancel')));
    await tester.pump();
    expect(cancelled, 1);
  });
}
