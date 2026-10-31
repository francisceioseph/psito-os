// shell/lib/settings_bus.dart
//
// O shell guarda as configurações (o SettingsStore sobre o settings.json) e
// as serve aos apps em org.psito.Settings: Get, Update e o sinal Changed. O
// cliente é o SettingsClient do psito_services.
import 'package:dbus/dbus.dart';
import 'package:psito_services/settings_client.dart';
import 'package:system_shell/shell/settings_store.dart';

class SettingsBusObject extends DBusObject {
  final SettingsStore store;

  SettingsBusObject(this.store) : super(settingsPath) {
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
        final settings = decodeSettings(methodCall.values.single.asString());
        if (settings == null) {
          return DBusMethodErrorResponse.invalidArgs('JSON inválido');
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

/// Registra as configurações na sessão, no mesmo cliente do shell.
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
