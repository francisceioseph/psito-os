// system_shell/lib/shell/notification_center.dart
//
// Histórico de notificações e toasts ativos, sem UI.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'app_entry.dart';
import 'window_manager.dart';

class ShellNotification {
  final int id;

  /// Janela que notificou; pode já ter sido fechada. Nula quando a
  /// notificação veio de fora (pelo D-Bus).
  final String? windowId;
  final AppEntry app;
  final String title;
  final String? body;
  final DateTime time;

  const ShellNotification({
    required this.id,
    this.windowId,
    required this.app,
    required this.title,
    this.body,
    required this.time,
  });

  String get appId => app.id;
  String get appName => app.name;
  Color get color => app.color;
}

/// Por que uma notificação saiu do histórico.
enum NotificationRemoval { dismissed, closed }

class NotificationCenter extends ChangeNotifier {
  static const historyLimit = 50;
  static const maxToasts = 3;

  NotificationCenter({
    this.toastDuration = const Duration(seconds: 5),
    this.silent,
    this.onRemoved,
  });

  final Duration toastDuration;

  /// "Não perturbe": se true, a notificação só vai para o histórico.
  final bool Function()? silent;

  /// Chamado quando uma notificação sai do histórico.
  final void Function(int id, NotificationRemoval reason)? onRemoved;

  final List<ShellNotification> _history = [];
  final List<ShellNotification> _toasts = [];
  final Map<int, Timer> _toastTimers = {};
  int _unread = 0;
  int _nextId = 0;

  /// Mais nova primeiro.
  List<ShellNotification> get history => List.unmodifiable(_history);

  /// Toasts na tela, mais novo primeiro.
  List<ShellNotification> get toasts => List.unmodifiable(_toasts);
  int get unreadCount => _unread;

  void post(ShellWindow window, PsitoNotification notification) => add(
    app: AppEntry.fromPsitoApp(window.app),
    windowId: window.id,
    title: notification.title,
    body: notification.body,
  );

  /// Põe uma notificação no histórico e na tela e devolve o id dela. Com
  /// [replaces] de uma que ainda está no histórico, ela é trocada e mantém o
  /// id.
  int add({
    required AppEntry app,
    required String title,
    String? body,
    String? windowId,
    int? replaces,
  }) {
    final old = replaces == null
        ? -1
        : _history.indexWhere((n) => n.id == replaces);
    final item = ShellNotification(
      id: old >= 0 ? replaces! : _nextId++,
      windowId: windowId,
      app: app,
      title: title,
      body: body,
      time: DateTime.now(),
    );

    if (old >= 0) {
      _history[old] = item;
      _toastTimers.remove(item.id)?.cancel();
      _toasts.removeWhere((n) => n.id == item.id);
    } else {
      _history.insert(0, item);
      if (_history.length > historyLimit) {
        final dropped = _history.removeLast();
        _toastTimers.remove(dropped.id)?.cancel();
        _toasts.removeWhere((n) => n.id == dropped.id);
        onRemoved?.call(dropped.id, NotificationRemoval.dismissed);
      }
      _unread = (_unread + 1).clamp(0, _history.length);
    }

    if (silent?.call() != true) {
      _toasts.insert(0, item);
      while (_toasts.length > maxToasts) {
        _toastTimers.remove(_toasts.removeLast().id)?.cancel();
      }
      _toastTimers[item.id] = Timer(toastDuration, () => dismissToast(item.id));
    }
    notifyListeners();
    return item.id;
  }

  /// Tira só da tela; continua no histórico.
  void dismissToast(int id) {
    _toastTimers.remove(id)?.cancel();
    final before = _toasts.length;
    _toasts.removeWhere((n) => n.id == id);
    if (_toasts.length != before) notifyListeners();
  }

  /// Tira do histórico e da tela, pelo usuário.
  void dismiss(int id) => _remove(id, NotificationRemoval.dismissed);

  /// Tira do histórico e da tela, a pedido de quem notificou.
  void close(int id) => _remove(id, NotificationRemoval.closed);

  void _remove(int id, NotificationRemoval reason) {
    _toastTimers.remove(id)?.cancel();
    _toasts.removeWhere((n) => n.id == id);
    final before = _history.length;
    _history.removeWhere((n) => n.id == id);
    if (_history.length == before) return;
    _unread = _unread.clamp(0, _history.length);
    onRemoved?.call(id, reason);
    notifyListeners();
  }

  void clear() {
    for (final timer in _toastTimers.values) {
      timer.cancel();
    }
    _toastTimers.clear();
    _toasts.clear();
    final removed = [for (final n in _history) n.id];
    _history.clear();
    for (final id in removed) {
      onRemoved?.call(id, NotificationRemoval.dismissed);
    }
    _unread = 0;
    notifyListeners();
  }

  void markAllRead() {
    if (_unread == 0) return;
    _unread = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final timer in _toastTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
