import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/screens/desktop_screen.dart';
import 'package:system_shell/shell/window_manager.dart';
import 'package:system_shell/widgets/launcher.dart';
import 'package:system_shell/widgets/psito_window.dart';
import 'package:system_shell/widgets/window_switcher_overlay.dart';

const _ctrl = LogicalKeyboardKey.controlLeft;
const _alt = LogicalKeyboardKey.altLeft;
const _shift = LogicalKeyboardKey.shiftLeft;
const _tab = LogicalKeyboardKey.tab;

/// Abre Calculadora, Relógio e Arquivos pela dock; Arquivos fica em foco.
Future<WindowManager> _pumpWithWindows(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: DesktopScreen()));
  for (final icon in [
    Icons.calculate_outlined,
    Icons.access_time_rounded,
    Icons.folder_open_rounded,
  ]) {
    await tester.tap(find.byIcon(icon).first);
    await tester.pump();
  }
  return tester
      .widget<PsitoWindow>(find.byType(PsitoWindow, skipOffstage: false).first)
      .manager;
}

String _appOf(WindowManager wm) => wm.focused!.app.id;

/// Segura [modifiers], aperta [key] e solta tudo.
Future<void> _combo(
  WidgetTester tester,
  List<LogicalKeyboardKey> modifiers,
  LogicalKeyboardKey key,
) async {
  for (final m in modifiers) {
    await tester.sendKeyDownEvent(m);
  }
  await tester.sendKeyEvent(key);
  for (final m in modifiers.reversed) {
    await tester.sendKeyUpEvent(m);
  }
  await tester.pump();
}

final _switcher = find.byType(WindowSwitcherOverlay);

void main() {
  testWidgets('Ctrl+Espaço abre e fecha o launcher', (tester) async {
    await _pumpWithWindows(tester);
    await _combo(tester, [_ctrl], LogicalKeyboardKey.space);
    expect(find.byType(Launcher), findsOneWidget);
    await _combo(tester, [_ctrl], LogicalKeyboardKey.space);
    expect(find.byType(Launcher), findsNothing);
  });

  testWidgets('Ctrl+Tab mostra o seletor e soltar Ctrl foca a escolhida', (
    tester,
  ) async {
    final wm = await _pumpWithWindows(tester);
    expect(_appOf(wm), 'files');

    await tester.sendKeyDownEvent(_ctrl);
    await tester.sendKeyEvent(_tab);
    await tester.pump();
    expect(_switcher, findsOneWidget);
    // Seleção começa na segunda mais recente; Tab de novo vai para a próxima
    await tester.sendKeyEvent(_tab);
    await tester.pump();
    expect(_appOf(wm), 'files');

    await tester.sendKeyUpEvent(_ctrl);
    await tester.pump();
    expect(_switcher, findsNothing);
    expect(_appOf(wm), 'calculator');
  });

  testWidgets('Alt+Tab nativo alterna entre as duas mais recentes', (
    tester,
  ) async {
    final wm = await _pumpWithWindows(tester);
    await _combo(tester, [_alt], _tab);
    expect(_appOf(wm), 'clock');
    await _combo(tester, [_alt], _tab);
    expect(_appOf(wm), 'files');
  });

  testWidgets('Shift volta e Esc cancela sem trocar o foco', (tester) async {
    final wm = await _pumpWithWindows(tester);
    await tester.sendKeyDownEvent(_ctrl);
    await tester.sendKeyDownEvent(_shift);
    await tester.sendKeyEvent(_tab);
    await tester.pump();
    expect(_switcher, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_switcher, findsNothing);
    await tester.sendKeyUpEvent(_shift);
    await tester.sendKeyUpEvent(_ctrl);
    await tester.pump();
    expect(_appOf(wm), 'files');
  });

  testWidgets('clicar num cartão do seletor foca a janela', (tester) async {
    final wm = await _pumpWithWindows(tester);
    await tester.sendKeyDownEvent(_ctrl);
    await tester.sendKeyEvent(_tab);
    await tester.pump();

    final calculator = wm.windows.first;
    await tester.tap(find.byKey(ValueKey('switcher-${calculator.id}')));
    await tester.pump();
    expect(_switcher, findsNothing);
    expect(wm.focusedId, calculator.id);
    await tester.sendKeyUpEvent(_ctrl);
  });

  testWidgets('Ctrl+Alt+W fecha a janela focada', (tester) async {
    final wm = await _pumpWithWindows(tester);
    await _combo(tester, [_ctrl, _alt], LogicalKeyboardKey.keyW);
    expect(wm.windows.map((w) => w.app.id), ['calculator', 'clock']);
    expect(_appOf(wm), 'clock');
  });

  testWidgets('Alt+Shift+setas fazem snap, maximizam e minimizam', (
    tester,
  ) async {
    final wm = await _pumpWithWindows(tester);
    final files = wm.focused!;

    await _combo(tester, [_alt, _shift], LogicalKeyboardKey.arrowLeft);
    expect(files.snap, SnapMode.left);
    await _combo(tester, [_alt, _shift], LogicalKeyboardKey.arrowLeft);
    expect(files.snap, isNull);

    await _combo(tester, [_alt, _shift], LogicalKeyboardKey.arrowUp);
    expect(files.snap, SnapMode.maximized);

    await _combo(tester, [_alt, _shift], LogicalKeyboardKey.arrowDown);
    expect(files.minimized, isTrue);
    expect(_appOf(wm), 'clock');
  });

  testWidgets('Super+→ nativo faz snap à direita', (tester) async {
    final wm = await _pumpWithWindows(tester);
    await _combo(tester, [
      LogicalKeyboardKey.metaLeft,
    ], LogicalKeyboardKey.arrowRight);
    expect(wm.focused!.snap, SnapMode.right);
    expect(find.byType(Launcher), findsNothing);
  });

  testWidgets('modificadores a mais não disparam o atalho', (tester) async {
    final wm = await _pumpWithWindows(tester);
    await _combo(tester, [_ctrl, _alt, _shift], LogicalKeyboardKey.arrowLeft);
    expect(wm.focused!.snap, isNull);
  });
}
