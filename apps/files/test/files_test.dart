import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_files/files_app.dart';
import 'package:psito_files/l10n/files_localizations.dart';
import 'package:psito_files/src/format.dart';
import 'package:psito_files/src/tab.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_sdk/psito_sdk.dart';

/// Os discos sem o shell: guarda o que o Files pediu.
class FakeVolumes implements PsitoVolumes {
  @override
  final ValueNotifier<List<PsitoVolume>> volumes = ValueNotifier(const []);
  final asked = <String>[];
  String? mounted;
  PsitoDiskResult answer = PsitoDiskResult.ok;

  @override
  Future<String?> mount(String id) async {
    asked.add('mount $id');
    return mounted;
  }

  @override
  Future<PsitoDiskResult> unmount(String id) async => answer;

  @override
  Future<PsitoDiskResult> eject(String id) async {
    asked.add('eject $id');
    return answer;
  }

  @override
  Future<String?> unlock(String id) async {
    asked.add('unlock $id');
    return mounted;
  }

  List<String> users = const [];

  @override
  Future<List<String>> usersOf(String id) async => users;
}

/// O contexto de um app sem o shell: guarda o que o Files pediu.
class FakeContext implements PsitoAppContext {
  @override
  final FakeVolumes volumes = FakeVolumes();

  final opened = <List<String>>[];
  final requests = StreamController<List<String>>.broadcast();
  String title = '';
  bool closed = false;

  @override
  List<String> openedPaths;

  FakeContext({this.openedPaths = const []});

  @override
  String get windowId => 'files#1';
  @override
  void setTitle(String title) => this.title = title;
  @override
  void close() => closed = true;
  @override
  void notify(PsitoNotification notification) {}
  @override
  ValueListenable<PsitoSettings> get settings =>
      ValueNotifier(PsitoSettings.defaults);
  @override
  void updateSettings(PsitoSettings settings) {}
  @override
  ValueListenable<PsitoSystemInfo> get systemInfo =>
      ValueNotifier(PsitoSystemInfo.unavailable);
  @override
  ValueListenable<PsitoNetworkState> get network =>
      ValueNotifier(const PsitoNetworkState(available: false));
  @override
  ValueListenable<PsitoTimeState> get time =>
      ValueNotifier(const PsitoTimeState(available: false));
  @override
  DateTime now() => DateTime(2026, 10, 31, 12);
  @override
  Future<List<String>> timezones() async => const [];
  @override
  void setTimezone(String timezone) {}
  @override
  PsitoAccounts get accounts => const PsitoNoAccounts();

  @override
  PsitoNetworkConnections get networkConnections =>
      const PsitoNoNetworkConnections();

  @override
  void setNtp(bool enabled) {}
  @override
  Stream<List<String>> get openRequests => requests.stream;
  @override
  Future<void> open(List<String> paths, {String? withApp}) async =>
      opened.add(paths);
  @override
  Future<List<PsitoAppChoice>> appsFor(String mimeType) async => const [
    PsitoAppChoice(id: 'org.psito.notepad', name: 'Notepad', isDefault: true),
  ];
  @override
  Future<void> setDefaultApp(String mimeType, String appId) async {}

  @override
  Future<bool> acceptsDrop(List<String> paths) async => false;

  @override
  Future<bool> openDropped(List<String> paths) async => false;

  @override
  Future<String?> pickFile({
    required String title,
    List<String> patterns = const [],
  }) async => null;
}

late Directory home;

String p(String rel) => '${home.path}/$rel';

void write(String rel, [String text = 'x']) => File(p(rel))
  ..createSync(recursive: true)
  ..writeAsStringSync(text);

FilesEnv testEnv() => FilesEnv(
  home: home.path,
  mime: MimeDatabase.empty(),
  trash: Trash(p('.local/share/Trash')),
  userDirs: {UserDir.documents: p('Documentos')},
);

/// Espera de verdade (o IO e os Isolates) até [done].
Future<void> until(bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(done(), isTrue);
}

