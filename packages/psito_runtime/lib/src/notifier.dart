// packages/psito_runtime/lib/src/notifier.dart
//
// As notificações dos apps vão ao org.freedesktop.Notifications da sessão,
// que é o shell do Psito. O desktop-entry faz o shell achar o app (ícone,
// nome e a janela a ativar no clique).
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';

class Notifier {
  final DBusClient _bus;
  final String appName;
  final String desktopEntry;

  Notifier(this._bus, {required this.appName, required this.desktopEntry});

  Future<void> notify(PsitoNotification n) async {
    try {
      await DBusRemoteObject(
        _bus,
        name: 'org.freedesktop.Notifications',
        path: DBusObjectPath('/org/freedesktop/Notifications'),
      ).callMethod('org.freedesktop.Notifications', 'Notify', [
        DBusString(appName),
        const DBusUint32(0),
        const DBusString(''),
        DBusString(n.title),
        DBusString(n.body ?? ''),
        DBusArray.string(const []),
        DBusDict.stringVariant({'desktop-entry': DBusString(desktopEntry)}),
        const DBusInt32(-1),
      ], replySignature: DBusSignature('u'));
    } on Exception catch (e) {
      debugPrint('🦜 $desktopEntry: notificação não entregue ($e)');
    }
  }
}
