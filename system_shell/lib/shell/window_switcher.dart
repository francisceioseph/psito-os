// system_shell/lib/shell/window_switcher.dart
//
// Seletor de janelas do Alt+Tab / Ctrl+Tab, sem UI. Fica aberto enquanto o
// modificador está pressionado; soltar confirma e Esc cancela.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'window_manager.dart';

class WindowSwitcher extends ChangeNotifier {
  List<ShellWindow> _windows = const [];
  int _index = 0;
  Set<LogicalKeyboardKey> _holdKeys = const {};

  bool get isOpen => _windows.isNotEmpty;

  /// Da mais recente para a mais antiga.
  List<ShellWindow> get windows => _windows;
  int get index => _index;
  String? get selectedId => isOpen ? _windows[_index].id : null;

  /// [zOrder] como em [WindowManager.windows]: a última é a mais recente.
  /// Com menos de 2 janelas não há o que alternar e o seletor não abre.
  /// [holdKeys] são as teclas do modificador cuja soltura confirma.
  void start(
    List<ShellWindow> zOrder, {
    required Set<LogicalKeyboardKey> holdKeys,
    bool reverse = false,
  }) {
    if (zOrder.length < 2) return;
    _windows = zOrder.reversed.toList();
    _index = reverse ? _windows.length - 1 : 1;
    _holdKeys = holdKeys;
    notifyListeners();
  }

  void step({bool reverse = false}) {
    if (!isOpen) return;
    _index = (_index + (reverse ? -1 : 1)) % _windows.length;
    notifyListeners();
  }

  void select(String id) {
    final i = _windows.indexWhere((w) => w.id == id);
    if (i < 0 || i == _index) return;
    _index = i;
    notifyListeners();
  }

  bool releases(LogicalKeyboardKey key) => _holdKeys.contains(key);

  /// Fecha e devolve a janela escolhida.
  String? commit() {
    final id = selectedId;
    cancel();
    return id;
  }

  void cancel() {
    if (!isOpen) return;
    _windows = const [];
    _index = 0;
    _holdKeys = const {};
    notifyListeners();
  }
}
