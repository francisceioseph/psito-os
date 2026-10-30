import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/shell/window_manager.dart';

class _FakeApp extends PsitoApp {
  @override
  final String id;
  @override
  final bool singleInstance;

  const _FakeApp(this.id, {this.singleInstance = false});

  @override
  String get name => id;
  @override
  IconData get icon => const IconData(0);
  @override
  Color get color => const Color(0xFFFFFFFF);
  @override
  Widget build(PsitoAppContext context) => const SizedBox();
}

const _area = Rect.fromLTRB(0, 40, 1000, 700);

WindowManager _manager() => WindowManager()..workArea = _area;

void main() {
  test('abrir foca e põe na frente; fechar devolve o foco', () {
    final wm = _manager();
    final a = wm.open(const _FakeApp('a'));
    final b = wm.open(const _FakeApp('b'));
    expect(wm.focusedId, b.id);

    wm.focus(a.id);
    expect(wm.windows.last, a);
    expect(wm.focusedId, a.id);

    wm.close(a.id);
    expect(wm.focusedId, b.id);
    wm.close(b.id);
    expect(wm.focusedId, isNull);
  });

  test('minimizar passa o foco para a visível de cima', () {
    final wm = _manager();
    final a = wm.open(const _FakeApp('a'));
    final b = wm.open(const _FakeApp('b'));
    wm.minimize(b.id);
    expect(b.minimized, isTrue);
    expect(wm.focusedId, a.id);

    wm.activateApp(b.app);
    expect(b.minimized, isFalse);
    expect(wm.focusedId, b.id);
  });

  test('singleInstance e activateApp não duplicam janelas', () {
    final wm = _manager();
    final single = wm.open(const _FakeApp('s', singleInstance: true));
    expect(wm.open(single.app), same(single));

    wm.activateApp(const _FakeApp('n'));
    wm.activateApp(const _FakeApp('n'));
    expect(wm.windows.where((w) => w.app.id == 'n'), hasLength(1));

    wm.open(const _FakeApp('n'));
    expect(wm.windows.where((w) => w.app.id == 'n'), hasLength(2));
  });

  test('snap usa a área útil e restore volta ao tamanho de antes', () {
    final wm = _manager();
    final w = wm.open(const _FakeApp('a'));
    final original = w.bounds;

    wm.snap(w.id, SnapMode.left);
    expect(w.bounds, const Rect.fromLTRB(0, 40, 500, 700));
    wm.snap(w.id, SnapMode.right);
    expect(w.bounds, const Rect.fromLTRB(500, 40, 1000, 700));

    wm.toggleMaximize(w.id);
    expect(w.bounds, _area);
    wm.toggleMaximize(w.id);
    expect(w.bounds, original);
    expect(w.snap, isNull);
  });

  test('snapTargetFor detecta bordas e topo', () {
    final wm = _manager();
    expect(wm.snapTargetFor(const Offset(2, 300)), SnapMode.left);
    expect(wm.snapTargetFor(const Offset(998, 300)), SnapMode.right);
    expect(wm.snapTargetFor(const Offset(500, 10)), SnapMode.maximized);
    expect(wm.snapTargetFor(const Offset(500, 300)), isNull);
  });

  test('arrastar até a borda aplica o snap; arrastar com snap restaura', () {
    final wm = _manager();
    final w = wm.open(const _FakeApp('a'));
    final size = w.bounds.size;

    wm.move(w.id, const Offset(-10, 0), pointer: const Offset(1, 300));
    expect(wm.snapPreview, SnapMode.left);
    wm.endMove(w.id);
    expect(w.snap, SnapMode.left);
    expect(wm.snapPreview, isNull);

    wm.beginMove(w.id, const Offset(300, 60));
    expect(w.snap, isNull);
    expect(w.bounds.size, size);
    expect(w.bounds.center.dx, 300);
  });

  test('resize respeita o tamanho mínimo e desfaz o snap', () {
    final wm = _manager();
    final w = wm.open(const _FakeApp('a'));
    wm.snap(w.id, SnapMode.left);

    wm.resize(w.id, ResizeEdge.bottomRight, const Offset(-2000, -2000));
    expect(w.snap, isNull);
    expect(w.bounds.size, WindowManager.minSize);

    final right = w.bounds.right;
    wm.resize(w.id, ResizeEdge.left, const Offset(-50, 0));
    expect(w.bounds.width, WindowManager.minSize.width + 50);
    expect(w.bounds.right, right);
  });

  test('a barra de título nunca sai da área útil', () {
    final wm = _manager();
    final w = wm.open(const _FakeApp('a'));

    wm.move(w.id, const Offset(0, -5000));
    expect(w.bounds.top, _area.top);
    wm.move(w.id, const Offset(0, 5000));
    expect(w.bounds.top, _area.bottom - WindowManager.titleBarHeight);
    wm.move(w.id, const Offset(5000, 0));
    expect(w.bounds.left, lessThanOrEqualTo(_area.right - 80));
    wm.move(w.id, const Offset(-5000, 0));
    expect(w.bounds.right, greaterThanOrEqualTo(_area.left + 80));
  });

  test('cycleFocus percorre todas as janelas, inclusive minimizadas', () {
    final wm = _manager();
    final a = wm.open(const _FakeApp('a'));
    final b = wm.open(const _FakeApp('b'));
    final c = wm.open(const _FakeApp('c'));
    wm.minimize(a.id);

    final seen = <String?>[];
    for (var i = 0; i < 3; i++) {
      wm.cycleFocus();
      seen.add(wm.focusedId);
    }
    expect(seen, [a.id, b.id, c.id]);
    expect(a.minimized, isFalse);

    wm.cycleFocus(reverse: true);
    expect(wm.focusedId, b.id);
  });

  test('setTitle pelo contexto do app', () {
    final wm = _manager();
    final w = wm.open(const _FakeApp('a'));
    w.context.setTitle('novo');
    expect(w.title, 'novo');
    w.context.close();
    expect(wm.windows, isEmpty);
  });
}
