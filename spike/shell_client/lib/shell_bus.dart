// spike/shell_client/lib/shell_bus.dart
//
// O shell no barramento da sessão, para o compositor chamar por um atalho:
//   gdbus call --session --dest org.psito.Shell --object-path /org/psito/Shell \
//     --method org.psito.Shell.ToggleLauncher
// Qualquer compositor que rode um comando num atalho serve (labwc, Wayfire).
import 'package:dbus/dbus.dart';

const shellBusName = 'org.psito.Shell';
const _interface = 'org.psito.Shell';

class ShellBusObject extends DBusObject {
  final void Function() onToggleLauncher;

  ShellBusObject({required this.onToggleLauncher})
    : super(DBusObjectPath('/org/psito/Shell'));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != _interface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch (methodCall.name) {
      case 'ToggleLauncher':
        onToggleLauncher();
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }
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
