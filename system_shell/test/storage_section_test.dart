import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/storage_service.dart';
import 'package:psito_settings/format_disk_view.dart';
import 'package:psito_settings/l10n/settings_localizations.dart';
import 'package:psito_settings/storage_section.dart';

void main() {
  final l = lookupSettingsLocalizations(const Locale('pt'));

  Future<void> pump(WidgetTester tester, FakeStorage storage) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt'),
        theme: psitoTheme(PsitoSettings.defaults.accent),
        localizationsDelegates: SettingsLocalizations.localizationsDelegates,
        supportedLocales: SettingsLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(children: [StorageSection(storage: storage)]),
        ),
      ),
    );
    await tester.pump();
  }

  const fmt = ValueKey('storage-format-/fake/pendrive');
  const go = ValueKey('storage-format-go');

  FilledButton goButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(go));

  testWidgets('mostra o sistema e o pendrive, e só este formata', (
    tester,
  ) async {
    await pump(tester, FakeStorage());
    expect(find.text(l.storageThisComputer), findsOneWidget);
    expect(find.text('PENDRIVE'), findsOneWidget);
    expect(find.text(l.storageFree('4,0 GB', '16 GB')), findsOneWidget);
    expect(find.text(l.storageFormat), findsOneWidget);
  });

  testWidgets('um disco sem montar diz o tamanho', (tester) async {
    await pump(
      tester,
      FakeStorage(const [
        PsitoDiskUsage(id: '/a', name: 'A', total: 8000000000),
      ]),
    );
    expect(find.text(l.storageNotMounted('8,0 GB')), findsOneWidget);
    expect(find.text(l.storageLargest), findsNothing);
  });

  testWidgets('um disco quase cheio avisa', (tester) async {
    await pump(
      tester,
      FakeStorage(const [
        PsitoDiskUsage(path: '/h', total: 100000000000, free: 1000000000),
      ]),
    );
    expect(find.text(l.storageAlmostFull), findsOneWidget);
  });

  testWidgets('as maiores pastas abrem nos Arquivos', (tester) async {
    final storage = FakeStorage();
    await pump(tester, storage);
    await tester.tap(find.byKey(const ValueKey('storage-largest-')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('40 GB'), findsOneWidget);
    await tester.tap(find.text('.cache'));
    expect(storage.opened, ['/home/ana/.cache']);
  });

  testWidgets('a lixeira pede para o shell perguntar', (tester) async {
    final storage = FakeStorage();
    await pump(tester, storage);
    await tester.tap(find.byKey(const ValueKey('storage-empty-trash')));
    expect(storage.asksToEmpty, 1);
  });

  testWidgets('sem nada na lixeira, não há o que esvaziar', (tester) async {
    await pump(tester, FakeStorage()..trash = 0);
    final button = tester.widget<TextButton>(
      find.byKey(const ValueKey('storage-empty-trash')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('formatar abre outra janela', (tester) async {
    final storage = FakeStorage();
    await pump(tester, storage);
    await tester.tap(find.byKey(fmt));
    expect(storage.opened, ['format:/fake/pendrive']);
    expect(storage.formatted, isEmpty);
  });

  group('a janela de formatar', () {
    Future<_Context> open(WidgetTester tester, FakeStorage storage) async {
      final ctx = _Context(storage);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt'),
          theme: psitoTheme(PsitoSettings.defaults.accent),
          localizationsDelegates: SettingsLocalizations.localizationsDelegates,
          supportedLocales: SettingsLocalizations.supportedLocales,
          home: Scaffold(
            body: FormatDiskView(appContext: ctx, id: '/fake/pendrive'),
          ),
        ),
      );
      await tester.pump();
      return ctx;
    }

    Future<void> confirmFormat(WidgetTester tester) async {
      await tester.tap(find.byKey(go));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('storage-format-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    test('o argumento diz qual disco', () {
      expect(formatDiskArgument(['$psitoFormatDiskPrefix/a/b']), '/a/b');
      expect(
        formatDiskArgument(['${psitoSettingsSectionPrefix}storage']),
        isNull,
      );
    });

    testWidgets('os campos vêm na ordem, com o nome e a capacidade', (
      tester,
    ) async {
      await open(tester, FakeStorage());
      double top(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;
      expect(
        top('storage-format-label'),
        lessThan(top('storage-format-capacity')),
      );
      expect(
        top('storage-format-capacity'),
        lessThan(top('storage-format-type')),
      );
      expect(find.text('PENDRIVE'), findsOneWidget);
      expect(find.text('16 GB'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('storage-format-close')))
            .dx,
        lessThan(tester.getTopLeft(find.byKey(go)).dx),
      );
    });

    testWidgets('pergunta antes de apagar, e desistir não formata', (
      tester,
    ) async {
      final storage = FakeStorage();
      await open(tester, storage);
      await tester.tap(find.byKey(go));
      await tester.pumpAndSettle();
      expect(find.text(l.storageFormatWarning('PENDRIVE')), findsOneWidget);
      await tester.tap(find.text(l.storageFormatCancel).last);
      await tester.pumpAndSettle();
      expect(storage.formatted, isEmpty);
    });

    testWidgets('formatando, trava os controles e mostra o progresso', (
      tester,
    ) async {
      final storage = _SlowStorage();
      await open(tester, storage);
      await confirmFormat(tester);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(goButton(tester).onPressed, isNull);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('storage-format-label')),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('storage-format-close')),
            )
            .onPressed,
        isNull,
      );
      storage.finish.complete(PsitoDiskResult.ok);
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('leva o tipo e o nome, avisa no fim e recarrega no OK', (
      tester,
    ) async {
      final storage = FakeStorage();
      await open(tester, storage);
      await tester.enterText(
        find.byKey(const ValueKey('storage-format-label')),
        'NOVO',
      );
      await confirmFormat(tester);
      await tester.pumpAndSettle();
      expect(storage.formatted.single, (
        '/fake/pendrive',
        PsitoDiskFormat.exfat,
        'NOVO',
      ));
      expect(find.text(l.storageFormatDone), findsOneWidget);
      storage.usage.value = const [
        PsitoDiskUsage(
          id: '/fake/pendrive',
          name: 'OUTRO',
          path: '/media/psito/OUTRO',
          total: 16000000000,
          free: 16000000000,
        ),
      ];
      await tester.tap(find.byKey(const ValueKey('storage-format-ok')));
      await tester.pumpAndSettle();
      expect(find.text(l.storageFormatDone), findsNothing);
      expect(find.text('OUTRO'), findsOneWidget);
      expect(goButton(tester).onPressed, isNotNull);
    });

    testWidgets('o disco sair e voltar no meio não perde o aviso', (
      tester,
    ) async {
      final storage = FakeStorage();
      await open(tester, storage);
      await tester.tap(find.byKey(go));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('storage-format-confirm')));
      storage.usage.value = const [];
      await tester.pumpAndSettle();
      expect(find.text(l.storageFormatDone), findsOneWidget);
      expect(find.text(l.storageFormatGone), findsNothing);
    });

    testWidgets('um disco em uso avisa, e o formulário continua', (
      tester,
    ) async {
      final storage = FakeStorage()..answer = PsitoDiskResult.busy;
      await open(tester, storage);
      await confirmFormat(tester);
      await tester.pumpAndSettle();
      expect(find.text(l.storageFormatBusy), findsOneWidget);
      expect(goButton(tester).onPressed, isNotNull);
    });

    testWidgets('um disco que saiu diz isso, e não formata', (tester) async {
      final storage = FakeStorage(const []);
      await open(tester, storage);
      expect(find.text(l.storageFormatGone), findsOneWidget);
      expect(find.byKey(go), findsNothing);
    });

    testWidgets('cancelar fecha a janela sem formatar', (tester) async {
      final storage = FakeStorage();
      final ctx = await open(tester, storage);
      await tester.tap(find.byKey(const ValueKey('storage-format-close')));
      expect(ctx.closed, isTrue);
      expect(storage.formatted, isEmpty);
    });
  });
}

class _SlowStorage extends FakeStorage {
  final finish = Completer<PsitoDiskResult>();

  @override
  Future<PsitoDiskResult> format(
    String id,
    PsitoDiskFormat type,
    String label,
  ) => finish.future;
}

class _Context implements PsitoAppContext {
  @override
  final PsitoStorage storage;
  bool closed = false;

  _Context(this.storage);

  @override
  void close() => closed = true;

  @override
  void setTitle(String title) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
