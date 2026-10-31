import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/shell/window_manager.dart';
import 'package:system_shell/shell/window_switcher.dart';

import 'helpers.dart';

final _ctrl = {LogicalKeyboardKey.controlLeft};

List<SwitcherEntry> _zOrder(List<String> ids) => [
  for (final id in ids)
    SwitcherEntry.fromWindow(
      ShellWindow(id: id, app: FakeApp(id), bounds: Rect.zero),
    ),
];

void main() {
  test('ordem do mais recente e seleção na segunda', () {
    final s = WindowSwitcher()
      ..start(_zOrder(['a', 'b', 'c']), holdKeys: _ctrl);
    expect(s.windows.map((w) => w.id), ['c', 'b', 'a']);
    expect(s.selectedId, 'b');
  });

  test('a focada vem primeiro mesmo fora do topo do z-order', () {
    final s = WindowSwitcher()
      ..start(_zOrder(['a', 'b', 'c']), holdKeys: _ctrl, focusedId: 'b');
    expect(s.windows.map((w) => w.id), ['b', 'c', 'a']);
    expect(s.selectedId, 'c');
  });

  test('reverse começa na mais antiga e step dá a volta', () {
    final s = WindowSwitcher()
      ..start(_zOrder(['a', 'b', 'c']), holdKeys: _ctrl, reverse: true);
    expect(s.selectedId, 'a');
    s.step();
    expect(s.selectedId, 'c');
    s.step(reverse: true);
    expect(s.selectedId, 'a');
  });

  test('com menos de 2 janelas não abre', () {
    final s = WindowSwitcher()..start(_zOrder(['a']), holdKeys: _ctrl);
    expect(s.isOpen, isFalse);
    expect(s.commit(), isNull);
  });

  test('commit devolve a escolhida e cancel não devolve nada', () {
    final s = WindowSwitcher()..start(_zOrder(['a', 'b']), holdKeys: _ctrl);
    expect(s.releases(LogicalKeyboardKey.controlLeft), isTrue);
    expect(s.releases(LogicalKeyboardKey.altLeft), isFalse);
    expect(s.commit(), 'a');
    expect(s.isOpen, isFalse);

    s.start(_zOrder(['a', 'b']), holdKeys: _ctrl);
    s.cancel();
    expect(s.isOpen, isFalse);
    expect(s.commit(), isNull);
  });
}
