import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/storage_service.dart';
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

  group('formatar', () {
    Future<void> open(WidgetTester tester, FakeStorage storage) async {
      await pump(tester, storage);
      await tester.tap(find.byKey(fmt));
      await tester.pump();
    }

    Finder confirm() => find.byKey(const ValueKey('storage-format-confirm'));

    testWidgets('só com o nome digitado certo', (tester) async {
      await open(tester, FakeStorage());
      expect(goButton(tester).onPressed, isNull);
      await tester.enterText(confirm(), 'pendrive');
      await tester.pump();
      expect(goButton(tester).onPressed, isNull);
      await tester.enterText(confirm(), 'PENDRIVE');
      await tester.pump();
      expect(goButton(tester).onPressed, isNotNull);
    });

    testWidgets('leva o tipo e o nome novo, e diz o resultado', (tester) async {
      final storage = FakeStorage();
      await open(tester, storage);
      await tester.enterText(
        find.byKey(const ValueKey('storage-format-label')),
        'NOVO',
      );
      await tester.enterText(confirm(), 'PENDRIVE');
      await tester.pump();
      await tester.tap(find.byKey(go));
      await tester.pump();
      await tester.pump();
      expect(storage.formatted.single, (
        '/fake/pendrive',
        PsitoDiskFormat.exfat,
        'NOVO',
      ));
      expect(find.text(l.storageFormatDone), findsOneWidget);
      expect(find.byKey(go), findsNothing);
    });

    testWidgets('um disco em uso avisa', (tester) async {
      final storage = FakeStorage()..answer = PsitoDiskResult.busy;
      await open(tester, storage);
      await tester.enterText(confirm(), 'PENDRIVE');
      await tester.pump();
      await tester.tap(find.byKey(go));
      await tester.pump();
      await tester.pump();
      expect(find.text(l.storageFormatBusy), findsOneWidget);
    });

    testWidgets('cancelar fecha sem formatar', (tester) async {
      final storage = FakeStorage();
      await open(tester, storage);
      await tester.tap(find.text(l.storageFormatCancel));
      await tester.pump();
      expect(find.byKey(go), findsNothing);
      expect(storage.formatted, isEmpty);
    });
  });
}
