// spike/shell_client/lib/shell_bus.dart
//
// O shell no barramento da sessão, para o compositor chamar por um atalho:
//   gdbus call --session --dest org.psito.Shell --object-path /org/psito/Shell \
//     --method org.psito.Shell.Run "'switchNext'"
// O argumento é o nome de uma ShellAction. Qualquer compositor que rode um
// comando num atalho serve (labwc, Wayfire); a ponte gera esses atalhos.
import 'package:dbus/dbus.dart';
import 'package:system_shell/shell/shortcuts.dart';

const shellBusName = 'org.psito.Shell';
const _interface = 'org.psito.Shell';

class ShellBusObject extends DBusObject {
  final void Function(ShellAction action) onRun;

  ShellBusObject({required this.onRun})
    : super(DBusObjectPath('/org/psito/Shell'));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != _interface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch (methodCall.name) {
      case 'ToggleLauncher':
        onRun(ShellAction.launcher);
        return DBusMethodSuccessResponse();
      case 'Run' when methodCall.signature == DBusSignature('s'):
        final name = methodCall.values.single.asString();
        final action = ShellAction.values.asNameMap()[name];
        if (action == null) {
          return DBusMethodErrorResponse.invalidArgs(
            'ação desconhecida: $name',
          );
        }
        onRun(action);
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  @override
  List<DBusIntrospectInterface> introspect() => [
    DBusIntrospectInterface(
      _interface,
      methods: [
        DBusIntrospectMethod('ToggleLauncher'),
        DBusIntrospectMethod(
          'Run',
          args: [
            DBusIntrospectArgument(
              DBusSignature('s'),
              DBusArgumentDirection.in_,
              name: 'action',
            ),
          ],
        ),
      ],
    ),
  ];
}

/// Registra o shell na sessão. Devolve o cliente, para fechar no fim.
Future<DBusClient> publishShell(
  ShellBusObject object, {
  DBusClient? client,
}) async {
  final bus = client ?? DBusClient.session();
  await bus.registerObject(object);
  await bus.requestName(
    shellBusName,
    flags: {
      DBusRequestNameFlag.replaceExisting,
      DBusRequestNameFlag.doNotQueue,
    },
  );
  return bus;
}
