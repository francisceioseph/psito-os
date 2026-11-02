import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_dock/psito_dock.dart';
import 'package:psito_fs/psito_fs.dart';
import 'package:psito_runtime/psito_runtime.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/system_services.dart';
import 'package:psito_shell/autostart.dart';
import 'package:psito_shell/desktop_entries.dart';
import 'package:psito_shell/dock.dart';
import 'package:psito_shell/notifications_server.dart';
import 'package:psito_shell/shell_state.dart';
import 'package:psito_shell/surfaces.dart';
import 'package:psito_shell/toplevels.dart';
import 'package:system_shell/shell/settings_store.dart';
import 'package:system_shell/widgets/dock_menu.dart';
import 'package:system_shell/widgets/psito_dock.dart';

const _toplevels = MethodChannel('test/dock-toplevels');
const _surfaces = MethodChannel('test/dock-surfaces');

DesktopEntry _app(String id) =>
    DesktopEntry(id: id, name: id.toUpperCase(), command: [id]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late ShellState state;
  late DockController ui;
  late List<MethodCall> surfaceCalls;
  late List<MethodCall> toplevelCalls;
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('psito_dock_shell_');
    surfaceCalls = [];
    toplevelCalls = [];
    messenger.setMockMethodCallHandler(_toplevels, (call) async {
      toplevelCalls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(_surfaces, (call) async {
      surfaceCalls.add(call);
      return null;
    });
    state = ShellState(
      settings: SettingsStore.memory(),
      services: SystemServices.fake(),
      toplevels: ToplevelList(channel: _toplevels),
      surfaces: Surfaces(_surfaces),
      dock: DockStore.memory(const [
        DockApp('foot'),
        DockApp('firefox-esr'),
        DockApp('org.psito.files'),
      ]),
      autostart: Autostart({
        'HOME': tmp.path,
        'XDG_CONFIG_DIRS': '${tmp.path}/xdg',
      }),
    );
    state.apps.value = [
      for (final id in ['foot', 'firefox-esr', 'org.psito.files', 'gimp'])
        _app(id),
    ];
    ui = state.dockUi
      ..screen = const Size(1440, 900)
      ..surface = const Size(400, 100);
  });
  tearDown(() => tmp.delete(recursive: true));

  List<String> ids() => [for (final item in state.dock.value) item.toString()];

  /// O centro do ícone [index] da fileira de agora.
  Offset at(int index, {double y = 850}) {
    final row = ui.row;
    final centers = PsitoDock.centers(
      count: row.items.length,
      separators: row.separators,
      iconSize: 52,
      centerX: 720,
    );
    return Offset(centers[index], y);
  }

  test('arrastar dentro da dock muda a ordem', () async {
    ui.startDrag(const DockApp('org.psito.files'), DockDragSource.dock, at(3));
    // O arrastado sai da fileira; antes do primeiro, abre o espaço no 1,
    // depois do "Apps", mesmo com o ponteiro em cima dele
    expect(ui.row.items.map((i) => i.item), const [
      DockLauncher(),
      DockApp('foot'),
      DockApp('firefox-esr'),
      DockTrash(),
    ]);
    ui.moveDrag(at(0));
    expect(ui.dropIndex(ui.row, ui.drag.value!), 1);
    ui.moveDrag(at(1) - const Offset(10, 0));
    expect(ui.dropIndex(ui.row, ui.drag.value!), 1);
    await ui.endDrag();
    expect(ids(), [
      'DockApp(org.psito.files)',
      'DockApp(foot)',
      'DockApp(firefox-esr)',
    ]);
    expect(ui.drag.value, isNull);
  });

  test('soltar longe da dock tira o item', () async {
    ui.startDrag(const DockApp('foot'), DockDragSource.dock, at(1));
    ui.moveDrag(const Offset(720, 400));
    expect(ui.dropIndex(ui.row, ui.drag.value!), isNull);
    await ui.endDrag();
    expect(ids(), ['DockApp(firefox-esr)', 'DockApp(org.psito.files)']);
  });

  test('do launcher, soltar sobre a dock fixa no lugar', () async {
    state.toggle(ShellOverlay.launcher);
    ui.startDrag(const DockApp('gimp'), DockDragSource.launcher, Offset.zero);
    // O launcher fecha, mas a sobreposição fica com o ponteiro
    expect(state.overlay.value, isNull);
    expect(
      surfaceCalls.last,
      isMethodCall('showOverlay', arguments: 'exclusive'),
    );
    ui.moveDrag(at(2) + const Offset(10, 0));
    await ui.endDrag();
    expect(ids(), [
      'DockApp(foot)',
      'DockApp(firefox-esr)',
      'DockApp(gimp)',
      'DockApp(org.psito.files)',
    ]);
    expect(surfaceCalls.last, isMethodCall('hideOverlay', arguments: null));

    // Soltar longe não faz nada com o que veio do launcher
    ui.startDrag(const DockApp('foot'), DockDragSource.launcher, Offset.zero);
    ui.moveDrag(const Offset(100, 100));
    await ui.endDrag();
    expect(state.dock.value.length, 4);
  });

  test('o arrastar da dock só desenha na sobreposição', () {
    ui.startDrag(const DockApp('foot'), DockDragSource.dock, at(0));
    expect(
      surfaceCalls.last,
      isMethodCall('showOverlay', arguments: 'passive'),
    );
    ui.cancelDrag();
    expect(surfaceCalls.last, isMethodCall('hideOverlay', arguments: null));
    expect(ids().first, 'DockApp(foot)');
  });

  test(
    'pastas e arquivos soltos viram itens, depois de um separador',
    () async {
      final folder = Directory('${tmp.path}/Projetos')..createSync();
      final file = File('${tmp.path}/nota.txt')..writeAsStringSync('oi');
      expect(await ui.dropPaths([folder.path, file.path]), isTrue);
      expect(state.dock.value.skip(3), [
        DockFolder(folder.path),
        DockFile(file.path),
      ]);
      final row = ui.row;
      expect(row.separators, {4});
      expect(row.paths, 4);

      // Uma pasta arrastada só cai entre as pastas e os arquivos
      ui.startDrag(DockFile(file.path), DockDragSource.dock, at(5));
      ui.moveDrag(at(0));
      expect(ui.dropIndex(ui.row, ui.drag.value!), 4);
    },
  );

  test('o menu de um app fixado, de um aberto e de uma pasta', () async {
    await state.toplevels.handle(
      const MethodCall('changed', {'id': 1, 'appId': 'gimp', 'title': 'x'}),
    );
    // O traço marca o começo de um grupo, e o asterisco, a marca
    List<String> labels(DockItem item) => [
      for (final entry in ui.menuItems(item))
        '${entry.separated ? '- ' : ''}${entry.label}'
            '${entry.checked == true ? ' *' : ''}',
    ];
    DockMenuItem option(DockItem item, String label) =>
        ui.menuItems(item).firstWhere((entry) => entry.label == label);
    expect(labels(const DockApp('foot')), [
      'Abrir',
      '- Abrir ao iniciar a sessão',
      'Remover da Dock',
    ]);
    expect(labels(const DockApp('gimp')), [
      'x',
      '- Nova janela',
      '- Abrir ao iniciar a sessão',
      'Manter na Dock',
      '- Ocultar',
      'Fechar',
    ]);
    expect(labels(const DockFolder('/home/u/Downloads')), [
      'Abrir no Files',
      'Mostrar no Files',
      'Manter na Dock',
    ]);

    option(const DockApp('gimp'), 'Manter na Dock').onTap();
    expect(state.dock.contains(const DockApp('gimp')), isTrue);
    option(const DockApp('gimp'), 'x').onTap();
    expect(toplevelCalls.last, isMethodCall('activate', arguments: 1));
    option(const DockApp('gimp'), 'Fechar').onTap();
    expect(toplevelCalls.last, isMethodCall('close', arguments: 1));

    // O autostart grava no ~/.config/autostart
    option(const DockApp('foot'), 'Abrir ao iniciar a sessão').onTap();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(labels(const DockApp('foot'))[1], '- Abrir ao iniciar a sessão *');
  });

  test('o menu abre na tela, e abrir um painel fecha o menu', () {
    ui.openMenu(const DockApp('foot'), const Rect.fromLTWH(30, 20, 52, 52));
    expect(ui.menu.value!.anchor, const Rect.fromLTWH(550, 820, 52, 52));
    expect(
      surfaceCalls.last,
      isMethodCall('showOverlay', arguments: 'on_demand'),
    );
    state.toggle(ShellOverlay.volume);
    expect(ui.menu.value, isNull);
  });

  test('clicar numa pasta abre no app padrão', () {
    final opened = <List<String>>[];
    state.openPaths = (paths, {withApp}) async => opened.add(paths);
    ui.tap(const DockFolder('/home/u/Downloads'));
    ui.menuItems(const DockFile('/home/u/a/b.txt'))[1].onTap();
    expect(opened, [
      ['/home/u/Downloads'],
      ['/home/u/a'],
    ]);
  });

  test('a lixeira fica no fim, e uma pasta cai antes dela', () async {
    final folder = Directory('${tmp.path}/Projetos')..createSync();
    await ui.dropPaths([folder.path]);
    final row = ui.row;
    expect(row.items.map((i) => i.item).skip(4), [
      DockFolder(folder.path),
      const DockTrash(),
    ]);
    expect(row.separators, {4});

    // Depois da lixeira, ainda cai antes dela
    ui.startDrag(DockFolder(folder.path), DockDragSource.dock, at(4));
    ui.moveDrag(at(4) + const Offset(60, 0));
    expect(ui.dropIndex(ui.row, ui.drag.value!), 4);
    ui.cancelDrag();

    // A lixeira não sai do lugar
    ui.startDrag(const DockTrash(), DockDragSource.dock, at(5));
    expect(ui.drag.value, isNull);
    await state.dock.pin(const DockTrash());
    expect(state.dock.value.length, 4);
  });

  test('o "Apps" é o primeiro, fixo, e abre a lista de apps', () async {
    expect(ui.row.items.first.item, const DockLauncher());
    // Sem apps abertos, nenhum separador logo depois dele
    expect(ui.row.separators, {4});

    ui.tap(const DockLauncher());
    expect(state.overlay.value, ShellOverlay.launcher);
    ui.tap(const DockLauncher());
    expect(state.overlay.value, isNull);

    // Não sai do lugar, não vai para o dock.json e não tem menu
    ui.startDrag(const DockLauncher(), DockDragSource.dock, at(0));
    expect(ui.drag.value, isNull);
    await state.dock.pin(const DockLauncher());
    expect(state.dock.contains(const DockLauncher()), isFalse);
    ui.openMenu(const DockLauncher(), Rect.zero);
    expect(ui.menu.value, isNull);
    expect(ui.dropAction(const DockLauncher(), ['/a.txt']), isNull);
  });

  test('uma pasta ou um arquivo que sumiu fica escondido', () async {
    final folder = Directory('${tmp.path}/Some')..createSync();
    await ui.dropPaths([folder.path]);
    expect(ui.row.items.length, 6);
    folder.deleteSync();
    expect(ui.row.items.length, 5);
    expect(state.dock.contains(DockFolder(folder.path)), isTrue);
  });

  test('clicar numa pasta abre a pilha, os mais novos primeiro', () async {
    final folder = Directory('${tmp.path}/Downloads')..createSync();
    final old = File('${folder.path}/velho.txt')..writeAsStringSync('a');
    old.setLastModifiedSync(DateTime(2020));
    File('${folder.path}/novo.txt')
      ..writeAsStringSync('b')
      ..setLastModifiedSync(DateTime(2100));
    File('${folder.path}/.oculto').writeAsStringSync('c');
    // A pasta é de agora: entre os dois
    Directory('${folder.path}/sub').createSync();

    await ui.openStack(
      DockFolder(folder.path),
      const Rect.fromLTWH(0, 20, 52, 52),
    );
    final stack = ui.stack.value!;
    expect(stack.anchor.topLeft, const Offset(520, 820));
    expect(stack.entries, [
      DockFile('${folder.path}/novo.txt'),
      DockFolder('${folder.path}/sub'),
      DockFile('${folder.path}/velho.txt'),
    ]);
    expect(
      surfaceCalls.last,
      isMethodCall('showOverlay', arguments: 'on_demand'),
    );

    // Abrir o launcher fecha a pilha
    state.toggle(ShellOverlay.launcher);
    expect(ui.stack.value, isNull);
  });

  group('a lixeira', () {
    setUp(() => ui.trash = Trash('${tmp.path}/Trash'));

    test('soltar leva para a lixeira, e o ícone enche', () async {
      final file = File('${tmp.path}/lixo.txt')..writeAsStringSync('x');
      expect(ui.dropAction(const DockTrash(), [file.path]), DropAction.move);
      expect(await ui.dropOn(const DockTrash(), [file.path]), isTrue);
      expect(file.existsSync(), isFalse);
      expect(ui.trashFull.value, isTrue);
      expect(ui.menuItems(const DockTrash()).map((item) => item.label), [
        'Abrir',
        'Esvaziar a lixeira',
      ]);
    });

    test('esvaziar pergunta antes', () async {
      final file = File('${tmp.path}/lixo.txt')..writeAsStringSync('x');
      await ui.dropOn(const DockTrash(), [file.path]);
      ui.menuItems(const DockTrash())[1].onTap();
      expect(ui.askEmptyTrash.value, isTrue);
      expect(
        surfaceCalls.last,
        isMethodCall('showOverlay', arguments: 'exclusive'),
      );
      await ui.emptyTrash();
      expect(ui.trashFull.value, isFalse);
      expect(Directory('${tmp.path}/Trash/files').listSync(), isEmpty);
      expect(ui.menuItems(const DockTrash()).map((item) => item.label), [
        'Abrir',
      ]);
    });

    test('clicar abre a pasta da lixeira no Files', () async {
      final opened = <List<String>>[];
      state.openPaths = (paths, {withApp}) async => opened.add(paths);
      ui.tap(const DockTrash());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(opened, [
        ['${tmp.path}/Trash/files'],
      ]);
    });
  });

  test('soltar sobre um app abre nele, se ele abre o tipo', () async {
    final opened = <(List<String>, String?)>[];
    state.openPaths = (paths, {withApp}) async => opened.add((paths, withApp));
    ui.appAccepts = (id, paths) => id == 'foot';
    expect(ui.dropAction(const DockApp('foot'), ['/a.txt']), DropAction.copy);
    expect(ui.dropAction(const DockApp('firefox-esr'), ['/a.txt']), isNull);
    // Sem o .desktop, não há com que abrir
    ui.appAccepts = (id, paths) => true;
    expect(ui.dropAction(const DockApp('sumiu'), ['/a.txt']), isNull);
    expect(ui.dropAction(const DockFolder('/x'), ['/a.txt']), isNull);

    expect(await ui.dropOn(const DockApp('foot'), ['/a.txt']), isTrue);
    expect(opened.single.$1, ['/a.txt']);
    expect(opened.single.$2, 'foot');
  });

  Future<void> window(int id, String appId, {bool activated = false}) =>
      state.toplevels.handle(
        MethodCall('changed', {
          'id': id,
          'appId': appId,
          'title': '$appId $id',
          'activated': activated,
        }),
      );

  test('o menu de um app com várias janelas e as ações do .desktop', () async {
    state.apps.value = [
      DesktopEntry(
        id: 'firefox-esr',
        name: 'Firefox',
        command: ['firefox'],
        actions: [
          DesktopAction('new-window', 'Nova janela do Firefox', [
            'firefox',
            '--new-window',
          ]),
          DesktopAction('private', 'Janela privativa', ['firefox', '-p']),
        ],
      ),
    ];
    await window(1, 'firefox-esr');
    await window(2, 'firefox-esr', activated: true);
    expect(
      [
        for (final entry in ui.menuItems(const DockApp('firefox-esr')))
          entry.label,
      ],
      [
        'firefox-esr 2',
        'firefox-esr 1',
        'Nova janela',
        'Janela privativa',
        'Abrir ao iniciar a sessão',
        'Remover da Dock',
        'Ocultar',
        'Fechar 2 janelas',
      ],
    );
    expect(ui.menuItems(const DockApp('firefox-esr')).first.checked, isTrue);

    // Ocultar minimiza as duas
    ui
        .menuItems(const DockApp('firefox-esr'))
        .firstWhere((entry) => entry.label == 'Ocultar')
        .onTap();
    expect(toplevelCalls.where((call) => call.method == 'minimize').length, 2);
  });

  test('o segundo clique num app com várias janelas mostra as dele', () async {
    await window(1, 'foot');
    await window(2, 'gimp');
    await window(3, 'foot', activated: true);
    ui.tap(const DockApp('foot'));
    expect(state.switcher.isOpen, isTrue);
    expect(state.switcher.windows.map((w) => w.id), ['3', '1']);
    expect(
      surfaceCalls.last,
      isMethodCall('showOverlay', arguments: 'exclusive'),
    );
    // Sem modificador: soltar uma tecla não escolhe; o Enter escolhe
    state.handleKey(
      const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.altLeft,
        logicalKey: LogicalKeyboardKey.altLeft,
        timeStamp: Duration.zero,
      ),
    );
    expect(state.switcher.isOpen, isTrue);
    state.handleKey(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      ),
    );
    expect(state.switcher.isOpen, isFalse);
    expect(toplevelCalls.last, isMethodCall('activate', arguments: 1));
  });

  test('o ícone pula até aparecer uma janela nova do app', () async {
    await window(1, 'foot');
    ui.startBounce('foot');
    expect(ui.launching.value, {'foot'});
    await window(2, 'gimp');
    expect(ui.launching.value, {'foot'});
    await window(3, 'foot');
    expect(ui.launching.value, isEmpty);
  });

  test('o pulo para sozinho depois do limite', () async {
    ui.bounceLimit = const Duration(milliseconds: 30);
    ui.startBounce('gimp');
    expect(ui.launching.value, {'gimp'});
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(ui.launching.value, isEmpty);
  });

  test('as não lidas de um app somem quando ele vem para frente', () async {
    state.notify(
      const IncomingNotification(
        appName: 'foot',
        summary: 'oi',
        desktopEntry: 'foot',
      ),
    );
    state.notify(
      const IncomingNotification(
        appName: 'gimp',
        summary: 'oi',
        desktopEntry: 'gimp',
      ),
    );
    expect(state.notifications.unreadFor('foot'), 1);
    await window(1, 'foot', activated: true);
    expect(state.notifications.unreadFor('foot'), 0);
    expect(state.notifications.unreadFor('gimp'), 1);
    expect(state.notifications.unreadCount, 1);
  });

  group('nas bordas dos lados', () {
    setUp(() async {
      await state.settings.update(
        state.settings.value.copyWith(dockPosition: PsitoDockPosition.left),
      );
      ui.surface = const Size(110, 400);
    });

    test('a dock fica centrada abaixo da top bar, e cai pelo eixo y', () {
      // (900 + 40) / 2
      expect(ui.rowCenter, 470);
      expect(ui.origin, const Offset(0, 270));
      final centers = PsitoDock.centers(
        count: ui.row.items.length,
        separators: ui.row.separators,
        iconSize: 52,
        centerX: 470,
      );
      ui.startDrag(const DockApp('foot'), DockDragSource.dock, Offset.zero);
      ui.moveDrag(Offset(40, centers.last + 20));
      expect(ui.dropIndex(ui.row, ui.drag.value!), 3);
      // Longe da borda esquerda, tira
      ui.moveDrag(Offset(400, centers.first));
      expect(ui.dropIndex(ui.row, ui.drag.value!), isNull);
      ui.cancelDrag();
    });

    test('o menu abre à direita do ícone, na tela', () {
      ui.openMenu(const DockApp('foot'), const Rect.fromLTWH(20, 30, 52, 52));
      expect(ui.menu.value!.anchor.topLeft, const Offset(20, 300));
    });

    test('a borda e a reserva vão para o runner', () {
      state.applyDockSettings();
      expect(
        surfaceCalls.last,
        isMethodCall('dock', arguments: {'edge': 'left', 'exclusive': 100}),
      );
    });

    test('a região de input só pega o lado de dentro com o ponteiro', () {
      // 16 da sombra mais 0,4 do ícone
      expect(ui.inputInsets.right, closeTo(36.8, 0.01));
      expect(ui.inputInsets.left, 0);
      ui.hovered.value = true;
      expect(ui.inputInsets.right, 0);
    });
  });

  group('ocultar sozinha', () {
    setUp(() async {
      ui.hideDelay = const Duration(milliseconds: 20);
      await state.settings.update(
        state.settings.value.copyWith(dockAutoHide: true),
      );
    });
    Future<void> wait() =>
        Future<void>.delayed(const Duration(milliseconds: 50));

    test('sai sem nada segurando, e não reserva espaço', () async {
      expect(ui.exclusiveZone, 0);
      await wait();
      expect(ui.revealed.value, isFalse);
      ui.reveal();
      expect(ui.revealed.value, isTrue);
      await wait();
      expect(ui.revealed.value, isFalse);
    });

    test('o ponteiro, o menu e o arrastar seguram a dock', () async {
      ui.hovered.value = true;
      await wait();
      expect(ui.revealed.value, isTrue);
      ui.openMenu(const DockApp('foot'), Rect.zero);
      ui.hovered.value = false;
      await wait();
      expect(ui.revealed.value, isTrue);
      ui.closeMenu();
      await wait();
      expect(ui.revealed.value, isFalse);

      // Arrastar do launcher traz a dock
      ui.startDrag(const DockApp('gimp'), DockDragSource.launcher, Offset.zero);
      expect(ui.revealed.value, isTrue);
      ui.cancelDrag();
      await wait();
      expect(ui.revealed.value, isFalse);
    });

    test('desligar traz a dock de volta', () async {
      await wait();
      await state.settings.update(
        state.settings.value.copyWith(dockAutoHide: false),
      );
      expect(ui.revealed.value, isTrue);
      expect(ui.exclusiveZone, 100);
    });
  });
}