void main() {
  setUp(() {
    home = Directory.systemTemp.createTempSync('psito_files');
    write('Documentos/nota.txt', 'oi');
    write('foto 10.txt');
    write('foto 2.txt');
    write('.oculto');
  });
  tearDown(() => home.deleteSync(recursive: true));

  test('formatos: tamanho, data e permissões', () {
    final l = lookupFilesLocalizations(const Locale('pt'));
    expect(formatSize(l, 1), '1 byte');
    expect(formatSize(l, 999), '999 bytes');
    expect(formatSize(l, 1234), '1,2 KB');
    expect(formatSize(l, 56 * 1000 * 1000), '56 MB');
    final now = DateTime(2026, 10, 31, 12);
    expect(
      formatLocalDate(l, DateTime.utc(2026, 10, 31, 9, 5), now),
      'Hoje, 09:05',
    );
    expect(
      formatLocalDate(l, DateTime.utc(2026, 10, 30, 23), now),
      'Ontem, 23:00',
    );
    expect(
      formatLocalDate(l, DateTime.utc(2025, 1, 2, 3, 4), now),
      '2 de jan. de 2025, 03:04',
    );
    expect(formatMode(0x1ed), 'rwxr-xr-x');
  });

  group('o controlador', () {
    late FakeContext ctx;
    late FilesController files;

    setUp(() {
      ctx = FakeContext();
      final env = testEnv();
      files = FilesController(
        ctx: ctx,
        env: env,
        config: FilesConfig(favorites: FilesConfig.defaultFavorites(env)),
      );
    });
    tearDown(() => files.dispose());

    test('a pasta da lixeira, mandada pela dock, abre a Lixeira', () {
      files.openPaths([p('.local/share/Trash/files/')]);
      expect(files.tab.location, const TrashLocation());
    });

    group('os discos', () {
      const volume = PsitoVolume(
        id: 'v',
        label: 'PENDRIVE',
        device: '/dev/sdb',
      );
      late List<String> messages;
      late String mount;

      setUp(() {
        messages = [];
        files.onError = messages.add;
        mount = p('Documentos');
      });

      test('abre onde já está montado, sem montar de novo', () async {
        await files.openVolume(volume.copyWith(mountPoint: () => mount));
        expect(files.tab.folder, mount);
        expect(ctx.volumes.asked, isEmpty);
      });

      test('monta e abre', () async {
        ctx.volumes.mounted = mount;
        await files.openVolume(volume);
        expect(ctx.volumes.asked, ['mount v']);
        expect(files.tab.folder, mount);
      });

      test('sem conseguir montar, avisa e fica onde estava', () async {
        final before = files.tab.folder;
        await files.openVolume(volume);
        expect(messages, ['Não foi possível abrir este disco.']);
        expect(files.tab.folder, before);
      });

      test('um trancado pede para destrancar e vai para onde montou', () async {
        ctx.volumes.mounted = mount;
        await files.openVolume(volume.copyWith(locked: true));
        expect(ctx.volumes.asked, ['unlock ${volume.id}']);
        expect(files.tab.folder, mount);
        expect(messages, isEmpty);
      });

      test('desistir da senha fica onde estava, sem aviso', () async {
        final before = files.tab.folder;
        await files.openVolume(volume.copyWith(locked: true));
        expect(files.tab.folder, before);
        expect(messages, isEmpty);
      });

      test('ejetar tira as abas do disco antes de pedir', () async {
        final inside = volume.copyWith(mountPoint: () => mount);
        await files.openVolume(inside);
        await files.ejectVolume(inside);
        expect(files.tab.folder, files.env.home);
        expect(ctx.volumes.asked, ['eject v']);
        expect(messages, ['Já pode tirar o disco.']);
      });

      test('uma pasta de nome parecido não sai do lugar', () async {
        final other = p('Documentos2');
        files.tab.go(FolderLocation(other));
        await files.ejectVolume(volume.copyWith(mountPoint: () => mount));
        expect(files.tab.folder, other);
      });

      test('disco em uso avisa', () async {
        ctx.volumes.answer = PsitoDiskResult.busy;
        await files.ejectVolume(volume);
        expect(messages.single, contains('em uso'));
      });

      test('diz quem está usando, quando dá para saber', () async {
        ctx.volumes.answer = PsitoDiskResult.busy;
        ctx.volumes.users = ['foot', 'vlc'];
        await files.ejectVolume(volume);
        expect(messages.single, contains('foot, vlc'));
      });

      test('enquanto ejeta, marca o disco, e depois solta', () async {
        final done = files.ejectVolume(volume);
        expect(files.ejecting.value, {'v'});
        await done;
        expect(files.ejecting.value, isEmpty);
      });

      test('um disco puxado tira as abas de lá', () async {
        final inside = volume.copyWith(mountPoint: () => mount);
        ctx.volumes.volumes.value = [inside];
        await files.openVolume(inside);
        files.newTab(FolderLocation(p('Documentos/a')));
        files.newTab(FolderLocation(p('Documentos2')));
        ctx.volumes.volumes.value = const [];
        expect(files.tabs.map((t) => t.folder), [
          files.env.home,
          files.env.home,
          p('Documentos2'),
        ]);
      });
    });

    test('lista o home sem os ocultos, na ordem natural', () async {
      await until(() => files.tab.items.isNotEmpty);
      expect(files.tab.items.map((e) => e.name), [
        'Documentos',
        'foto 2.txt',
        'foto 10.txt',
      ]);
      expect(ctx.title, 'Início');
      files.config.setShowHidden(true);
      expect(files.tab.items.map((e) => e.name), contains('.oculto'));
    });

    test('nova pasta já em edição, renomear e desfazer', () async {
      await until(() => files.tab.items.isNotEmpty);
      await files.newFolder();
      expect(Directory(p('Nova pasta')).existsSync(), isTrue);
      expect(files.tab.renaming, p('Nova pasta'));
      expect(await files.rename(p('Nova pasta'), 'Projetos'), isTrue);
      expect(Directory(p('Projetos')).existsSync(), isTrue);
      expect(files.undoLabel, 'Renomear');
      await files.undo();
      expect(Directory(p('Nova pasta')).existsSync(), isTrue);
      await files.undo();
      expect(Directory(p('Nova pasta')).existsSync(), isFalse);
    });

    test('copiar e colar, recortar e colar, e a lixeira', () async {
      await until(() => files.tab.items.isNotEmpty);
      files.copy([p('foto 2.txt')]);
      files.tab.go(FolderLocation(p('Documentos')));
      await files.paste();
      expect(File(p('Documentos/foto 2.txt')).existsSync(), isTrue);
      expect(File(p('foto 2.txt')).existsSync(), isTrue);
      expect(files.tab.selection, {p('Documentos/foto 2.txt')});

      files.copy([p('foto 10.txt')], cut: true);
      await files.paste();
      expect(File(p('foto 10.txt')).existsSync(), isFalse);
      expect(files.clipboard, isEmpty);
      await files.undo();
      expect(File(p('foto 10.txt')).existsSync(), isTrue);

      await files.moveToTrash([p('Documentos/nota.txt')]);
      files.tab.go(const TrashLocation());
      await until(() => files.tab.items.isNotEmpty);
      expect(
        files.tab.trashItems.values.single.originalPath,
        p('Documentos/nota.txt'),
      );
      await files.restore([files.tab.items.single.path]);
      expect(File(p('Documentos/nota.txt')).readAsStringSync(), 'oi');
    });

    test(
      'abrir: a pasta na aba, o arquivo pelo shell, e na lixeira não',
      () async {
        await until(() => files.tab.items.isNotEmpty);
        final docs = files.tab.items.first;
        await files.open([docs]);
        expect(files.tab.folder, p('Documentos'));
        await until(() => files.tab.items.isNotEmpty);
        await files.open([files.tab.items.single]);
        expect(ctx.opened, [
          [p('Documentos/nota.txt')],
        ]);
        files.tab.back();
        expect(files.tab.folder, home.path);
        // Voltar seleciona a pasta de onde se veio
        expect(files.tab.selection, {p('Documentos')});
        files.tab.up();
        expect(files.tab.folder, dirName(home.path));
        expect(files.tab.selection, {home.path});
      },
    );

    test('o que o shell manda com o Files aberto vira aba', () async {
      ctx.requests.add([p('Documentos'), p('foto 2.txt')]);
      await until(() => files.tabs.length == 3);
      expect(files.tabs[1].folder, p('Documentos'));
      expect(files.tabs[2].folder, home.path);
      expect(files.tabs[2].selection, {p('foto 2.txt')});
      expect(files.activeIndex, 2);
      files.closeTab();
      files.closeTab();
      files.closeTab();
      expect(ctx.closed, isTrue);
    });

    test('o caminho marcado abre o Quick Look, sem outra aba', () async {
      expect(files.takeQuickLook(), isFalse);
      ctx.requests.add(['$psitoQuickLookPrefix${p('Documentos')}/a.txt']);
      await until(() => files.tabs.length == 2);
      expect(files.tab.folder, p('Documentos'));
      expect(files.tab.cursor, '${p('Documentos')}/a.txt');
      expect(files.takeQuickLook(), isTrue);
      expect(files.takeQuickLook(), isFalse);
      // O seguinte, na mesma pasta, fica na mesma aba
      files.selectTab(0);
      ctx.requests.add(['$psitoQuickLookPrefix${p('Documentos')}/b.txt']);
      await until(() => files.activeIndex == 1);
      expect(files.tabs, hasLength(2));
      expect(files.tab.selection, {'${p('Documentos')}/b.txt'});
      expect(files.takeQuickLook(), isTrue);
    });

    test('a busca acha nas subpastas', () async {
      files.tab.go(SearchLocation(home.path, 'NOTA'));
      await until(() => !files.tab.searching && files.tab.items.isNotEmpty);
      expect(files.tab.items.single.path, p('Documentos/nota.txt'));
      files.reveal(files.tab.items.single.path);
      expect(files.tab.folder, p('Documentos'));
      expect(files.tab.selection, {p('Documentos/nota.txt')});
    });

    test('a seleção: Shift, Ctrl, setas, digitar e tudo', () async {
      await until(() => files.tab.items.isNotEmpty);
      final tab = files.tab;
      tab.tap(p('Documentos'));
      tab.tap(p('foto 10.txt'), extend: true);
      expect(tab.selection, hasLength(3));
      tab.tap(p('foto 2.txt'), toggle: true);
      expect(tab.selection, {p('Documentos'), p('foto 10.txt')});
      // O Ctrl deixou as setas no foto 2
      tab.moveCursor(-1);
      expect(tab.selection, {p('Documentos')});
      tab.moveCursor(1, extend: true);
      expect(tab.selection, {p('Documentos'), p('foto 2.txt')});
      tab.typeAhead('d');
      expect(tab.selection, {p('Documentos')});
      tab.selectAll();
      expect(tab.selection, hasLength(3));
    });

    test('a configuração vai e volta do files.json', () async {
      final env = FilesEnv(
        home: home.path,
        mime: MimeDatabase.empty(),
        trash: Trash(p('t')),
        configFile: File(p('.config/psito/files.json')),
      );
      final config = FilesConfig.load(env);
      expect(config.favorites, [home.path]);
      config
        ..addFavorite(p('Documentos'))
        ..setMode(p('Documentos'), ViewMode.columns)
        ..setIconSize(500)
        ..save();
      final again = FilesConfig.load(env);
      expect(again.favorites, [home.path, p('Documentos')]);
      expect(again.modeFor(p('Documentos')), ViewMode.columns);
      expect(again.modeFor(p('outra')), ViewMode.columns);
      expect(again.iconSize, FilesConfig.maxIconSize);
      config.dispose();
      again.dispose();
    });
  });

  group('a janela', () {
    Future<FakeContext> pump(WidgetTester tester, {Size? size}) async {
      if (size != null) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }
      final ctx = FakeContext();
      final env = testEnv();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: psitoLocalizationsDelegates(
            const FilesApp().localizationsDelegates,
          ),
          supportedLocales: psitoLocales,
          theme: psitoTheme(const Color(0xFFFFC107)),
          home: Scaffold(
            body: FilesView(
              appContext: ctx,
              env: env,
              config: FilesConfig(favorites: FilesConfig.defaultFavorites(env)),
            ),
          ),
        ),
      );
      await settle(tester, () => find.text('foto 2.txt').evaluate().isNotEmpty);
      return ctx;
    }

    testWidgets('o Enter renomeia e o duplo clique abre', (tester) async {
      final ctx = await pump(tester);
      await tester.tap(find.text('foto 2.txt'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).last, 'foto 3.txt');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester, () => File(p('foto 3.txt')).existsSync());
      await settle(tester, () => find.text('foto 3.txt').evaluate().isNotEmpty);

      await tester.tap(find.text('foto 10.txt'));
      // A seleção não espera o tempo do duplo clique
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('foto 10.txt'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(ctx.opened, [
        [p('foto 10.txt')],
      ]);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('o Espaço pré-visualiza, e os modos pelo teclado', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('foto 2.txt'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(find.text('Nome'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(find.text('Nome'), findsNothing);
      // Nas colunas o selecionado aparece também na pré-visualização
      expect(find.text('foto 2.txt'), findsNWidgets(2));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('o Delete manda para a lixeira', (tester) async {
      await pump(tester);
      await tester.tap(find.text('foto 2.txt'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await settle(tester, () => !File(p('foto 2.txt')).existsSync());
      expect(
        File(p('.local/share/Trash/files/foto 2.txt')).existsSync(),
        isTrue,
      );
      // O tempo do duplo clique
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('o que o shell manda aparece como aba, com a contagem', (
      tester,
    ) async {
      final ctx = await pump(tester);
      expect(find.byTooltip('Nova aba (Ctrl+T)'), findsNothing);
      Directory(p('docs')).createSync();
      write('docs/um.txt');
      ctx.requests.add([p('docs')]);
      await settle(tester, () => find.text('um.txt').evaluate().isNotEmpty);
      // A barra das abas e a de status são const: precisam do FilesScope
      expect(find.byTooltip('Nova aba (Ctrl+T)'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    for (final size in [const Size(240, 160), const Size(900, 560)]) {
      testWidgets('cabe em ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        await pump(tester, size: size);
        for (final mode in ['1', '2', '3']) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(
            LogicalKeyboardKey.findKeyByKeyId(mode.codeUnitAt(0))!,
          );
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'modo $mode');
        }
        // O files.json grava meio segundo depois
        await tester.pump(const Duration(seconds: 1));
      });
    }
  });
}

/// O IO de verdade dentro do teste de widget: roda o relógio real aos
/// poucos até [done].
Future<void> settle(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(done(), isTrue);
}
