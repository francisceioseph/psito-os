import 'package:flutter_test/flutter_test.dart';
import 'package:psito_dock/psito_dock.dart';

class _Window implements DockWindow {
  final int id;
  @override
  final String appId;
  @override
  final bool focused;
  @override
  final bool minimized;

  const _Window(
    this.id,
    this.appId, {
    this.focused = false,
    this.minimized = false,
  });
}

const _apps = {'foot': 'Foot', 'firefox-esr': 'Firefox'};

DockLayout<String, _Window> _layout(
  List<DockItem> items, [
  List<_Window> windows = const [],
  bool Function(String path)? exists,
]) => dockLayout(
  items: items,
  apps: _apps,
  windows: windows,
  exists: exists ?? (_) => true,
);

void main() {
  test('fixados primeiro, depois os abertos agrupados por app_id', () {
    final layout = _layout(
      const [DockApp('firefox-esr'), DockApp('foot')],
      const [
        _Window(1, 'foot'),
        _Window(2, 'org.gtk.Demo4'),
        _Window(3, 'foot'),
      ],
    );
    expect(layout.pinned.map((s) => s.id), ['firefox-esr', 'foot']);
    expect(layout.running.map((s) => s.id), ['org.gtk.Demo4']);
    expect(layout.apps.map((s) => s.pinned), [true, true, false]);
    expect(layout.pinned[0].running, isFalse);
    expect(layout.pinned[1].windows.map((w) => w.id), [1, 3]);
    expect(layout.running.single.app, isNull);
  });

  test('o que sumiu fica escondido, e volta quando reaparece', () {
    const items = [
      DockApp('firefox-esr'),
      DockApp('org.psito.ausente'),
      DockFolder('/home/u/Downloads'),
      DockFile('/home/u/apagado.txt'),
      DockApp('foot'),
    ];
    final hidden = _layout(
      items,
      const [],
      (path) => !path.contains('apagado'),
    );
    expect(hidden.pinned.map((s) => s.id), ['firefox-esr', 'foot']);
    expect(hidden.paths, [const DockFolder('/home/u/Downloads')]);

    final open = _layout(items, const [_Window(1, 'org.psito.ausente')]);
    expect(open.pinned.map((s) => s.id), [
      'firefox-esr',
      'org.psito.ausente',
      'foot',
    ]);
    expect(open.running, isEmpty);
  });

  test('sem janela, o clique abre o app', () {
    const slot = DockAppSlot<String, _Window>(id: 'foot', app: 'Foot');
    expect((tapAction(slot)! as LaunchApp).app, 'Foot');
    expect(tapAction(const DockAppSlot<String, _Window>(id: 'x')), isNull);
  });

  test('com a janela em foco, o clique minimiza', () {
    const slot = DockAppSlot<String, _Window>(
      id: 'foot',
      windows: [_Window(1, 'foot'), _Window(2, 'foot', focused: true)],
    );
    expect((tapAction(slot)! as MinimizeWindow<String, _Window>).window.id, 2);
  });

  test('sem foco ou minimizada, o clique ativa a mais recente', () {
    const slot = DockAppSlot<String, _Window>(
      id: 'foot',
      windows: [
        _Window(1, 'foot'),
        _Window(2, 'foot', focused: true, minimized: true),
      ],
    );
    expect((tapAction(slot)! as ActivateWindow<String, _Window>).window.id, 2);
  });

  test('o nome de uma pasta é o último pedaço do caminho', () {
    expect(const DockFolder('/home/u/Downloads/').name, 'Downloads');
    expect(const DockFolder('/').name, '/');
  });
}
