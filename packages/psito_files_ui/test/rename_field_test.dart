import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_files_ui/psito_files_ui.dart';

void main() {
  late List<String> submitted;
  late int cancelled;

  Future<void> pump(WidgetTester tester, {bool isDirectory = false}) async {
    submitted = [];
    cancelled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RenameField(
            name: 'notas.tar.gz',
            isDirectory: isDirectory,
            onSubmit: submitted.add,
            onCancel: () => cancelled++,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  TextEditingController text(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!;

  // No desktop, o TextField seleciona tudo ao ganhar o foco
  testWidgets('no Linux, começa com o nome sem a extensão selecionado', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await pump(tester);
    final selection = text(tester).selection;
    debugDefaultTargetPlatformOverride = null;
    expect(selection, const TextSelection(baseOffset: 0, extentOffset: 5));
  });

  testWidgets('uma pasta seleciona o nome inteiro', (tester) async {
    await pump(tester, isDirectory: true);
    expect(text(tester).selection.extentOffset, 'notas.tar.gz'.length);
  });

  testWidgets('o Enter confirma o nome novo, sem as pontas', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), ' novo.txt ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, ['novo.txt']);
    expect(cancelled, 0);
  });

  testWidgets('o nome igual cancela', (tester) async {
    await pump(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(cancelled, 1);
    expect(submitted, isEmpty);
  });

  testWidgets('o nome vazio cancela', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(cancelled, 1);
    expect(submitted, isEmpty);
  });

  testWidgets('o Esc cancela, sem confirmar ao perder o foco', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'novo');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(cancelled, 1);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(submitted, isEmpty);
  });

  testWidgets('perder o foco confirma', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'novo');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(submitted, ['novo']);
  });
}
