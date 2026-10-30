// system_shell/lib/shell/notification_center.dart
//
// Histórico de notificações e toasts ativos, sem UI.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'window_manager.dart';

class ShellNotification {
  final int id;

  /// Janela que notificou; pode já ter sido fechada.
  final String windowId;
  final String appId;
  final String appName;
  final IconData icon;
  final Color color;
  final String title;
  final String? body;
  final DateTime time;

  const ShellNotification({
    required this.id,
    required this.windowId,
    required this.appId,
    required this.appName,
    required this.icon,
    required this.color,
    required this.title,
    this.body,
    required this.time,
  });
}

class NotificationCenter extends ChangeNotifier {
  static const historyLimit = 50;
  static const maxToasts = 3;

  NotificationCenter({
    this.toastDuration = const Duration(seconds: 5),
    this.silent,
  });

  final Duration toastDuration;

  /// "Não perturbe": se true, a notificação só vai para o histórico.
  final bool Function()? silent;

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

  void post(ShellWindow window, PsitoNotification notification) {
    final app = window.app;
    final item = ShellNotification(
      id: _nextId++,
      windowId: window.id,
      appId: app.id,
      appName: app.name,
      icon: app.icon,
      color: app.color,
      title: notification.title,
      body: notification.body,
      time: DateTime.now(),
    );

    _history.insert(0, item);
    if (_history.length > historyLimit) _history.removeLast();
    _unread = (_unread + 1).clamp(0, _history.length);

    if (silent?.call() != true) {
      _toasts.insert(0, item);
      while (_toasts.length > maxToasts) {
        _toastTimers.remove(_toasts.removeLast().id)?.cancel();
      }
      _toastTimers[item.id] = Timer(toastDuration, () => dismissToast(item.id));
    }
    notifyListeners();
  }

  /// Tira só da tela; continua no histórico.
  void dismissToast(int id) {
    _toastTimers.remove(id)?.cancel();
    final before = _toasts.length;
    _toasts.removeWhere((n) => n.id == id);
    if (_toasts.length != before) notifyListeners();
  }

  /// Tira do histórico e da tela.
  void dismiss(int id) {
    _toastTimers.remove(id)?.cancel();
    _toasts.removeWhere((n) => n.id == id);
    _history.removeWhere((n) => n.id == id);
    _unread = _unread.clamp(0, _history.length);
    notifyListeners();
  }

  void clear() {
    for (final timer in _toastTimers.values) {
      timer.cancel();
    }
    _toastTimers.clear();
    _toasts.clear();
    _history.clear();
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
