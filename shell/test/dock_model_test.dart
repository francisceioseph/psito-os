import 'package:flutter_test/flutter_test.dart';
import 'package:psito_shell/desktop_entries.dart';
import 'package:psito_shell/dock_model.dart';
import 'package:psito_shell/toplevels.dart';

DesktopEntry _app(String id) =>
    DesktopEntry(id: id, name: id.toUpperCase(), command: [id]);

final _entries = {
  for (final id in ['foot', 'firefox-esr']) id: _app(id),
};

void main() {
  test('fixados primeiro, depois os abertos agrupados por app_id', () {
    final slots = dockSlotsFor(
      pinned: ['firefox-esr', 'foot'],
      entries: _entries,
      windows: const [
        Toplevel(id: 1, appId: 'foot'),
        Toplevel(id: 2, appId: 'org.gtk.Demo4', title: 'GTK Demo'),
        Toplevel(id: 3, appId: 'foot'),
      ],
    );
    expect(slots.map((s) => s.id), ['firefox-esr', 'foot', 'org.gtk.Demo4']);
    expect(slots[0].running, isFalse);
    expect(slots[1].windows.map((w) => w.id), [1, 3]);
    // Sem .desktop, o nome vem do título da janela
    expect(slots[2].name, 'GTK Demo');
  });

  test('fixado que não está instalado não aparece, a não ser aberto', () {
    List<String> ids(List<Toplevel> windows) => [
      for (final slot in dockSlotsFor(
        pinned: ['firefox-esr', 'org.psito.ausente', 'foot'],
        entries: _entries,
        windows: windows,
      ))
        slot.id,
    ];
    expect(ids(const []), ['firefox-esr', 'foot']);
    expect(ids(const [Toplevel(id: 1, appId: 'org.psito.ausente')]), [
      'firefox-esr',
      'org.psito.ausente',
      'foot',
    ]);
  });

  test('sem janela, o clique abre o app', () {
    final slot = DockSlot(id: 'foot', entry: _app('foot'));
    expect(tapAction(slot), isA<LaunchApp>());
    expect(tapAction(const DockSlot(id: 'sem-desktop')), isNull);
  });

  test('com a janela em foco, o clique minimiza', () {
    final slot = DockSlot(
      id: 'foot',
      windows: const [
        Toplevel(id: 1, appId: 'foot'),
        Toplevel(id: 2, appId: 'foot', activated: true),
      ],
    );
    expect((tapAction(slot)! as MinimizeWindow).id, 2);
  });

  test('sem foco ou minimizada, o clique ativa a mais recente', () {
    final slot = DockSlot(
      id: 'foot',
      windows: const [
        Toplevel(id: 1, appId: 'foot'),
        Toplevel(id: 2, appId: 'foot', activated: true, minimized: true),
      ],
    );
    expect((tapAction(slot)! as ActivateWindow).id, 2);
  });
}
