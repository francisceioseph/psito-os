// system_shell/lib/services/session_service.dart
//
// Desligar, reiniciar e suspender pelo systemd-logind.
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import 'dbus_names.dart';

@immutable
class SessionCapabilities {
  final bool canPowerOff;
  final bool canReboot;
  final bool canSuspend;

  const SessionCapabilities({
    this.canPowerOff = false,
    this.canReboot = false,
    this.canSuspend = false,
  });

  static const none = SessionCapabilities();
  static const all = SessionCapabilities(
    canPowerOff: true,
    canReboot: true,
    canSuspend: true,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionCapabilities &&
      other.canPowerOff == canPowerOff &&
      other.canReboot == canReboot &&
      other.canSuspend == canSuspend;

  @override
  int get hashCode => Object.hash(canPowerOff, canReboot, canSuspend);

  @override
  String toString() {
    final names = [
      if (canPowerOff) 'poweroff',
      if (canReboot) 'reboot',
      if (canSuspend) 'suspend',
    ];
    return names.isEmpty ? 'nenhuma' : names.join(',');
  }
}

abstract class SessionService {
  ValueListenable<SessionCapabilities> get capabilities;

  Future<void> powerOff();

  Future<void> reboot();

  Future<void> suspend();

  Future<void> dispose();
}

class LogindSessionService implements SessionService {
  static const busName = 'org.freedesktop.login1';
  static const interface = 'org.freedesktop.login1.Manager';
  static final path = DBusObjectPath('/org/freedesktop/login1');

  final DBusClient _bus;
  late final _manager = DBusRemoteObject(_bus, name: busName, path: path);
  final _capabilities = ValueNotifier(SessionCapabilities.none);

  /// Completa depois da primeira leitura, com ou sem sucesso.
  late final Future<void> ready;

  LogindSessionService(this._bus) {
    ready = _load();
  }

  @override
  ValueListenable<SessionCapabilities> get capabilities => _capabilities;

  /// Só "yes" serve: "challenge" pediria senha a um agente do polkit, que a
  /// interface não tem.
  Future<bool> _can(String method) async {
    final reply = await _manager.callMethod(
      interface,
      method,
      [],
      replySignature: DBusSignature('s'),
    );
    return reply.values.first.asString() == 'yes';
  }

  Future<void> _load() async {
    try {
      if (!await busNameAvailable(_bus, busName)) {
        debugPrint('🦜 $busName não está no barramento');
        return;
      }
      _capabilities.value = SessionCapabilities(
        canPowerOff: await _can('CanPowerOff'),
        canReboot: await _can('CanReboot'),
        canSuspend: await _can('CanSuspend'),
      );
    } catch (e) {
      debugPrint('🦜 Erro lendo $busName: $e');
    }
  }

  // interactive=false: sem diálogo de senha, o polkit decide sozinho
  Future<void> _call(String method) async {
    try {
      await _manager.callMethod(interface, method, [
        const DBusBoolean(false),
      ], replySignature: DBusSignature(''));
    } catch (e) {
      debugPrint('🦜 Erro no $method: $e');
    }
  }

  @override
  Future<void> powerOff() => _call('PowerOff');

  @override
  Future<void> reboot() => _call('Reboot');

  @override
  Future<void> suspend() => _call('Suspend');

  @override
  Future<void> dispose() async => _capabilities.dispose();
}

class FakeSessionService implements SessionService {
  final ValueNotifier<SessionCapabilities> _capabilities;

  /// Ações pedidas, na ordem: 'powerOff', 'reboot', 'suspend'.
  final List<String> calls = [];

  FakeSessionService([SessionCapabilities initial = SessionCapabilities.all])
    : _capabilities = ValueNotifier(initial);

  @override
  ValueListenable<SessionCapabilities> get capabilities => _capabilities;

  void set(SessionCapabilities capabilities) =>
      _capabilities.value = capabilities;

  @override
  Future<void> powerOff() async => calls.add('powerOff');

  @override
  Future<void> reboot() async => calls.add('reboot');

  @override
  Future<void> suspend() async => calls.add('suspend');

  @override
  Future<void> dispose() async => _capabilities.dispose();
}
