import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_shell/notifications_server.dart';
import 'package:system_shell/shell/notification_center.dart';

void main() {
  late Directory dir;
  late DBusServer server;
  late DBusClient shellBus;
  late DBusClient appBus;
  late NotificationsServer notifications;
  late List<IncomingNotification> received;
  late List<int> closed;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('psito_notify_');
    server = DBusServer();
    final address = await server.listenAddress(DBusAddress.unix(dir: dir));
    shellBus = DBusClient(address);
    appBus = DBusClient(address);
    received = [];
    closed = [];
    notifications = NotificationsServer(
      onNotify: (n) {
        received.add(n);
        return n.replaces ?? received.length - 1;
      },
      onClose: closed.add,
    );
    await publishNotifications(shellBus, notifications);
  });

  tearDown(() async {
    await appBus.close();
    await shellBus.close();
    await server.close();
    await dir.delete(recursive: true);
  });

  final remote = DBusRemoteObject.new;

  Future<DBusMethodSuccessResponse> call(String method, List<DBusValue> args) =>
      remote(
        appBus,
        name: notificationsBusName,
        path: DBusObjectPath('/org/freedesktop/Notifications'),
      ).callMethod('org.freedesktop.Notifications', method, args);

  List<DBusValue> notify(
    String summary, {
    int replaces = 0,
    String body = '',
  }) => [
    const DBusString('notify-send'),
    DBusUint32(replaces),
    const DBusString('dialog-information'),
    DBusString(summary),
    DBusString(body),
    DBusArray.string(['default', 'Abrir']),
    DBusDict.stringVariant({
      'desktop-entry': const DBusString('org.example.App'),
      'urgency': const DBusByte(1),
    }),
    const DBusInt32(-1),
  ];

  test('Notify devolve o id mais 1 e tira as marcações do corpo', () async {
    final reply = await call(
      'Notify',
      notify('oi', body: '<b>negrito</b> &amp; <a href="x">link</a>'),
    );
    expect(reply.returnValues.single, const DBusUint32(1));
    final n = received.single;
    expect(n.summary, 'oi');
    expect(n.body, 'negrito & link');
    expect(n.desktopEntry, 'org.example.App');
    expect(n.actions, ['default']);
    expect(n.replaces, isNull);

    // replaces_id 1 é o 0 do centro
    final again = await call('Notify', notify('de novo', replaces: 1));
    expect(again.returnValues.single, const DBusUint32(1));
    expect(received.last.replaces, 0);
  });

  test('CloseNotification e os sinais', () async {
    final signals = <DBusSignal>[];
    final sub = DBusSignalStream(
      appBus,
      interface: 'org.freedesktop.Notifications',
    ).listen(signals.add);
    await call('Notify', notify('oi'));

    await call('CloseNotification', [const DBusUint32(1)]);
    expect(closed, [0]);

    await notifications.invokeDefault(0);
    await notifications.notifyClosed(0, NotificationRemoval.closed);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(signals.map((s) => s.name), ['ActionInvoked', 'NotificationClosed']);
    expect(signals.first.values, [
      const DBusUint32(1),
      const DBusString('default'),
    ]);
    expect(signals.last.values, [const DBusUint32(1), const DBusUint32(3)]);
    await sub.cancel();
  });

  test('GetCapabilities e GetServerInformation', () async {
    final caps = await call('GetCapabilities', []);
    expect(caps.returnValues.single.asStringArray(), ['body', 'actions']);
    final info = await call('GetServerInformation', []);
    expect(info.returnValues.first, const DBusString('Psito'));
    expect(info.returnValues.last, const DBusString('1.2'));
  });
}
