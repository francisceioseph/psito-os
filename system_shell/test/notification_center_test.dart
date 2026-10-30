import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/shell/notification_center.dart';
import 'package:system_shell/shell/window_manager.dart';

class _FakeApp extends PsitoApp {
  const _FakeApp();

  @override
  String get id => 'fake';
  @override
  String get name => 'Fake';
  @override
  IconData get icon => const IconData(0);
  @override
  Color get color => const Color(0xFFFFFFFF);
  @override
  Widget build(PsitoAppContext context) => const SizedBox();
}

final _window = ShellWindow(
  id: 'fake#0',
  app: const _FakeApp(),
  bounds: Rect.zero,
);

NotificationCenter _center() =>
    NotificationCenter(toastDuration: const Duration(hours: 1));

void _post(NotificationCenter c, String title) =>
    c.post(_window, PsitoNotification(title: title));

void main() {
  test('post põe a mais nova primeiro e conta não lidas', () {
    final c = _center();
    _post(c, 'a');
    _post(c, 'b');

    expect(c.history.map((n) => n.title), ['b', 'a']);
    expect(c.toasts.map((n) => n.title), ['b', 'a']);
    expect(c.unreadCount, 2);
    expect(c.history.first.windowId, 'fake#0');
    expect(c.history.first.appName, 'Fake');

    c.markAllRead();
    expect(c.unreadCount, 0);
    c.dispose();
  });

  test('dismissToast só tira da tela; dismiss tira de tudo', () {
    final c = _center();
    _post(c, 'a');
    _post(c, 'b');
    final a = c.history.last;

    c.dismissToast(a.id);
    expect(c.toasts.map((n) => n.title), ['b']);
    expect(c.history, hasLength(2));

    c.dismiss(c.history.first.id);
    expect(c.history.map((n) => n.title), ['a']);
    expect(c.toasts, isEmpty);
    expect(c.unreadCount, 1);
    c.dispose();
  });

  test('clear esvazia tudo', () {
    final c = _center();
    _post(c, 'a');
    c.clear();
    expect(c.history, isEmpty);
    expect(c.toasts, isEmpty);
    expect(c.unreadCount, 0);
    c.dispose();
  });

  test('limites do histórico e dos toasts', () {
    final c = _center();
    for (var i = 0; i < NotificationCenter.historyLimit + 5; i++) {
      _post(c, '$i');
    }
    expect(c.history, hasLength(NotificationCenter.historyLimit));
    expect(c.history.first.title, '${NotificationCenter.historyLimit + 4}');
    expect(c.unreadCount, NotificationCenter.historyLimit);
    expect(c.toasts, hasLength(NotificationCenter.maxToasts));
    c.dispose();
  });
}
