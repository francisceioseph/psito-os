import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_shell/displays.dart';
import 'package:psito_shell/displays_confirm_dialog.dart';
import 'package:psito_shell/l10n/shell_localizations.dart';

void main() {
  final l = lookupShellLocalizations(const Locale('pt'));
  late int kept;
  late int reverted;
  late DisplaysConfirm request;

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: psitoTheme(PsitoSettings.defaults.accent),
      home: Scaffold(
        body: DisplaysConfirmDialog(request: request, l10n: l),
      ),
    ),
  );

  setUp(() {
    kept = reverted = 0;
    request = DisplaysConfirm(keep: () => kept++, revert: () => reverted++);
  });

  testWidgets('conta o tempo e mantém no botão', (tester) async {
    await pump(tester);
    expect(find.text(l.displaysConfirmBody(15)), findsOneWidget);
    request.tick();
    await tester.pump();
    expect(find.text(l.displaysConfirmBody(14)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('displays-keep')));
    expect(kept, 1);
    expect(reverted, 0);
  });

  testWidgets('o foco começa em voltar, e o Enter não mantém', (tester) async {
    await pump(tester);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(kept, 0);
    expect(reverted, 1);
  });

  testWidgets('o Esc volta', (tester) async {
    await pump(tester);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(reverted, 1);
  });
}
