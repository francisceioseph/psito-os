// system_shell/lib/services/system_info_service.dart
//
// Nome do computador e versões do sistema, lidos do systemd-hostnamed.
import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';

abstract class SystemInfoService {
  ValueListenable<PsitoSystemInfo> get info;

  Future<void> dispose();
}

class HostnamedSystemInfoService implements SystemInfoService {
  static const busName = 'org.freedesktop.hostname1';
  static const interface = 'org.freedesktop.hostname1';
  static final path = DBusObjectPath('/org/freedesktop/hostname1');

  final DBusClient _client;
  final _info = ValueNotifier(PsitoSystemInfo.unavailable);
  final Map<String, DBusValue> _properties = {};
  StreamSubscription<DBusPropertiesChangedSignal>? _changes;

  /// Completa depois da primeira leitura, com ou sem sucesso.
  late final Future<void> ready;

  /// Não espera o barramento: começa indisponível e carrega em segundo plano.
  HostnamedSystemInfoService(this._client) {
    ready = _load();
  }

  @override
  ValueListenable<PsitoSystemInfo> get info => _info;

  Future<void> _load() async {
    try {
      if (!await _client.nameHasOwner(busName)) {
        debugPrint('🦜 $busName não está no barramento');
        return;
      }
      final object = DBusRemoteObject(_client, name: busName, path: path);
      _changes = object.propertiesChanged.listen((signal) {
        if (signal.propertiesInterface != interface) return;
        _properties.addAll(signal.changedProperties);
        _publish();
      });
      _properties.addAll(await object.getAllProperties(interface));
      _publish();
    } catch (e) {
      debugPrint('🦜 Erro lendo $busName: $e');
    }
  }

  String _string(String name) {
    final value = _properties[name];
    return value is DBusString ? value.value.trim() : '';
  }

  void _publish() {
    final pretty = _string('PrettyHostname');
    final hardware = [
      _string('HardwareVendor'),
      _string('HardwareModel'),
    ].where((s) => s.isNotEmpty).join(' ');
    _info.value = PsitoSystemInfo(
      available: true,
      hostname: pretty.isNotEmpty ? pretty : _string('Hostname'),
      osName: _string('OperatingSystemPrettyName'),
      kernel: _string('KernelRelease'),
      hardware: hardware.isEmpty ? null : hardware,
    );
  }

  @override
  Future<void> dispose() async {
    await _changes?.cancel();
    _info.dispose();
  }
}

class FakeSystemInfoService implements SystemInfoService {
  final ValueNotifier<PsitoSystemInfo> _info;

  FakeSystemInfoService([PsitoSystemInfo initial = sample])
    : _info = ValueNotifier(initial);

  static const sample = PsitoSystemInfo(
    available: true,
    hostname: 'psito-fake',
    osName: 'Psito OS (serviços falsos)',
    kernel: '0.0.0-fake',
  );

  @override
  ValueListenable<PsitoSystemInfo> get info => _info;

  void set(PsitoSystemInfo info) => _info.value = info;

  @override
  Future<void> dispose() async => _info.dispose();
}
