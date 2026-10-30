// system_shell/lib/shell/window_manager.dart
//
// Estado das janelas sem UI: z-order, foco, minimizar, snap e redimensionar.
// A moldura (widgets/psito_window.dart) só chama estes métodos.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:psito_sdk/psito_sdk.dart';

enum SnapMode { left, right, maximized }

/// Borda ou canto sendo arrastado: -1, 0 ou 1 em cada eixo.
class ResizeEdge {
  final int dx;
  final int dy;

  const ResizeEdge(this.dx, this.dy);

  static const top = ResizeEdge(0, -1);
  static const bottom = ResizeEdge(0, 1);
  static const left = ResizeEdge(-1, 0);
  static const right = ResizeEdge(1, 0);
  static const topLeft = ResizeEdge(-1, -1);
  static const topRight = ResizeEdge(1, -1);
  static const bottomLeft = ResizeEdge(-1, 1);
  static const bottomRight = ResizeEdge(1, 1);
}

class ShellWindow {
  final String id;
  final PsitoApp app;
  String title;
  Rect bounds;
  bool minimized = false;
  SnapMode? snap;

  /// Bounds de antes do snap, para restaurar.
  Rect? restoreBounds;
  late final PsitoAppContext context;

  ShellWindow({required this.id, required this.app, required this.bounds})
    : title = app.name;
}

class WindowManager extends ChangeNotifier {
  static const minSize = Size(240, 160);
  static const titleBarHeight = 40.0;

  /// Quanto da barra de título precisa ficar visível na horizontal.
  static const _grabMargin = 80.0;

  /// Distância da borda que ativa o snap ao arrastar.
  static const _snapThreshold = 8.0;

  WindowManager({
    this.onNotify,
    ValueListenable<PsitoSettings>? settings,
    this.onUpdateSettings,
  }) : settings = settings ?? ValueNotifier(PsitoSettings.defaults);

  final void Function(ShellWindow window, PsitoNotification notification)?
  onNotify;

  /// O que os apps leem por [PsitoAppContext.settings].
  final ValueListenable<PsitoSettings> settings;

  /// Pedido de mudança vindo de um app com [PsitoApp.canChangeSettings].
  final void Function(PsitoSettings settings)? onUpdateSettings;

  final List<ShellWindow> _windows = [];
  String? _focusedId;
  int _nextId = 0;
  Rect _workArea = const Rect.fromLTWH(0, 40, 1280, 660);
  SnapMode? _snapPreview;

  /// Janelas em z-order: a última fica na frente.
  List<ShellWindow> get windows => List.unmodifiable(_windows);
  String? get focusedId => _focusedId;
  ShellWindow? get focused => _byId(_focusedId);

  /// Tela menos a top bar e a dock.
  Rect get workArea => _workArea;

  /// Snap que seria aplicado se o arraste terminasse agora.
  SnapMode? get snapPreview => _snapPreview;
  Rect? get snapPreviewRect =>
      _snapPreview == null ? null : snapRect(_snapPreview!);

  bool contains(String id) => _byId(id) != null;

  bool isRunning(String appId) => _windows.any((w) => w.app.id == appId);

  /// Chamado durante o layout do desktop, que já vai redesenhar as janelas:
  /// por isso não notifica.
  set workArea(Rect area) {
    if (area == _workArea) return;
    _workArea = area;
    for (final w in _windows) {
      w.bounds = w.snap != null ? snapRect(w.snap!) : _clamp(w.bounds);
    }
  }

  ShellWindow open(PsitoApp app) {
    if (app.singleInstance) {
      final existing = _topmostOf(app.id);
      if (existing != null) {
        focus(existing.id);
        return existing;
      }
    }

    final size = Size(
      math.min(app.defaultSize.width, _workArea.width),
      math.min(app.defaultSize.height, _workArea.height),
    );
    final cascade = (_windows.length % 6) * 30.0;
    final origin =
        _workArea.center -
        Offset(size.width / 2, size.height / 2) +
        Offset(cascade - 75, cascade - 75);
    final window = ShellWindow(
      id: '${app.id}#${_nextId++}',
      app: app,
      bounds: _clamp(origin & size),
    );
    window.context = _WindowContext(this, window.id);
    _windows.add(window);
    _focusedId = window.id;
    notifyListeners();
    app.onOpen(window.context);
    return window;
  }

  /// Clique na dock: foca a janela do app (restaurando) ou abre uma nova.
  void activateApp(PsitoApp app) {
    final existing = _topmostOf(app.id);
    if (existing == null) {
      open(app);
    } else {
      focus(existing.id);
    }
  }

  void close(String id) {
    final window = _byId(id);
    if (window == null) return;
    _windows.remove(window);
    if (_focusedId == id) _focusedId = _topmostVisible()?.id;
    notifyListeners();
    window.app.onClose(window.context);
  }

  void focus(String id) {
    final window = _byId(id);
    if (window == null) return;
    if (_focusedId == id && !window.minimized && _windows.last == window) {
      return;
    }
    window.minimized = false;
    _windows
      ..remove(window)
      ..add(window);
    _focusedId = id;
    notifyListeners();
  }

  void minimize(String id) {
    final window = _byId(id);
    if (window == null) return;
    window.minimized = true;
    if (_focusedId == id) _focusedId = _topmostVisible()?.id;
    notifyListeners();
  }

  void toggleMaximize(String id) {
    final window = _byId(id);
    if (window == null) return;
    if (window.snap == SnapMode.maximized) {
      restore(id);
    } else {
      snap(id, SnapMode.maximized);
    }
  }

  void snap(String id, SnapMode mode) {
    final window = _byId(id);
    if (window == null) return;
    window.restoreBounds ??= window.bounds;
    window.snap = mode;
    window.bounds = snapRect(mode);
    notifyListeners();
  }

