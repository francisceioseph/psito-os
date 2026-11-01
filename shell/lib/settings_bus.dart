// shell/lib/settings_bus.dart
//
// O shell guarda as configurações (o SettingsStore sobre o settings.json) e
// as serve aos apps em org.psito.Settings: Get, Update e o sinal Changed. O
// cliente é o SettingsClient do psito_services.
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:psito_services/settings_client.dart';
import 'package:system_shell/shell/settings_store.dart';

import 'desktop_entries.dart';

/// Se quem mandou a mensagem (o nome único no barramento) pode chamar o
/// `Update`.
typedef SettingsAuthorizer = Future<bool> Function(String sender);

class SettingsBusObject extends DBusObject {
  final SettingsStore store;

  /// A segunda trava do `Update`, além do filtro do sandbox. Sem ela, todos
  /// podem.
  final SettingsAuthorizer? mayUpdate;

  SettingsBusObject(this.store, {this.mayUpdate}) : super(settingsPath) {
    store.addListener(_changed);
  }

  void _changed() => emitSignal(settingsInterface, 'Changed', [
    DBusString(encodeSettings(store.value)),
  ]);

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != settingsInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch (methodCall.name) {
      case 'Get':
        return DBusMethodSuccessResponse([
          DBusString(encodeSettings(store.value)),
        ]);
      case 'Update' when methodCall.signature == DBusSignature('s'):
        final sender = methodCall.sender;
        if (mayUpdate != null &&
            (sender == null || !await mayUpdate!(sender))) {
          return DBusMethodErrorResponse.accessDenied(
            'the app lacks the settings permission',
          );
        }
        final settings = decodeSettings(methodCall.values.single.asString());
        if (settings == null) {
          return DBusMethodErrorResponse.invalidArgs('invalid JSON');
        }
        await store.update(settings);
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  @override
  List<DBusIntrospectInterface> introspect() => [
    DBusIntrospectInterface(
      settingsInterface,
      methods: [
        DBusIntrospectMethod(
          'Get',
          args: [
            DBusIntrospectArgument(
              DBusSignature('s'),
              DBusArgumentDirection.out,
              name: 'settings',
            ),
          ],
        ),
        DBusIntrospectMethod(
          'Update',
          args: [
            DBusIntrospectArgument(
              DBusSignature('s'),
              DBusArgumentDirection.in_,
              name: 'settings',
            ),
          ],
        ),
      ],
      signals: [
        DBusIntrospectSignal(
          'Changed',
          args: [
            DBusIntrospectArgument(
              DBusSignature('s'),
              DBusArgumentDirection.out,
              name: 'settings',
            ),
          ],
        ),
      ],
    ),
  ];

  void dispose() => store.removeListener(_changed);
}

/// O id do app (o `.desktop`) de quem mandou a mensagem, pelo cgroup do
/// processo: o `systemd-run` do shell põe cada app numa unidade
/// `app-psito-<id>-….scope`. No sandbox, o processo é o xdg-dbus-proxy do
/// app, que está no mesmo escopo. Null fora de um app.
Future<String?> senderAppId(DBusClient bus, String sender) async {
  try {
    final reply = await bus.callMethod(
      destination: 'org.freedesktop.DBus',
      path: DBusObjectPath('/org/freedesktop/DBus'),
      interface: 'org.freedesktop.DBus',
      name: 'GetConnectionUnixProcessID',
      values: [DBusString(sender)],
      replySignature: DBusSignature('u'),
    );
    final pid = reply.values.single.asUint32();
    return appIdFromCgroup(await File('/proc/$pid/cgroup').readAsString());
  } on Exception {
    return null;
  }
}

/// Registra as configurações na sessão. O shell usa um cliente só para elas:
/// o xdg-dbus-proxy dá ao nome único da conexão a permissão do nome mais
/// aberto dela, e o Notifications e o org.psito.Shell não podem abrir o
/// Update.
Future<void> publishSettings(DBusClient bus, SettingsBusObject object) async {
  await bus.registerObject(object);
  await bus.requestName(
    settingsBusName,
    flags: {
      DBusRequestNameFlag.replaceExisting,
      DBusRequestNameFlag.doNotQueue,
    },
  );
}
