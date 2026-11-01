import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_desktop/psito_desktop.dart';
import 'package:psito_dock/psito_dock.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/system_services.dart';
import 'package:psito_shell/desk.dart';
import 'package:psito_shell/desktop_entries.dart';
import 'package:psito_shell/shell_state.dart';
import 'package:psito_shell/surfaces.dart';
import 'package:psito_shell/toplevels.dart';
import 'package:system_shell/shell/settings_store.dart';

const _surfaces = MethodChannel('psito_test/desk_surfaces');
const _toplevels = MethodChannel('psito_test/desk_toplevels');

const _shortcut = '''
[Desktop Entry]
Type=Application
Name=Meu app
Name[pt_BR]=Meu programa
Exec=/nao/existe/meu-app
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late ShellState state;
  late DeskController desk;
  late List<List<String>> opened;

  String path(String name) => '${dir.path}/$name';
  DeskItem item(String key) => desk.items.firstWhere((i) => i.key == key);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('psito_desk_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_surfaces, (_) async => null);
    messenger.setMockMethodCallHandler(_toplevels, (_) async => null);
    state = ShellState(
      settings: SettingsStore.memory(),
      services: SystemServices.fake(),
      toplevels: ToplevelList(channel: _toplevels),
      surfaces: const Surfaces(_surfaces),
      dock: DockStore.memory(),
    );
    opened = [];
    state.openPaths = (paths, {withApp}) async => opened.add(paths);
    desk = DeskController(
      state,
      dir: dir.path,
      home: '/home/x',
      mime: MimeDatabase.load(const []),
      store: DeskStore.memory(),
      env: const {'LANG': 'pt_BR.UTF-8', 'PATH': '/nao/existe'},
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

    test('sem o +x não abre, e avisa', () async {
      File(path('meu.desktop')).writeAsStringSync(_shortcut);
      await desk.reload();
      desk.open('meu.desktop');
      expect(state.notifications.history.single.title, 'Atalho não confiável');
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
}