  /// Volta ao tamanho de antes do snap.
  void restore(String id) {
    final window = _byId(id);
    if (window == null || window.snap == null) return;
    window.bounds = _clamp(window.restoreBounds ?? window.bounds);
    window.snap = null;
    window.restoreBounds = null;
    notifyListeners();
  }

  Rect snapRect(SnapMode mode) {
    final a = _workArea;
    return switch (mode) {
      SnapMode.left => Rect.fromLTRB(a.left, a.top, a.center.dx, a.bottom),
      SnapMode.right => Rect.fromLTRB(a.center.dx, a.top, a.right, a.bottom),
      SnapMode.maximized => a,
    };
  }

  /// Início do arraste pela barra de título. Uma janela com snap volta ao
  /// tamanho normal, centrada no ponteiro.
  void beginMove(String id, Offset pointer) {
    final window = _byId(id);
    if (window == null || window.snap == null) return;
    final size = (window.restoreBounds ?? window.bounds).size;
    window.snap = null;
    window.restoreBounds = null;
    window.bounds = _clamp(
      Offset(pointer.dx - size.width / 2, pointer.dy - titleBarHeight / 2) &
          size,
    );
    notifyListeners();
  }

  void move(String id, Offset delta, {Offset? pointer}) {
    final window = _byId(id);
    if (window == null) return;
    window.bounds = _clamp(window.bounds.shift(delta));
    _snapPreview = pointer == null ? null : snapTargetFor(pointer);
    notifyListeners();
  }

  /// Fim do arraste: aplica o snap pré-visualizado, se houver.
  void endMove(String id) {
    final target = _snapPreview;
    _snapPreview = null;
    if (target != null) {
      snap(id, target);
    } else {
      notifyListeners();
    }
  }

  SnapMode? snapTargetFor(Offset pointer) {
    if (pointer.dy <= _workArea.top + _snapThreshold / 2) {
      return SnapMode.maximized;
    }
    if (pointer.dx <= _workArea.left + _snapThreshold) return SnapMode.left;
    if (pointer.dx >= _workArea.right - _snapThreshold) return SnapMode.right;
    return null;
  }

  void resize(String id, ResizeEdge edge, Offset delta) {
    final window = _byId(id);
    if (window == null || window.snap == SnapMode.maximized) return;
    window.snap = null;
    window.restoreBounds = null;

    var Rect(:left, :top, :right, :bottom) = window.bounds;
    if (edge.dx < 0) {
      left = math.min(left + delta.dx, right - minSize.width);
    } else if (edge.dx > 0) {
      right = math.max(right + delta.dx, left + minSize.width);
    }
    if (edge.dy < 0) {
      top = math.min(
        math.max(top + delta.dy, _workArea.top),
        bottom - minSize.height,
      );
    } else if (edge.dy > 0) {
      bottom = math.max(bottom + delta.dy, top + minSize.height);
    }
    window.bounds = Rect.fromLTRB(left, top, right, bottom);
    notifyListeners();
  }

  /// Traz para frente a janela de baixo (incluindo minimizadas); repetir
  /// percorre todas. O overlay de Alt+Tab da etapa 6 usa isso.
  void cycleFocus({bool reverse = false}) {
    if (_windows.isEmpty) return;
    if (_windows.length == 1) {
      focus(_windows.first.id);
      return;
    }
    if (reverse) {
      final top = _windows.removeLast();
      _windows.insert(0, top);
      focus(_windows.last.id);
    } else {
      focus(_windows.first.id);
    }
  }

  void setTitle(String id, String title) {
    final window = _byId(id);
    if (window == null || window.title == title) return;
    window.title = title;
    notifyListeners();
  }

  /// Mantém a barra de título alcançável dentro da área útil.
  Rect _clamp(Rect r) {
    final a = _workArea;
    final dx = r.left.clamp(
      a.left - r.width + _grabMargin,
      a.right - _grabMargin,
    );
    final dy = r.top.clamp(a.top, math.max(a.top, a.bottom - titleBarHeight));
    return Offset(dx.toDouble(), dy.toDouble()) & r.size;
  }

  ShellWindow? _byId(String? id) {
    for (final w in _windows) {
      if (w.id == id) return w;
    }
    return null;
  }

  ShellWindow? _topmostOf(String appId) =>
      _windows.lastWhereOrNull((w) => w.app.id == appId);

  ShellWindow? _topmostVisible() =>
      _windows.lastWhereOrNull((w) => !w.minimized);
}

extension<T> on List<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    for (var i = length - 1; i >= 0; i--) {
      if (test(this[i])) return this[i];
    }
    return null;
  }
}

/// O que um app enxerga do shell, para uma janela.
class _WindowContext implements PsitoAppContext {
  final WindowManager _manager;

  @override
  final String windowId;

  _WindowContext(this._manager, this.windowId);

  @override
  void setTitle(String title) => _manager.setTitle(windowId, title);

  @override
  void close() => _manager.close(windowId);

  @override
  void notify(PsitoNotification notification) {
    final window = _manager._byId(windowId);
    if (window == null) return;
    final handler = _manager.onNotify;
    if (handler != null) {
      handler(window, notification);
    } else {
      debugPrint('🦜 Notificação de $windowId: ${notification.title}');
    }
  }

  @override
  ValueListenable<PsitoSettings> get settings => _manager.settings;

  @override
  void updateSettings(PsitoSettings settings) {
    final window = _manager._byId(windowId);
    if (window == null) return;
    if (!window.app.canChangeSettings) {
      debugPrint('🦜 ${window.app.id} não pode alterar as configurações');
      return;
    }
    _manager.onUpdateSettings?.call(settings);
  }
}
