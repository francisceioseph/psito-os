// system_shell/lib/services/dbus_names.dart
import 'package:dbus/dbus.dart';

/// O serviço está rodando ou o barramento sobe ele na primeira chamada
/// (ex.: o hostnamed só roda sob demanda).
Future<bool> busNameAvailable(DBusClient bus, String name) async =>
    await bus.nameHasOwner(name) ||
    (await bus.listActivatableNames()).contains(name);
