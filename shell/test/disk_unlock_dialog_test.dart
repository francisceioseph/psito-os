import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/disks_service.dart';
import 'package:psito_shell/disk_unlock_dialog.dart';
import 'package:psito_shell/l10n/shell_localizations.dart';

void main() {
  final l10n = lookupShellLocalizations(const Locale('pt'));

  DiskUnlockRequest request(
    Future<DiskUnlockResult> Function(String password) attempt,
  ) => DiskUnlockRequest(id: 'a', name: 'COFRE', attempt: attempt);

  Future<void> pump(WidgetTester tester, DiskUnlockRequest request) =>
      tester.pumpWidget(
        MaterialApp(
          theme: psitoTheme(PsitoSettings.defaults.accent),
          home: Scaffold(
            body: DiskUnlockDialog(request: request, l10n: l10n),
          ),
        ),
      );

  Finder field() => find.byKey(const ValueKey('disk-password'));

  testWidgets('a senha errada avisa e fica no campo', (tester) async {
    final tried = <String>[];
    final req = request((password) async {
      tried.add(password);
      return (result: PsitoDiskResult.wrongPassword, mountPoint: null);
    });
    await pump(tester, req);
    expect(find.text(l10n.diskUnlockTitle('COFRE')), findsOneWidget);

    await tester.enterText(field(), 'errada');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(tried, ['errada']);
    expect(find.text(l10n.diskUnlockWrong), findsOneWidget);
    expect(tester.widget<TextField>(field()).controller!.text, 'errada');
  });

  testWidgets('a senha certa devolve onde montou', (tester) async {
    final req = request(
      (_) async => (result: PsitoDiskResult.ok, mountPoint: '/media/ana/a'),
    );
    await pump(tester, req);
    await tester.enterText(field(), 'certa');
    await tester.tap(find.text(l10n.diskUnlockAction));
    await tester.pump();
    expect(await req.done, '/media/ana/a');
  });

  testWidgets('um campo vazio nem tenta', (tester) async {
    var tries = 0;
    final req = request((_) async {
      tries++;
      return (result: PsitoDiskResult.ok, mountPoint: '/m');
    });
    await pump(tester, req);
    await tester.tap(find.text(l10n.diskUnlockAction));
    await tester.pump();
    expect(tries, 0);
  });

  testWidgets('o disco que não abre encerra o pedido', (tester) async {
    final req = request(
      (_) async => (result: PsitoDiskResult.failed, mountPoint: null),
    );
    await pump(tester, req);
    await tester.enterText(field(), 'certa');
    await tester.tap(find.text(l10n.diskUnlockAction));
    await tester.pump();
    expect(await req.done, isNull);
    expect(req.failed, isTrue);
  });

  testWidgets('Esc e Cancelar desistem', (tester) async {
    final esc = request((_) async => throw StateError('sem tentativa'));
    await pump(tester, esc);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(await esc.done, isNull);

    final cancel = request((_) async => throw StateError('sem tentativa'));
    await pump(tester, cancel);
    await tester.tap(find.text(l10n.diskUnlockCancel));
    expect(await cancel.done, isNull);
  });

  testWidgets('o botão de mostrar tem nome e revela a senha', (tester) async {
    await pump(
      tester,
      request((_) async => (result: PsitoDiskResult.ok, mountPoint: '/m')),
    );
    expect(tester.widget<TextField>(field()).obscureText, isTrue);
    expect(find.byTooltip(l10n.diskUnlockShow), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('disk-password-show')));
    await tester.pump();

    expect(tester.widget<TextField>(field()).obscureText, isFalse);
    expect(find.byTooltip(l10n.diskUnlockHide), findsOneWidget);
  });
}
