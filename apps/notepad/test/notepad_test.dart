import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_notepad/notepad_app.dart';

void main() {
  test('a nota só vai para o disco no sandbox', () {
    expect(noteFile({'HOME': '/home/psito'}), isNull);
    expect(
      noteFile({'HOME': '/home/psito', 'PSITO_APP_ID': 'org.psito.notepad'})!
          .path,
      '/home/psito/nota.txt',
    );
  });

  testWidgets('carrega a nota e grava depois de editar', (tester) async {
    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('psito-notepad'),
    );
    addTearDown(() => dir!.deleteSync(recursive: true));
    final file = File('${dir!.path}/nota.txt')..writeAsStringSync('oi');

    // A leitura do arquivo é IO de verdade: começa e termina fora do relógio
    // falso dos testes
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NotepadView(file: file)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(find.text('oi'), findsOneWidget);
    expect(find.text('Salvo em ~/nota.txt'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'oi, mundo');
    await tester.pump();
    expect(find.text('Salvando...'), findsOneWidget);
    // O timer do salvamento é do relógio falso; a gravação, IO de verdade
    await tester.pump(const Duration(milliseconds: 1100));
    // Cada passo da gravação (abrir, escrever, fechar) volta pelo relógio falso
    final saved = find.text('Salvo em ~/nota.txt');
    for (var i = 0; i < 20 && saved.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(file.readAsStringSync(), 'oi, mundo');
    expect(find.text('Salvo em ~/nota.txt'), findsOneWidget);
  });

  testWidgets('sem arquivo, a nota fica na memória', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NotepadView())),
    );
    expect(find.text('Nota só nesta sessão'), findsOneWidget);
  });
}
