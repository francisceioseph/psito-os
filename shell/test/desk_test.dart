import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_desktop/psito_desktop.dart';
import 'package:psito_dock/psito_dock.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_runtime/psito_runtime.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/system_services.dart';
import 'package:psito_services/disks_service.dart';
import 'package:psito_shell/desk.dart';
import 'package:psito_shell/dock.dart';
import 'package:psito_shell/desktop_entries.dart';
import 'package:psito_shell/shell_state.dart';
import 'package:psito_shell/surfaces.dart';
import 'package:psito_shell/toplevels.dart';
import 'package:system_shell/shell/settings_store.dart';
import 'package:system_shell/widgets/dock_menu.dart';
import 'package:system_shell/widgets/top_bar.dart';

const _surfaces = MethodChannel('psito_test/desk_surfaces');
const _clipboard = MethodChannel('psito_test/desk_clipboard');
const _toplevels = MethodChannel('psito_test/desk_toplevels');

const _shortcut = '''
[Desktop Entry]
Type=Application
Name=Meu app
Name[pt]=Meu programa
Exec=/nao/existe/meu-app
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late ShellState state;
  late DeskController desk;
  late List<List<String>> opened;
  late List<DesktopEntry> launched;
  late PsitoClipboard clipboard;
  late List<MethodCall> surfaceCalls;

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue);
  }

  String path(String name) => '${dir.path}/$name';
  DeskItem item(String key) => desk.items.firstWhere((i) => i.key == key);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('psito_desk_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    surfaceCalls = [];
    messenger.setMockMethodCallHandler(_surfaces, (call) async {
      surfaceCalls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(_toplevels, (_) async => null);
    state = ShellState(
      settings: SettingsStore.memory(),
      services: SystemServices.fake(),
      toplevels: ToplevelList(channel: _toplevels),
      surfaces: const Surfaces(_surfaces),
      dock: DockStore.memory(),
    );
    opened = [];
    launched = [];
    clipboard = PsitoClipboard(_clipboard);
    state.openPaths = (paths, {withApp}) async =>
        opened.add([...paths, ?withApp]);
    desk = DeskController(
      state,
      dir: dir.path,
      home: '/home/x',
      mime: MimeDatabase.load(const []),
      store: DeskStore.memory(),
      env: const {'LANG': 'pt_BR.UTF-8', 'PATH': '/nao/existe'},
      clipboard: clipboard,
      launchEntry: (app) async => launched.add(app),
    );
    desk.setGrid(const DeskGrid(4, 3));
  });

  tearDown(() async {
    desk.dispose();
    await dir.delete(recursive: true);
  });

  test('mostra os arquivos da pasta, sem os ocultos', () async {
    File(path('b.txt')).writeAsStringSync('b');
    File(path('.oculto')).writeAsStringSync('');
    Directory(path('a')).createSync();
    await desk.reload();
    expect([for (final i in desk.items) i.key], ['a', 'b.txt']);
    expect(desk.cells['a'], const DeskCell(0, 0));
    expect(desk.cells['b.txt'], const DeskCell(0, 1));
  });

  test('a posição salva vale, e o novo não toma o lugar', () async {
    await desk.store.put({'b.txt': const DeskCell(0, 0)});
    File(path('a.txt')).writeAsStringSync('');
    File(path('b.txt')).writeAsStringSync('');
    await desk.reload();
    expect(desk.cells['b.txt'], const DeskCell(0, 0));
    expect(desk.cells['a.txt'], const DeskCell(0, 1));
    // O novo guardou a dele
    expect(desk.store.cells['a.txt'], const DeskCell(0, 1));
  });

  test('uma tela menor não apaga a posição salva', () async {
    await desk.store.put({'a.txt': const DeskCell(3, 2)});
    File(path('a.txt')).writeAsStringSync('');
    await desk.reload();
    desk.setGrid(const DeskGrid(2, 2));
    expect(desk.cells['a.txt'], const DeskCell(1, 1));
    expect(desk.store.cells['a.txt'], const DeskCell(3, 2));
    desk.setGrid(const DeskGrid(4, 3));
    expect(desk.cells['a.txt'], const DeskCell(3, 2));
  });

  test('um arquivo que sai da pasta esquece a posição', () async {
    File(path('a.txt')).writeAsStringSync('');
    await desk.reload();
    expect(desk.store.cells, contains('a.txt'));
    File(path('a.txt')).deleteSync();
    await desk.reload();
    await Future<void>.delayed(Duration.zero);
    expect(desk.store.cells, isNot(contains('a.txt')));
  });

  test('o home e a lixeira vêm das configurações', () async {
    state.settings.update(
      state.settings.value.copyWith(
        desktopShowHome: true,
        desktopShowTrash: true,
      ),
    );
    await desk.reload();
    expect(
      [for (final i in desk.items) i.key],
      [DeskItem.homeKey, DeskItem.trashKey],
    );
    desk.open(DeskItem.homeKey);
    expect(opened.single, ['/home/x']);
  });

  test('desligados, os ícones somem, e as posições ficam', () async {
    File(path('a.txt')).writeAsStringSync('');
    await desk.reload();
    state.settings.update(
      state.settings.value.copyWith(desktopShowIcons: false),
    );
    expect(desk.items, isEmpty);
    expect(desk.store.cells, contains('a.txt'));
  });

  test('o organizar sozinha segue a ordem, sem mexer nas salvas', () async {
    await desk.store.put({'a.txt': const DeskCell(3, 2)});
    File(path('a.txt')).writeAsStringSync('');
    await desk.reload();
    state.settings.update(
      state.settings.value.copyWith(desktopAutoArrange: true),
    );
    expect(desk.cells['a.txt'], const DeskCell(0, 0));
    expect(desk.store.cells['a.txt'], const DeskCell(3, 2));
  });

  test('um arquivo abre pelo caminho', () async {
    File(path('a.txt')).writeAsStringSync('');
    await desk.reload();
    desk.open('a.txt');
    expect(opened.single, [path('a.txt')]);
  });

  group('os atalhos', () {
    test(
      'mostram o nome localizado, e sem o programa estão quebrados',
      () async {
        File(path('meu.desktop')).writeAsStringSync(_shortcut);
        await desk.reload();
        expect(item('meu.desktop').name, 'Meu programa');
        expect(item('meu.desktop').broken, isTrue);
      },
    );

    test('o de um app instalado aponta para ele, mesmo renomeado', () async {
      File(path('meu.desktop')).writeAsStringSync(_shortcut);
      await desk.reload();
      final installed = DesktopEntry(
        id: 'org.exemplo.app',
        name: 'App',
        command: const ['/nao/existe/meu-app'],
      );
      state.apps.value = [installed];
      expect(item('meu.desktop').broken, isFalse);
      expect(desk.installedFor(item('meu.desktop').shortcut!), installed);
    });

    DesktopEntry installApp() {
      final installed = DesktopEntry(
        id: 'org.exemplo.app',
        name: 'App',
        command: const ['/nao/existe/meu-app'],
      );
      state.apps.value = [installed];
      return installed;
    }

    test('sem o +x pergunta, e confiar dá o +x e abre', () async {
      final installed = installApp();
      File(path('meu.desktop')).writeAsStringSync(_shortcut);
      await desk.reload();
      desk.open('meu.desktop');
      await until(() => state.deskTrust.value != null);
      expect(state.deskTrust.value!.name, 'Meu programa');
      expect(launched, isEmpty);
      expect(
        surfaceCalls.last,
        isMethodCall('showOverlay', arguments: 'exclusive'),
      );

      state.deskTrust.value!.onTrust();
      await until(() => launched.isNotEmpty);
      expect(launched.single, installed);
      expect(item('meu.desktop').entry!.executable, isTrue);
    });

    test('com o +x e do usuário, abre sem perguntar', () async {
      installApp();
      File(path('meu.desktop')).writeAsStringSync(_shortcut);
      Process.runSync('chmod', ['+x', path('meu.desktop')]);
      await desk.reload();
      desk.open('meu.desktop');
      await until(() => launched.isNotEmpty);
      expect(state.deskTrust.value, isNull);
    });

    test('quebrado avisa em vez de perguntar', () async {
      File(path('meu.desktop')).writeAsStringSync(_shortcut);
      await desk.reload();
      desk.open('meu.desktop');
      await until(() => state.notifications.history.isNotEmpty);
      expect(state.notifications.history.single.title, 'Atalho quebrado');
      expect(state.deskTrust.value, isNull);
    });

    test('renomear muda o Name, e não o arquivo nem o +x', () async {
      File(path('meu.desktop')).writeAsStringSync(_shortcut);
      Process.runSync('chmod', ['+x', path('meu.desktop')]);
      await desk.reload();
      await desk.rename('meu.desktop', 'Outro nome');
      expect(item('meu.desktop').name, 'Outro nome');
      expect(item('meu.desktop').entry!.executable, isTrue);
    });

    test('um .desktop sem o Exec é um arquivo qualquer', () async {
      File(path('ruim.desktop')).writeAsStringSync('[Desktop Entry]\nName=X\n');
      await desk.reload();
      expect(item('ruim.desktop').shortcut, isNull);
      expect(item('ruim.desktop').name, 'ruim.desktop');
    });
  });

  group('o teclado', () {
    late Trash trash;

    setUp(() async {
      trash = Trash('${dir.path}/.lixo');
      state.dockUi.trash = trash;
      File(path('a.txt')).writeAsStringSync('a');
      File(path('b.txt')).writeAsStringSync('b');
      File(path('c.txt')).writeAsStringSync('c');
      await desk.reload();
      desk.setKeyboard(true);
    });

    KeyEventResult down(LogicalKeyboardKey key) => desk.handleKey(
      KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: key,
        timeStamp: Duration.zero,
      ),
    );

    test('sem o foco do fundo, nenhuma tecla vale', () {
      desk.press('a.txt');
      desk.setKeyboard(false);
      expect(down(LogicalKeyboardKey.delete), KeyEventResult.ignored);
      expect(File(path('a.txt')).existsSync(), isTrue);
    });

    test('as setas andam e o Shift estende', () {
      desk.press('a.txt');
      desk.key(LogicalKeyboardKey.arrowDown);
      expect(desk.selected, {'b.txt'});
      desk.key(LogicalKeyboardKey.arrowDown, shift: true);
      expect(desk.selected, {'b.txt', 'c.txt'});
      desk.key(LogicalKeyboardKey.escape);
      expect(desk.selected, isEmpty);
    });

    test('o Ctrl+A pega todos, e o Enter abre todos', () {
      desk.key(LogicalKeyboardKey.keyA, ctrl: true);
      expect(desk.selected, {'a.txt', 'b.txt', 'c.txt'});
      desk.key(LogicalKeyboardKey.enter);
      expect(opened, [
        [path('a.txt')],
        [path('b.txt')],
        [path('c.txt')],
      ]);
    });

    test('digitar o começo do nome seleciona', () {
      desk.key(LogicalKeyboardKey.keyB, character: 'B');
      expect(desk.selected, {'b.txt'});
      desk.key(LogicalKeyboardKey.period, character: '.');
      expect(desk.selected, {'b.txt'});
    });

    test('uma letra com o Ctrl não é digitar', () {
      expect(
        desk.key(LogicalKeyboardKey.keyB, ctrl: true, character: 'b'),
        isFalse,
      );
      expect(desk.selected, isEmpty);
    });

    test('o Delete joga a seleção na lixeira, e o home fica', () async {
      state.settings.update(
        state.settings.value.copyWith(desktopShowHome: true),
      );
      await desk.reload();
      await desk.store.put({});
      desk.press(DeskItem.homeKey);
      desk.press('a.txt', ctrl: true);
      await desk.trashSelected();
      expect(File(path('a.txt')).existsSync(), isFalse);
      expect(File('${trash.filesDir}/a.txt').existsSync(), isTrue);
      expect(desk.selected, {DeskItem.homeKey});
    });

    test('o F2 abre o campo, mas não no home', () async {
      state.settings.update(
        state.settings.value.copyWith(desktopShowHome: true),
      );
      await desk.reload();
      desk.press(DeskItem.homeKey);
      desk.key(LogicalKeyboardKey.f2);
      expect(desk.renaming, isNull);
      desk.press('a.txt');
      desk.key(LogicalKeyboardKey.f2);
      expect(desk.renaming, 'a.txt');
      // Com o campo aberto, as teclas são dele
      expect(down(LogicalKeyboardKey.delete), KeyEventResult.ignored);
    });

    test('renomear leva a célula junto', () async {
      await desk.store.put({'a.txt': const DeskCell(2, 2)});
      await desk.reload();
      desk.startRename('a.txt');
      await desk.rename('a.txt', 'novo.txt');
      expect(desk.renaming, isNull);
      expect(File(path('novo.txt')).existsSync(), isTrue);
      expect(desk.cells['novo.txt'], const DeskCell(2, 2));
      expect(desk.selected, {'novo.txt'});
      expect(desk.store.cells, isNot(contains('a.txt')));
    });

    test('um nome que já existe avisa, e nada muda', () async {
      final cell = desk.cells['b.txt'];
      await desk.rename('a.txt', 'b.txt');
      expect(File(path('a.txt')).readAsStringSync(), 'a');
      expect(File(path('b.txt')).readAsStringSync(), 'b');
      expect(desk.cells['b.txt'], cell);
      expect(state.notifications.history.single.title, 'Sem como renomear');
    });

    test('a pasta nova já entra com o nome em edição', () async {
      await desk.newFolder();
      expect(Directory(path('Nova pasta')).existsSync(), isTrue);
      expect(desk.renaming, 'Nova pasta');
      expect(desk.selected, {'Nova pasta'});
    });

    test('o Espaço pede o Quick Look do item', () {
      final previews = <String>[];
      state.previewPath = (path) async => previews.add(path);
      desk.key(LogicalKeyboardKey.space);
      expect(previews, isEmpty);
      desk.press('a.txt');
      desk.key(LogicalKeyboardKey.space);
      expect(previews, [path('a.txt')]);
    });
  });

  test('o Ctrl preso de outra superfície não conta no clique', () async {
    File(path('a.txt')).writeAsStringSync('');
    File(path('b.txt')).writeAsStringSync('');
    await desk.reload();
    desk.setKeyboard(true);
    await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
    addTearDown(() => simulateKeyUpEvent(LogicalKeyboardKey.controlLeft));
    desk.press('a.txt');
    desk.press('b.txt');
    expect(desk.selected, {'b.txt'});
    // Com uma tecla depois do foco, o Ctrl é de verdade
    desk.handleKey(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.controlLeft,
        logicalKey: LogicalKeyboardKey.controlLeft,
        timeStamp: Duration.zero,
      ),
    );
    desk.press('a.txt');
    expect(desk.selected, {'a.txt', 'b.txt'});
  });

  test('um item que some sai da seleção e do renomear', () async {
    File(path('a.txt')).writeAsStringSync('');
    await desk.reload();
    desk.startRename('a.txt');
    File(path('a.txt')).deleteSync();
    await desk.reload();
    expect(desk.selected, isEmpty);
    expect(desk.renaming, isNull);
  });

  test('a dock na lateral tira o espaço daquele lado', () {
    state.settings.update(
      state.settings.value.copyWith(dockPosition: PsitoDockPosition.right),
    );
    expect(desk.insets.right, greaterThan(0));
    expect(desk.insets.bottom, 0);
  });

  group('a área de transferência', () {
    late Directory other;

    setUp(() async {
      other = await Directory.systemTemp.createTemp('psito_desk_outra_');
    });
    tearDown(() => other.delete(recursive: true));

    test('copiar oferece os selecionados, sem os fixos', () async {
      state.settings.update(
        state.settings.value.copyWith(desktopShowHome: true),
      );
      File(path('a.txt')).writeAsStringSync('a');
      await desk.reload();
      desk.key(LogicalKeyboardKey.keyA, ctrl: true);
      desk.key(LogicalKeyboardKey.keyC, ctrl: true);
      expect(clipboard.current.value, FileClip([path('a.txt')]));
    });

    test('colar traz para a mesa e seleciona, com um nome livre', () async {
      File('${other.path}/a.txt').writeAsStringSync('novo');
      File(path('a.txt')).writeAsStringSync('velho');
      await desk.reload();
      await clipboard.copy(['${other.path}/a.txt']);
      await desk.paste();
      expect(File(path('a.txt')).readAsStringSync(), 'velho');
      expect(File(path('a 2.txt')).readAsStringSync(), 'novo');
      expect(File('${other.path}/a.txt').existsSync(), isTrue);
      expect(desk.selected, {'a 2.txt'});
    });

    test('um recortado anda, fica apagado e só cola uma vez', () async {
      File(path('a.txt')).writeAsStringSync('a');
      await desk.reload();
      desk.press('a.txt');
      desk.copySelected(cut: true);
      expect(desk.isCut(item('a.txt')), isTrue);
      // Colar na mesma pasta não move nada, mas gasta o recortado
      await desk.paste();
      expect(File(path('a.txt')).existsSync(), isTrue);
      expect(clipboard.current.value, isNull);
      expect(desk.isCut(item('a.txt')), isFalse);

      File('${other.path}/b.txt').writeAsStringSync('b');
      await clipboard.copy(['${other.path}/b.txt'], cut: true);
      await desk.paste();
      expect(File(path('b.txt')).existsSync(), isTrue);
      expect(File('${other.path}/b.txt').existsSync(), isFalse);
      await desk.paste();
      expect(state.notifications.history, isEmpty);
    });
  });

  group('os menus', () {
    const at = Offset(1400, 60);

    List<String> labels() => [
      for (final item in state.deskMenu.value!.items) item.label,
    ];
    DockMenuItem option(String label) =>
        state.deskMenu.value!.items.firstWhere((i) => i.label == label);

    setUp(() {
      state.dockUi.screen = const Size(1440, 900);
      state.appsForType = (type) => type.isEmpty
          ? [
              const DesktopEntry(id: 'a', name: 'App A', command: ['a']),
              const DesktopEntry(id: 'b', name: 'App B', command: ['b']),
            ]
          : [
              const DesktopEntry(id: 'a', name: 'App A', command: ['a']),
            ];
    });

    test('a mesa vazia limpa a seleção, e o teclado fica onde está', () async {
      File(path('a.txt')).writeAsStringSync('');
      await desk.reload();
      desk.press('a.txt');
      await desk.openMenu(null, at);
      expect(desk.selected, isEmpty);
      expect(state.deskMenu.value!.title, 'Área de trabalho');
      expect(labels(), contains('Nova pasta'));
      expect(option('Colar').enabled, isFalse);
      expect(desk.menuOpen, isTrue);
      expect(
        surfaceCalls.last,
        isMethodCall('showOverlay', arguments: 'pointer'),
      );
      desk.closeMenu();
      expect(surfaceCalls.last, isMethodCall('hideOverlay', arguments: null));
    });

    test('o Colar conta o que está copiado', () async {
      await clipboard.copy(['/a', '/b']);
      await desk.openMenu(null, at);
      expect(labels(), contains('Colar 2 itens'));
      expect(option('Colar 2 itens').enabled, isTrue);
    });

    test('um item fora da seleção fica sozinho; dentro, ela fica', () async {
      for (final name in ['a.txt', 'b.txt', 'c.txt']) {
        File(path(name)).writeAsStringSync('');
      }
      await desk.reload();
      desk.key(LogicalKeyboardKey.keyA, ctrl: true);
      await desk.openMenu('a.txt', at);
      expect(state.deskMenu.value!.title, '3 itens');
      expect(labels(), isNot(contains('Renomear')));
      expect(labels(), containsAll(['Copiar', 'Mover para a lixeira']));
      desk.closeMenu();

      desk.press('a.txt', ctrl: false);
      desk.release('a.txt', ctrl: false);
      await desk.openMenu('b.txt', at);
      expect(desk.selected, {'b.txt'});
      expect(state.deskMenu.value!.title, 'b.txt');
      expect(
        labels(),
        containsAll(['Abrir', 'Abrir com…', 'Renomear', 'Fixar na Dock']),
      );
    });

    test('o Renomear abre o campo', () async {
      File(path('a.txt')).writeAsStringSync('');
      await desk.reload();
      await desk.openMenu('a.txt', at);
      option('Renomear').onTap();
      expect(desk.renaming, 'a.txt');
    });

    test('o Abrir com lista os apps, e o Outro lista todos', () async {
      File(path('a.txt')).writeAsStringSync('');
      await desk.reload();
      await desk.openMenu('a.txt', at);
      expect(option('Abrir com…').keepsOpen, isTrue);
      option('Abrir com…').onTap();
      expect(labels(), ['App A', 'Outro…']);
      option('Outro…').onTap();
      expect(labels(), ['App A', 'App B']);
      option('App B').onTap();
      await until(() => opened.isNotEmpty);
      expect(opened.single, [path('a.txt'), 'b']);
    });

    test('o Fixar na Dock some com o item já fixado', () async {
      File(path('a.txt')).writeAsStringSync('');
      await desk.reload();
      await desk.openMenu('a.txt', at);
      option('Fixar na Dock').onTap();
      await until(() => state.dock.contains(DockFile(path('a.txt'))));
      await desk.openMenu('a.txt', at);
      expect(labels(), isNot(contains('Fixar na Dock')));
    });

    test('a lixeira e o home têm só o que é deles', () async {
      state.settings.update(
        state.settings.value.copyWith(
          desktopShowHome: true,
          desktopShowTrash: true,
        ),
      );
      await desk.reload();
      await desk.openMenu(DeskItem.homeKey, at);
      expect(labels(), ['Abrir']);
      await desk.openMenu(DeskItem.trashKey, at);
      expect(labels(), ['Abrir']);
      state.dockUi.trashFull.value = true;
      await desk.openMenu(DeskItem.trashKey, at);
      option('Esvaziar a lixeira').onTap();
      expect(state.dockUi.askEmptyTrash.value, isTrue);
    });

    test('a nova pasta fica no clique, com o nome em edição', () async {
      await desk.reload();
      await desk.openMenu(null, const Offset(1300, 150));
      option('Nova pasta').onTap();
      await until(() => desk.renaming != null);
      // Da direita: 1440 - 1300 = 140, a coluna 1; 150 - a top bar, a linha 1
      expect(desk.cells[desk.renaming], isNot(const DeskCell(0, 0)));
      expect(desk.cells[desk.renaming]!.column, 1);
    });

    test('o documento vem do modelo, ou vazio', () async {
      final templates = await Directory.systemTemp.createTemp('psito_modelos_');
      addTearDown(() => templates.delete(recursive: true));
      File('${templates.path}/Carta.txt').writeAsStringSync('Prezado');
      File('${templates.path}/.oculto').writeAsStringSync('');
      final withTemplates = DeskController(
        state,
        dir: dir.path,
        home: '/home/x',
        mime: MimeDatabase.load(const []),
        store: DeskStore.memory(),
        userDirs: {UserDir.templates: templates.path},
        clipboard: clipboard,
      );
      addTearDown(withTemplates.dispose);
      withTemplates.setGrid(const DeskGrid(4, 3));
      await withTemplates.reload();
      await withTemplates.openMenu(null, at);
      option('Novo documento…').onTap();
      await until(() => labels().contains('Documento vazio'));
      expect(labels(), ['Documento vazio', 'Carta']);
      option('Carta').onTap();
      await until(() => withTemplates.renaming != null);
      expect(withTemplates.renaming, 'Carta.txt');
      expect(File(path('Carta.txt')).readAsStringSync(), 'Prezado');
      await withTemplates.newDocument();
      expect(File(path('Novo documento.txt')).lengthSync(), 0);
    });

    test('organizar por e limpar tiram os buracos', () async {
      File(path('b.txt')).writeAsStringSync('1234');
      File(path('a.txt')).writeAsStringSync('1');
      await desk.reload();
      await desk.store.put({'a.txt': const DeskCell(3, 2)});
      await desk.reload();
      desk.cleanUp();
      expect(desk.cells.values.toSet(), {
        const DeskCell(0, 0),
        const DeskCell(0, 1),
      });
      desk.arrangeBy(FsSortKey.size);
      expect(desk.cells['b.txt'], const DeskCell(0, 0));
      desk.arrangeBy(FsSortKey.name);
      expect(desk.cells['a.txt'], const DeskCell(0, 0));
      // Sobrevive ao reload
      await desk.reload();
      expect(desk.cells['a.txt'], const DeskCell(0, 0));
    });

    test('por nome, um atalho vale pelo nome que a mesa mostra', () async {
      File(path('z.desktop'))
          .writeAsStringSync('[Desktop Entry]\nName=Aaa\nExec=/nao/existe/x\n');
      File(path('b.txt')).writeAsStringSync('');
      Directory(path('pasta')).createSync();
      await desk.reload();
      desk.arrangeBy(FsSortKey.name);
      expect(desk.cells['pasta'], const DeskCell(0, 0));
      expect(desk.cells['z.desktop'], const DeskCell(0, 1));
      expect(desk.cells['b.txt'], const DeskCell(0, 2));
    });

    test('com o organizar sozinha, não tem o que organizar', () async {
      state.settings.update(
        state.settings.value.copyWith(desktopAutoArrange: true),
      );
      await desk.openMenu(null, at);
      expect(option('Limpar').enabled, isFalse);
    });

    test('abrir um painel fecha o menu', () async {
      await desk.openMenu(null, at);
      state.toggle(ShellOverlay.notifications);
      expect(desk.menuOpen, isFalse);
    });
  });

  group('o atalho de um app', () {
    late Directory apps;
    late DesktopEntry app;

    setUp(() async {
      apps = await Directory.systemTemp.createTemp('psito_apps_');
      File('${apps.path}/gimp.desktop').writeAsStringSync(_shortcut);
      app = DesktopEntry(
        id: 'gimp',
        name: 'GIMP',
        command: const ['/nao/existe/meu-app'],
        path: '${apps.path}/gimp.desktop',
      );
      state.apps.value = [app];
      state.dockUi.screen = const Size(1440, 900);
      state.desk.value = desk;
      await desk.reload();
    });
    tearDown(() => apps.delete(recursive: true));

    test('nasce executável, e abre o instalado', () async {
      await desk.createShortcut(app);
      final shortcut = item('gimp.desktop');
      expect(shortcut.entry!.executable, isTrue);
      expect(desk.selected, {'gimp.desktop'});
      desk.open('gimp.desktop');
      await until(() => launched.isNotEmpty);
      expect(launched.single, app);
    });

    test('do launcher para longe da dock, fica onde soltou', () async {
      state.dockUi.startDrag(
        const DockApp('gimp'),
        DockDragSource.launcher,
        Offset.zero,
      );
      state.dockUi.moveDrag(const Offset(1300, 150));
      await state.dockUi.endDrag();
      expect(desk.cells['gimp.desktop']!.column, 1);
    });

    test('um segundo atalho só move o primeiro', () async {
      await desk.createShortcut(app);
      await desk.createShortcut(app, at: const Offset(1300, 150));
      expect(desk.items.where((i) => i.shortcut != null), hasLength(1));
      expect(desk.cells['gimp.desktop']!.column, 1);
    });

    test('a célula ocupada deixa o de lá e cai na do lado', () async {
      File(path('a.txt')).writeAsStringSync('');
      await desk.reload();
      final taken = desk.cells['a.txt']!;
      await desk.createShortcut(app, at: const Offset(1430, 50));
      expect(desk.cells['a.txt'], taken);
      expect(desk.cells['gimp.desktop'], isNot(taken));
    });

    test('com os ícones desligados, não cria', () async {
      state.settings.update(
        state.settings.value.copyWith(desktopShowIcons: false),
      );
      await desk.createShortcut(app);
      expect(File(path('gimp.desktop')).existsSync(), isFalse);
    });
  });

  group('arrastar e soltar', () {
    late Directory fora;
    const at = Offset(1440 - 104 - 10, TopBar.height + 10);

    setUp(() async {
      fora = await Directory.systemTemp.createTemp('psito_fora_');
      state.dockUi.screen = const Size(1440, 900);
      state.dockUi.trash = Trash('${dir.path}/.lixo');
    });

    tearDown(() => fora.delete(recursive: true));

    Future<String> arquivoFora(String name) async {
      final file = File('${fora.path}/$name')..writeAsStringSync(name);
      return file.path;
    }

    test('mover na mesa salva a célula, e vários andam juntos', () async {
      File(path('a.txt')).writeAsStringSync('');
      File(path('b.txt')).writeAsStringSync('');
      await desk.reload();
      desk.moveKeys('a.txt', {'a.txt', 'b.txt'}, at);
      expect(desk.cells['a.txt'], const DeskCell(1, 0));
      expect(desk.cells['b.txt'], const DeskCell(1, 1));
      expect(desk.store.cells['b.txt'], const DeskCell(1, 1));
    });

    test('organizando sozinha, mover desliga e o resto fica', () async {
      File(path('a.txt')).writeAsStringSync('');
      File(path('b.txt')).writeAsStringSync('');
      await desk.reload();
      state.settings.update(
        state.settings.value.copyWith(desktopAutoArrange: true),
      );
      final before = desk.cells['b.txt'];
      desk.moveKeys('a.txt', {'a.txt'}, at);
      expect(state.settings.value.desktopAutoArrange, isFalse);
      expect(desk.cells['a.txt'], const DeskCell(1, 0));
      expect(desk.cells['b.txt'], before);
      expect(desk.store.cells['b.txt'], before);
      // O Ctrl+Z volta a organizar
      await desk.undo();
      expect(state.settings.value.desktopAutoArrange, isTrue);
      expect(desk.cells['a.txt'], const DeskCell(0, 0));
    });

    test('começar a arrastar fora da seleção deixa só ele', () async {
      File(path('a.txt')).writeAsStringSync('');
      File(path('b.txt')).writeAsStringSync('');
      await desk.reload();
      desk.press('b.txt');
      desk.dragStarted('a.txt');
      expect(desk.selected, {'a.txt'});
      desk.press('a.txt');
      desk.selectRect({'a.txt', 'b.txt'});
      desk.dragStarted('a.txt');
      expect(desk.selected, {'a.txt', 'b.txt'});
    });

    test('um arquivo de fora copia para a célula do soltar', () async {
      final source = await arquivoFora('c.txt');
      expect(await desk.drop(null, [source], DropAction.copy, at: at), isTrue);
      await until(() => desk.selected.contains('c.txt'));
      expect(File(source).existsSync(), isTrue);
      expect(desk.cells['c.txt'], const DeskCell(1, 0));
      expect(desk.store.cells['c.txt'], const DeskCell(1, 0));
    });

    test('mover tira do lugar de origem', () async {
      final source = await arquivoFora('c.txt');
      await desk.drop(null, [source], DropAction.move, at: at);
      await until(() => desk.selected.contains('c.txt'));
      expect(File(source).existsSync(), isFalse);
      expect(File(path('c.txt')).existsSync(), isTrue);
    });

    test('o nome que já existe fica com os dois, na célula certa', () async {
      File(path('c.txt')).writeAsStringSync('antigo');
      await desk.reload();
      final source = await arquivoFora('c.txt');
      await desk.drop(null, [source], DropAction.copy, at: at);
      await until(() => desk.selected.length == 1);
      expect(File(path('c.txt')).readAsStringSync(), 'antigo');
      final novo = desk.selected.single;
      expect(novo, isNot('c.txt'));
      expect(desk.cells[novo], const DeskCell(1, 0));
    });

    test('quem já está na mesa só muda de célula', () async {
      File(path('a.txt')).writeAsStringSync('a');
      await desk.reload();
      await desk.drop(null, [path('a.txt')], DropAction.copy, at: at);
      expect(desk.cells['a.txt'], const DeskCell(1, 0));
      expect(desk.items.where((i) => i.entry != null).length, 1);
    });

    test('a ação diz copiar até saber que é o mesmo disco', () async {
      final source = await arquivoFora('c.txt');
      expect(desk.dropAction(null, [source]), DropAction.copy);
      await until(() => desk.dropAction(null, [source]) == DropAction.move);
      expect(desk.dropAction(null, ['/proc/self']), DropAction.copy);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(desk.dropAction(null, ['/proc/self']), DropAction.copy);
    });

    test('a mesa não aceita a pasta em que ela mesma está', () {
      expect(desk.dropAction(null, [dirName(dir.path)]), isNull);
      expect(desk.dropAction(null, [dir.path]), isNull);
      expect(desk.dropAction(null, const []), isNull);
    });

    test('soltar numa pasta leva para dentro, e ela não recebe a si', () async {
      Directory(path('p')).createSync();
      File(path('a.txt')).writeAsStringSync('a');
      await desk.reload();
      expect(desk.canDropOn('p', {'a.txt'}), isTrue);
      expect(desk.canDropOn('p', {'p'}), isFalse);
      expect(desk.canDropOn('a.txt', {'p'}), isFalse);
      desk.dropOn('p', {'a.txt'});
      await until(() => File(path('p/a.txt')).existsSync());
      expect(File(path('a.txt')).existsSync(), isFalse);
    });

    test('o Ctrl+Z desfaz o mover na mesa', () async {
      File(path('a.txt')).writeAsStringSync('');
      await desk.reload();
      desk.moveKeys('a.txt', {'a.txt'}, at);
      expect(desk.cells['a.txt'], const DeskCell(1, 0));
      expect(desk.undoLabel, 'Mover');
      desk.key(LogicalKeyboardKey.keyZ, ctrl: true);
      await until(() => desk.cells['a.txt'] == const DeskCell(0, 0));
      expect(desk.store.cells['a.txt'], const DeskCell(0, 0));
      expect(desk.canUndo, isFalse);
    });

    test('desfazer o que veio de fora tira da mesa', () async {
      final copied = await arquivoFora('c.txt');
      await desk.drop(null, [copied], DropAction.copy, at: at);
      await until(() => desk.canUndo);
      await desk.undo();
      expect(File(path('c.txt')).existsSync(), isFalse);
      expect(File(copied).existsSync(), isTrue);
      expect(desk.items.any((i) => i.key == 'c.txt'), isFalse);

      final moved = await arquivoFora('d.txt');
      await desk.drop(null, [moved], DropAction.move, at: at);
      await until(() => desk.canUndo);
      await desk.undo();
      expect(File(path('d.txt')).existsSync(), isFalse);
      expect(File(moved).existsSync(), isTrue);
    });

    test('desfazer traz da pasta para a mesma célula', () async {
      Directory(path('p')).createSync();
      File(path('a.txt')).writeAsStringSync('a');
      await desk.reload();
      desk.moveKeys('a.txt', {'a.txt'}, at);
      desk.dropOn('p', {'a.txt'});
      await until(() => File(path('p/a.txt')).existsSync() && desk.canUndo);
      await until(() => desk.undoLabel != 'Mover' || desk.items.length == 1);
      await desk.undo();
      expect(File(path('a.txt')).existsSync(), isTrue);
      expect(desk.cells['a.txt'], const DeskCell(1, 0));
    });

    test('desfazer tira da lixeira, na mesma célula', () async {
      File(path('a.txt')).writeAsStringSync('a');
      await desk.reload();
      desk.moveKeys('a.txt', {'a.txt'}, at);
      await desk.drop(DeskItem.trashKey, [path('a.txt')], DropAction.move);
      expect(File(path('a.txt')).existsSync(), isFalse);
      await desk.undo();
      expect(File(path('a.txt')).existsSync(), isTrue);
      expect(desk.cells['a.txt'], const DeskCell(1, 0));
    });

    test('renomear, a pasta nova e o Limpar também desfazem', () async {
      File(path('a.txt')).writeAsStringSync('a');
      File(path('b.txt')).writeAsStringSync('b');
      await desk.reload();
      await desk.rename('a.txt', 'z.txt');
      await desk.undo();
      expect(File(path('a.txt')).existsSync(), isTrue);
      expect(File(path('z.txt')).existsSync(), isFalse);

      await desk.newFolder();
      desk.stopRename();
      expect(Directory(path('Nova pasta')).existsSync(), isTrue);
      await desk.undo();
      expect(Directory(path('Nova pasta')).existsSync(), isFalse);

      desk.moveKeys('b.txt', {'b.txt'}, at);
      final before = desk.cells['b.txt'];
      desk.cleanUp();
      expect(desk.cells['b.txt'], isNot(before));
      await desk.undo();
      expect(desk.cells['b.txt'], before);
    });

    test('o menu da mesa mostra o que desfaz', () async {
      File(path('a.txt')).writeAsStringSync('');
      await desk.reload();
      await desk.openMenu(null, at);
      DockMenuItem option() => state.deskMenu.value!.items.firstWhere(
        (i) => i.label.startsWith('Desfazer'),
      );
      expect(option().enabled, isFalse);
      desk.moveKeys('a.txt', {'a.txt'}, at);
      await desk.openMenu(null, at);
      expect(option().label, 'Desfazer Mover');
      expect(option().enabled, isTrue);
    });

    test('a cópia aparece na top bar, e a rápida não', () async {
      final seen = <String?>[];
      void listener() => seen.add(state.deskTransfer.value?.text);
      state.deskTransfer.addListener(listener);
      addTearDown(() => state.deskTransfer.removeListener(listener));
      await desk.drop(null, [await arquivoFora('c.txt')], DropAction.copy);
      await until(() => desk.selected.contains('c.txt'));
      expect(seen, isEmpty);

      final slow = DeskController(
        state,
        dir: dir.path,
        home: '/home/x',
        mime: MimeDatabase.load(const []),
        store: DeskStore.memory(),
        clipboard: clipboard,
        jobDelay: Duration.zero,
      )..setGrid(const DeskGrid(4, 3));
      addTearDown(slow.dispose);
      await slow.drop(null, [await arquivoFora('d.txt')], DropAction.copy);
      await until(() => slow.selected.contains('d.txt'));
      expect(seen.first, startsWith('Copiando'));
      expect(seen.last, isNull);
      expect(state.deskTransfer.value, isNull);
    });

    test('soltar na lixeira joga fora', () async {
      File(path('a.txt')).writeAsStringSync('a');
      await desk.reload();
      expect(desk.canDropOn(DeskItem.trashKey, {'a.txt'}), isTrue);
      await desk.drop(DeskItem.trashKey, [path('a.txt')], DropAction.move);
      expect(File(path('a.txt')).existsSync(), isFalse);
      expect(
        File('${state.dockUi.trash!.filesDir}/a.txt').existsSync(),
        isTrue,
      );
    });

    test('o home e a lixeira não saem da mesa', () async {
      state.settings.update(
        state.settings.value.copyWith(
          desktopShowHome: true,
          desktopShowTrash: true,
        ),
      );
      await desk.reload();
      expect(desk.canDropOn('a.txt', {DeskItem.homeKey}), isFalse);
      expect(desk.canDropOn(DeskItem.trashKey, {DeskItem.homeKey}), isFalse);
    });

    test('um atalho abre no app dele só o que ele aceita', () async {
      File(path('gimp.desktop')).writeAsStringSync(_shortcut);
      state.apps.value = [
        DesktopEntry(
          id: 'gimp',
          name: 'GIMP',
          command: const ['/nao/existe/meu-app'],
        ),
      ];
      state.dockUi.appAccepts = (id, paths) => paths.first.endsWith('.png');
      await desk.reload();
      expect(desk.acceptsDrops('gimp.desktop'), isTrue);
      expect(desk.dropAction('gimp.desktop', ['/tmp/x.txt']), isNull);
      expect(desk.dropAction('gimp.desktop', ['/tmp/x.png']), DropAction.copy);
      await desk.drop('gimp.desktop', ['/tmp/x.png'], DropAction.copy);
      expect(opened.single, ['/tmp/x.png', 'gimp']);
    });
  });

  group('os discos', () {
    late FakeDisksService disks;
    var locked = false;

    const pendrive = PsitoVolume(
      id: '/d/sdb1',
      label: 'PENDRIVE',
      device: '/dev/sdb1',
      drive: 'sdb',
      canEject: true,
      autoMount: true,
    );
    final key = DeskItem.volumeKey(pendrive.id);

    setUp(() async {
      disks = state.services.disks as FakeDisksService;
      locked = false;
      state.sessionLocked = () async => locked;
      await state.services.ready;
      await Future<void>.delayed(Duration.zero);
    });

    Future<void> plug([PsitoVolume volume = pendrive]) async {
      disks.volumes.value = [...disks.volumes.value, volume];
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('um disco ligado aparece na mesa, e sai quando tiram', () async {
      await plug();
      expect(item(key).name, 'PENDRIVE');
      disks.volumes.value = const [];
      expect(desk.items.where((i) => i.key == key), isEmpty);
    });

    test('sem nome, usa o genérico', () async {
      await plug(const PsitoVolume(id: '/d/x', label: '', device: '/dev/sdc1'));
      expect(item(DeskItem.volumeKey('/d/x')).name, 'Disco externo');
    });

    test('a configuração esconde', () async {
      await plug();
      await state.settings.update(
        state.settings.value.copyWith(desktopShowVolumes: false),
      );
      expect(desk.items.where((i) => i.key == key), isEmpty);
    });

    test('ao ligar, monta e avisa', () async {
      await plug();
      await until(() => state.notifications.history.isNotEmpty);
      expect(disks.volumes.value.single.mountPoint, isNotNull);
      final notice = state.notifications.history.single;
      expect(notice.title, 'PENDRIVE');
      expect(notice.body, 'Disco ligado. Clique para abrir.');
    });

    test('o clique no aviso abre onde montou', () async {
      await plug();
      await until(() => state.notifications.history.isNotEmpty);
      state.notifications.history.single.onOpen!();
      await until(() => opened.isNotEmpty);
      expect(opened.single, [disks.volumes.value.single.mountPoint]);
    });

    test('com a tela bloqueada, não monta nem avisa', () async {
      locked = true;
      await plug();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(disks.volumes.value.single.mountPoint, isNull);
      expect(state.notifications.history, isEmpty);
    });

    test('o que o sistema não indica montar não monta, mas avisa', () async {
      await plug(
        const PsitoVolume(id: '/d/y', label: 'DADOS', device: '/dev/sdd1'),
      );
      await until(() => state.notifications.history.isNotEmpty);
      expect(disks.volumes.value.single.mountPoint, isNull);
    });

    test('um trancado não monta', () async {
      await plug(
        const PsitoVolume(
          id: '/d/z',
          label: 'COFRE',
          device: '/dev/sde1',
          locked: true,
          autoMount: true,
        ),
      );
      await until(() => state.notifications.history.isNotEmpty);
      expect(disks.volumes.value.single.mountPoint, isNull);
      expect(
        state.notifications.history.single.body,
        'Este disco é criptografado.',
      );
    });

    test('abrir monta e pede ao Files', () async {
      locked = true;
      await plug();
      locked = false;
      desk.open(key);
      await until(() => opened.isNotEmpty);
      expect(disks.volumes.value.single.mountPoint, isNotNull);
      expect(opened.single, [disks.volumes.value.single.mountPoint]);
    });

    test('o menu tem ejetar, que diz quando dá para tirar', () async {
      locked = true;
      await plug();
      await desk.openMenu(key, Offset.zero);
      final items = state.deskMenu.value!.items;
      expect(items.map((i) => i.label), ['Abrir', 'Ejetar']);
      items.last.onTap();
      await until(() => state.notifications.history.isNotEmpty);
      expect(disks.volumes.value, isEmpty);
      expect(state.notifications.history.single.body, 'Já pode tirar o disco.');
    });

    test('um disco em uso avisa e fica', () async {
      locked = true;
      await plug();
      disks.answer = PsitoDiskResult.busy;
      await state.ejectVolume(pendrive);
      expect(disks.volumes.value, hasLength(1));
      expect(state.notifications.history.single.body, contains('em uso'));
    });

    test('diz quem está usando', () async {
      locked = true;
      await plug();
      disks.answer = PsitoDiskResult.busy;
      disks.users = ['foot'];
      await state.ejectVolume(pendrive);
      expect(state.notifications.history.single.body, contains('foot'));
    });

    test('ejetar rápido não avisa que está gravando', () async {
      locked = true;
      await plug();
      await state.ejectVolume(pendrive);
      await Future<void>.delayed(Duration.zero);
      expect(state.notifications.history.map((n) => n.body), [
        'Já pode tirar o disco.',
      ]);
    });

    test('puxar o cabo de um montado avisa', () async {
      locked = true;
      await plug(pendrive.copyWith(mountPoint: () => '/media/x/PENDRIVE'));
      disks.volumes.value = const [];
      expect(state.notifications.history.single.body, contains('sem ejetar'));
    });

    test('um disco que já foi desmontado sai sem aviso', () async {
      locked = true;
      await plug();
      disks.volumes.value = const [];
      expect(state.notifications.history, isEmpty);
    });

    test('só recebe arquivo depois de montado, e copia', () async {
      File(path('a.txt')).writeAsStringSync('a');
      final inside = Directory(path('dentro'))..createSync();
      await desk.reload();
      locked = true;
      await plug();
      expect(desk.acceptsDrops(key), isFalse);
      disks.volumes.value = [pendrive.copyWith(mountPoint: () => inside.path)];
      expect(desk.acceptsDrops(key), isTrue);
      desk.dropOn(key, {'a.txt'});
      await until(() => File('${inside.path}/a.txt').existsSync());
      // O original fica na mesa
      expect(File(path('a.txt')).existsSync(), isTrue);
    });
  });
}
