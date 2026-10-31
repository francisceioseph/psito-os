import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_dock/psito_dock.dart';
import 'package:psito_services/system_services.dart';
import 'package:psito_shell/autostart.dart';
import 'package:psito_shell/desktop_entries.dart';
import 'package:psito_shell/dock.dart';
import 'package:psito_shell/shell_state.dart';
import 'package:psito_shell/surfaces.dart';
import 'package:psito_shell/toplevels.dart';
import 'package:system_shell/shell/settings_store.dart';
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
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('psito_dock_shell_');
    surfaceCalls = [];
    messenger.setMockMethodCallHandler(_toplevels, (call) async => null);
    messenger.setMockMethodCallHandler(_surfaces, (call) async {
      surfaceCalls.add(call);
      return null;
    });
    state = ShellState(
      settings: SettingsStore.memory(),
      services: SystemServices.fake(),
      toplevels: ToplevelList(channel: _toplevels),
      surfaces: const Surfaces(_surfaces),
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
    ui.startDrag(const DockApp('org.psito.files'), DockDragSource.dock, at(2));
    // O arrastado sai da fileira; antes do primeiro, abre o espaço no 0
    expect(ui.row.items.map((i) => i.item), const [
      DockApp('foot'),
      DockApp('firefox-esr'),
    ]);
    ui.moveDrag(at(0) - const Offset(10, 0));
    expect(ui.dropIndex(ui.row, ui.drag.value!), 0);
    await ui.endDrag();
    expect(ids(), [
      'DockApp(org.psito.files)',
      'DockApp(foot)',
      'DockApp(firefox-esr)',
    ]);
    expect(ui.drag.value, isNull);
  });

  test('soltar longe da dock tira o item', () async {
    ui.startDrag(const DockApp('foot'), DockDragSource.dock, at(0));
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
    ui.moveDrag(at(1) + const Offset(10, 0));
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
      expect(row.separators, {3});
      expect(row.paths, 3);

      // Uma pasta arrastada só cai entre as pastas e os arquivos
      ui.startDrag(DockFile(file.path), DockDragSource.dock, at(4));
      ui.moveDrag(at(0));
      expect(ui.dropIndex(ui.row, ui.drag.value!), 3);
    },
  );

  test('o menu de um app fixado, de um aberto e de uma pasta', () async {
    await state.toplevels.handle(
      const MethodCall('changed', {'id': 1, 'appId': 'gimp', 'title': 'x'}),
    );
    List<String> labels(DockItem item) => [
      for (final entry in ui.menuItems(item))
        '${entry.label}${entry.checked == true ? ' *' : ''}',
    ];
    expect(labels(const DockApp('foot')), [
      'Abrir ao iniciar a sessão',
      'Remover da Dock',
    ]);
    expect(labels(const DockApp('gimp')), [
      'Abrir ao iniciar a sessão',
      'Manter na Dock',
    ]);
    expect(labels(const DockFolder('/home/u/Downloads')), [
      'Abrir',
      'Mostrar no Files',
      'Manter na Dock',
    ]);

    ui.menuItems(const DockApp('gimp'))[1].onTap();
    expect(state.dock.contains(const DockApp('gimp')), isTrue);

    // O autostart grava no ~/.config/autostart
    ui.menuItems(const DockApp('foot'))[0].onTap();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(labels(const DockApp('foot')).first, 'Abrir ao iniciar a sessão *');
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
    state.openPaths = (paths) async => opened.add(paths);
    ui.tap(const DockFolder('/home/u/Downloads'));
    ui.menuItems(const DockFile('/home/u/a/b.txt'))[1].onTap();
    expect(opened, [
      ['/home/u/Downloads'],
      ['/home/u/a'],
    ]);
  });
}
