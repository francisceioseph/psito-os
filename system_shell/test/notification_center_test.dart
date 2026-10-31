import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/shell/app_entry.dart';
import 'package:system_shell/shell/notification_center.dart';
import 'package:system_shell/shell/window_manager.dart';

import 'helpers.dart';

final _window = ShellWindow(
  id: 'fake#0',
  app: const FakeApp('fake', name: 'Fake'),
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

  test('add com replaces troca a notificação e mantém o id', () {
    final c = _center();
    final app = AppEntry.fromPsitoApp(const FakeApp('fake', name: 'Fake'));
    final id = c.add(app: app, title: 'baixando', body: '10%');
    c.add(app: app, title: 'outra');
    expect(c.add(app: app, title: 'baixando', body: '90%', replaces: id), id);

    expect(c.history, hasLength(2));
    expect(c.history.last.body, '90%');
    expect(c.history.last.windowId, isNull);
    expect(c.toasts.first.id, id);
    expect(c.toasts, hasLength(2));
    expect(c.unreadCount, 2);

    // Um replaces que não existe mais vira uma notificação nova
    expect(c.add(app: app, title: 'nova', replaces: 999), isNot(999));
    c.dispose();
  });

  test('onRemoved diz quem tirou a notificação', () {
    final removed = <(int, NotificationRemoval)>[];
    final c = NotificationCenter(
      toastDuration: const Duration(hours: 1),
      onRemoved: (id, reason) => removed.add((id, reason)),
    );
    _post(c, 'a');
    _post(c, 'b');
    _post(c, 'c');
    final [cId, bId, aId] = [for (final n in c.history) n.id];

    c.dismissToast(aId);
    expect(removed, isEmpty);
    c.dismiss(aId);
    c.close(bId);
    c.close(bId);
    c.clear();
    expect(removed, [
      (aId, NotificationRemoval.dismissed),
      (bId, NotificationRemoval.closed),
      (cId, NotificationRemoval.dismissed),
    ]);
    c.dispose();
  });
}
