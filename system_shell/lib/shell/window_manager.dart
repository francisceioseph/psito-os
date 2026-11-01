// system_shell/lib/shell/window_manager.dart
//
// Estado das janelas sem UI: z-order, foco, minimizar, snap e redimensionar.
// A moldura (widgets/psito_window.dart) só chama estes métodos.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'package:psito_services/accounts_service.dart';
import 'package:psito_services/disks_service.dart';
import 'package:psito_services/network_connections.dart';
import 'package:psito_services/time_service.dart';

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
    : title = app.localizedName(resolvePsitoLocale(''));
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
    ValueListenable<PsitoSystemInfo>? systemInfo,
    ValueListenable<PsitoNetworkState>? network,
    PsitoNetworkConnections? networkConnections,
    TimeService? time,
  }) : networkConnections = networkConnections ?? FakeNetworkConnections(),
       time = time ?? FakeTimeService(initial: PsitoTimeState.unavailable),
       settings = settings ?? ValueNotifier(PsitoSettings.defaults),
       systemInfo = systemInfo ?? ValueNotifier(PsitoSystemInfo.unavailable),
       network = network ?? ValueNotifier(PsitoNetworkState.unavailable);

  final void Function(ShellWindow window, PsitoNotification notification)?
  onNotify;

  /// O que os apps leem por [PsitoAppContext.settings].
  final ValueListenable<PsitoSettings> settings;

  /// Pedido de mudança vindo de um app com [PsitoApp.canChangeSettings].
  final void Function(PsitoSettings settings)? onUpdateSettings;

  /// O que os apps leem por [PsitoAppContext.systemInfo].
  final ValueListenable<PsitoSystemInfo> systemInfo;

  /// O que os apps leem por [PsitoAppContext.network].
  final ValueListenable<PsitoNetworkState> network;

  /// Relógio do sistema: [PsitoAppContext.now], fuso e NTP.
  final TimeService time;

  /// As contas do laboratório: nunca as de verdade do host.
  final PsitoAccounts accounts = FakeAccountsService();

  /// Idem para as conexões de rede.
  final PsitoNetworkConnections networkConnections;

  /// Os discos do laboratório: um pendrive, nunca os de verdade do host.
  final PsitoVolumes volumes = FakeDisksService([FakeDisksService.sample]);

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
  ValueListenable<PsitoSystemInfo> get systemInfo => _manager.systemInfo;

  @override
  ValueListenable<PsitoNetworkState> get network => _manager.network;

  @override
  ValueListenable<PsitoTimeState> get time => _manager.time.state;

  @override
  DateTime now() => _manager.time.now();

  @override
  Future<List<String>> timezones() => _manager.time.timezones();

  /// Só apps com [PsitoApp.canChangeSettings] mexem no sistema.
  bool _mayChange(String what) {
    final window = _manager._byId(windowId);
    if (window == null) return false;
    if (window.app.canChangeSettings) return true;
    debugPrint('🦜 ${window.app.id} não pode alterar $what');
    return false;
  }

  @override
  PsitoAccounts get accounts {
    final window = _manager._byId(windowId);
    return window != null && window.app.canChangeSettings
        ? _manager.accounts
        : const PsitoNoAccounts();
  }

  @override
  PsitoVolumes get volumes => _manager.volumes;

  @override
  PsitoNetworkConnections get networkConnections {
    final window = _manager._byId(windowId);
    return window != null && window.app.canChangeSettings
        ? _manager.networkConnections
        : const PsitoNoNetworkConnections();
  }

  @override
  void setTimezone(String timezone) {
    if (_mayChange('o fuso')) _manager.time.setTimezone(timezone);
  }

  @override
  void setNtp(bool enabled) {
    if (_mayChange('o NTP')) _manager.time.setNtp(enabled);
  }

  @override
  void updateSettings(PsitoSettings settings) {
    if (_mayChange('as configurações')) {
      _manager.onUpdateSettings?.call(settings);
    }
  }

  // No laboratório os apps estão no mesmo processo e não há o shell que
  // abre arquivos: abrir vai para o xdg-open do host

  @override
  List<String> get openedPaths => const [];

  @override
  Stream<List<String>> get openRequests => const Stream.empty();

  @override
  Future<void> open(List<String> paths, {String? withApp}) async {
    for (final path in paths) {
      try {
        await Process.start('xdg-open', [
          path,
        ], mode: ProcessStartMode.detached);
      } on ProcessException catch (e) {
        throw PsitoOpenException(PsitoOpenError.failed, '$e');
      }
    }
  }

  @override
  Future<List<PsitoAppChoice>> appsFor(String mimeType) async => const [];

  @override
  Future<void> setDefaultApp(String mimeType, String appId) async {}

  // No laboratório não há sandbox nem o arrastar entre processos
  @override
  Future<bool> acceptsDrop(List<String> paths) async => false;

  @override
  Future<bool> openDropped(List<String> paths) async => false;

  // O laboratório não tem portal
  @override
  Future<String?> pickFile({
    required String title,
    List<String> patterns = const [],
  }) async => null;
}
