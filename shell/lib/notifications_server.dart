// shell/lib/notifications_server.dart
//
// O shell como servidor de notificações da sessão (org.freedesktop.Notifications,
// a especificação 1.2 do freedesktop): notify-send, o Firefox e os apps GTK
// viram toasts e entram no painel. O id no D-Bus é o do NotificationCenter
// mais 1, porque o 0 quer dizer "nenhuma".
import 'package:dbus/dbus.dart';
import 'package:system_shell/shell/notification_center.dart';

const notificationsBusName = 'org.freedesktop.Notifications';
const _interface = 'org.freedesktop.Notifications';

/// Uma notificação como chegou pelo `Notify`.
class IncomingNotification {
  final String appName;

  /// O id do NotificationCenter que ela troca, ou nulo.
  final int? replaces;
  final String appIcon;
  final String summary;
  final String body;

  /// As chaves das ações (a especificação manda pares chave, rótulo).
  final List<String> actions;

  /// O hint `desktop-entry`: o id do `.desktop` de quem notificou.
  final String? desktopEntry;

  const IncomingNotification({
    required this.appName,
    this.replaces,
    this.appIcon = '',
    required this.summary,
    this.body = '',
    this.actions = const [],
    this.desktopEntry,
  });
}

/// O corpo pode vir com marcações (`<b>`, `<a href>`); o shell mostra texto.
String plainText(String body) => body
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&')
    .trim();

class NotificationsServer extends DBusObject {
  /// Põe no centro e devolve o id dele.
  final int Function(IncomingNotification notification) onNotify;

  /// Pedido de quem notificou para tirar a notificação.
  final void Function(int id) onClose;

  NotificationsServer({required this.onNotify, required this.onClose})
    : super(DBusObjectPath('/org/freedesktop/Notifications'));

  /// As que têm a ação `default` (clicar no toast).
  final _withDefault = <int>{};

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != _interface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    final values = methodCall.values;
    switch (methodCall.name) {
      case 'GetCapabilities':
        return DBusMethodSuccessResponse([
          DBusArray.string(['body', 'actions']),
        ]);
      case 'GetServerInformation':
        return DBusMethodSuccessResponse([
          const DBusString('Psito'),
          const DBusString('Psito OS'),
          const DBusString('0.3'),
          const DBusString('1.2'),
        ]);
      case 'Notify' when methodCall.signature == DBusSignature('susssasa{sv}i'):
        final replaces = values[1].asUint32();
        final actions = values[5].asStringArray().toList();
        final hints = values[6].asStringVariantDict();
        final id = onNotify(
          IncomingNotification(
            appName: values[0].asString(),
            replaces: replaces == 0 ? null : replaces - 1,
            appIcon: values[2].asString(),
            summary: values[3].asString(),
            body: plainText(values[4].asString()),
            actions: [for (var i = 0; i < actions.length; i += 2) actions[i]],
            desktopEntry: switch (hints['desktop-entry']) {
              DBusString(:final value) when value.isNotEmpty => value,
              _ => null,
            },
          ),
        );
        if (actions.indexed.any((a) => a.$1.isEven && a.$2 == 'default')) {
          _withDefault.add(id);
        } else {
          _withDefault.remove(id);
        }
        return DBusMethodSuccessResponse([DBusUint32(id + 1)]);
      case 'CloseNotification' when methodCall.signature == DBusSignature('u'):
        onClose(values[0].asUint32() - 1);
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  /// Avisa quem notificou que a notificação saiu (1 expirou, 2 dispensada
  /// pelo usuário, 3 fechada pelo `CloseNotification`).
  Future<void> notifyClosed(int id, NotificationRemoval reason) {
    _withDefault.remove(id);
    return emitSignal(_interface, 'NotificationClosed', [
      DBusUint32(id + 1),
      DBusUint32(switch (reason) {
        NotificationRemoval.dismissed => 2,
        NotificationRemoval.closed => 3,
      }),
    ]);
  }

  /// O clique no toast: a ação `default`, se quem notificou pediu uma.
  Future<void> invokeDefault(int id) async {
    if (!_withDefault.contains(id)) return;
    await emitSignal(_interface, 'ActionInvoked', [
      DBusUint32(id + 1),
      const DBusString('default'),
    ]);
  }

  @override
  List<DBusIntrospectInterface> introspect() => [
    DBusIntrospectInterface(
      _interface,
      methods: [
        DBusIntrospectMethod(
          'GetCapabilities',
          args: [_out('as', 'capabilities')],
        ),
        DBusIntrospectMethod(
          'Notify',
          args: [
            _in('s', 'app_name'),
            _in('u', 'replaces_id'),
            _in('s', 'app_icon'),
            _in('s', 'summary'),
            _in('s', 'body'),
            _in('as', 'actions'),
            _in('a{sv}', 'hints'),
            _in('i', 'expire_timeout'),
            _out('u', 'id'),
          ],
        ),
        DBusIntrospectMethod('CloseNotification', args: [_in('u', 'id')]),
        DBusIntrospectMethod(
          'GetServerInformation',
          args: [
            _out('s', 'name'),
            _out('s', 'vendor'),
            _out('s', 'version'),
            _out('s', 'spec_version'),
          ],
        ),
      ],
      signals: [
        DBusIntrospectSignal(
          'NotificationClosed',
          args: [_signal('u', 'id'), _signal('u', 'reason')],
        ),
        DBusIntrospectSignal(
          'ActionInvoked',
          args: [_signal('u', 'id'), _signal('s', 'action_key')],
        ),
      ],
    ),
  ];
}

DBusIntrospectArgument _in(String type, String name) => DBusIntrospectArgument(
  DBusSignature(type),
  DBusArgumentDirection.in_,
  name: name,
);

DBusIntrospectArgument _out(String type, String name) => DBusIntrospectArgument(
  DBusSignature(type),
  DBusArgumentDirection.out,
  name: name,
);

DBusIntrospectArgument _signal(String type, String name) =>
    DBusIntrospectArgument(
      DBusSignature(type),
      DBusArgumentDirection.out,
      name: name,
    );

/// Assina o nome na sessão, tirando outro servidor que já esteja lá.
Future<void> publishNotifications(
  DBusClient bus,
  NotificationsServer server,
) async {
  await bus.registerObject(server);
  await bus.requestName(
    notificationsBusName,
    flags: {
      DBusRequestNameFlag.replaceExisting,
      DBusRequestNameFlag.doNotQueue,
    },
  );
}
