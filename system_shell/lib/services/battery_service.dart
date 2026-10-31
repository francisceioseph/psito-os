// system_shell/lib/services/battery_service.dart
//
// Bateria pelo DisplayDevice da UPower: o resumo de todas as baterias.
import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import 'dbus_names.dart';

@immutable
class BatteryState {
  /// A UPower respondeu (com ou sem bateria).
  final bool available;
  final bool present;

  /// 0–100.
  final double percentage;
  final bool charging;
  final bool full;
  final Duration? timeToEmpty;
  final Duration? timeToFull;

  const BatteryState({
    required this.available,
    this.present = false,
    this.percentage = 0,
    this.charging = false,
    this.full = false,
    this.timeToEmpty,
    this.timeToFull,
  });

  static const unavailable = BatteryState(available: false);

  @override
  bool operator ==(Object other) =>
      other is BatteryState &&
      other.available == available &&
      other.present == present &&
      other.percentage == percentage &&
      other.charging == charging &&
      other.full == full &&
      other.timeToEmpty == timeToEmpty &&
      other.timeToFull == timeToFull;

  @override
  int get hashCode => Object.hash(
    available,
    present,
    percentage,
    charging,
    full,
    timeToEmpty,
    timeToFull,
  );
}

abstract class BatteryService {
  ValueListenable<BatteryState> get state;

  Future<void> dispose();
}

class UPowerBatteryService implements BatteryService {
  static const busName = 'org.freedesktop.UPower';
  static const interface = 'org.freedesktop.UPower.Device';
  static final path = DBusObjectPath(
    '/org/freedesktop/UPower/devices/DisplayDevice',
  );

  final DBusClient _bus;
  final _state = ValueNotifier(BatteryState.unavailable);
  final Map<String, DBusValue> _properties = {};
  StreamSubscription<DBusPropertiesChangedSignal>? _changes;

  /// Completa depois da primeira leitura, com ou sem sucesso.
  late final Future<void> ready;

  UPowerBatteryService(this._bus) {
    ready = _load();
  }

  @override
  ValueListenable<BatteryState> get state => _state;

  Future<void> _load() async {
    try {
      if (!await busNameAvailable(_bus, busName)) {
        debugPrint('🦜 $busName não está no barramento');
        return;
      }
      final object = DBusRemoteObject(_bus, name: busName, path: path);
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

  Duration? _seconds(String name) {
    final value = _properties[name];
    final seconds = value is DBusInt64 ? value.value : 0;
    return seconds > 0 ? Duration(seconds: seconds) : null;
  }

  void _publish() {
    final present = _properties['IsPresent'];
    final percentage = _properties['Percentage'];
    final state = _properties['State'];
    // 1 carregando, 2 descarregando, 3 vazia, 4 cheia, 5 na tomada sem
    // carregar, 6 descarregando sem estimativa
    final code = state is DBusUint32 ? state.value : 0;
    _state.value = BatteryState(
      available: true,
      present: present is DBusBoolean && present.value,
      percentage: percentage is DBusDouble ? percentage.value : 0,
      charging: code == 1,
      full: code == 4,
      timeToEmpty: _seconds('TimeToEmpty'),
      timeToFull: _seconds('TimeToFull'),
    );
  }

  @override
  Future<void> dispose() async {
    await _changes?.cancel();
    _state.dispose();
  }
}

class FakeBatteryService implements BatteryService {
  final ValueNotifier<BatteryState> _state;

  FakeBatteryService([BatteryState initial = sample])
    : _state = ValueNotifier(initial);

  /// Como a VM: a UPower existe, mas não há bateria.
  static const sample = BatteryState(available: true);

  @override
  ValueListenable<BatteryState> get state => _state;

  void set(BatteryState state) => _state.value = state;

  @override
  Future<void> dispose() async => _state.dispose();
}
