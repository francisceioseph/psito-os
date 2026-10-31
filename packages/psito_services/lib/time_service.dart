// packages/psito_services/lib/time_service.dart
//
// Fuso e NTP pelo systemd-timedated. A hora local é calculada com o pacote
// timezone: o DateTime.now() do Dart guarda o fuso de quando o processo
// começou (o glibc não relê o /etc/localtime).
import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dbus_names.dart';

abstract class TimeService {
  ValueListenable<PsitoTimeState> get state;

  /// Hora local no fuso atual do sistema.
  DateTime now();

  Future<List<String>> timezones();

  Future<void> setTimezone(String timezone);

  Future<void> setNtp(bool enabled);

  Future<void> dispose();
}

bool _tzReady = false;

/// Fuso pelo nome IANA; null se a base não conhece.
tz.Location? locationFor(String name) {
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  try {
    return tz.getLocation(name);
  } on tz.LocationNotFoundException {
    return null;
  }
}

class TimedatedTimeService implements TimeService {
  static const busName = 'org.freedesktop.timedate1';
  static const interface = 'org.freedesktop.timedate1';
  static final path = DBusObjectPath('/org/freedesktop/timedate1');

  final DBusClient _bus;
  late final _object = DBusRemoteObject(_bus, name: busName, path: path);
  final _state = ValueNotifier(PsitoTimeState.unavailable);
  final Map<String, DBusValue> _properties = {};
  StreamSubscription<DBusPropertiesChangedSignal>? _changes;
  tz.Location? _location;
  String? _warnedTimezone;
  List<String>? _timezones;

  /// Completa depois da primeira leitura, com ou sem sucesso.
  late final Future<void> ready;

  TimedatedTimeService(this._bus) {
    ready = _load();
  }

  @override
  ValueListenable<PsitoTimeState> get state => _state;

  Future<void> _load() async {
    try {
      if (!await busNameAvailable(_bus, busName)) {
        debugPrint('🦜 $busName não está no barramento');
        return;
      }
      _changes = _object.propertiesChanged.listen((signal) {
        if (signal.propertiesInterface != interface) return;
        _properties.addAll(signal.changedProperties);
        _publish();
      });
      await _reload();
    } catch (e) {
      debugPrint('🦜 Erro lendo $busName: $e');
    }
  }

  Future<void> _reload() async {
    _properties.addAll(await _object.getAllProperties(interface));
    _publish();
  }

  bool _bool(String name) {
    final value = _properties[name];
    return value is DBusBoolean && value.value;
  }

  void _publish() {
    final timezone = _properties['Timezone'];
    final name = timezone is DBusString ? timezone.value : '';
    _location = locationFor(name);
    if (_location == null && _warnedTimezone != name) {
      _warnedTimezone = name;
      debugPrint('🦜 Fuso "$name" desconhecido; usando o relógio local');
    }
    _state.value = PsitoTimeState(
      available: true,
      timezone: name,
      ntp: _bool('NTP'),
      ntpSynchronized: _bool('NTPSynchronized'),
      canNtp: _bool('CanNTP'),
    );
  }

  @override
  DateTime now() {
    final location = _location;
    return location == null ? DateTime.now() : tz.TZDateTime.now(location);
  }

  @override
  Future<List<String>> timezones() async {
    final cached = _timezones;
    if (cached != null) return cached;
    try {
      final reply = await _object.callMethod(
        interface,
        'ListTimezones',
        [],
        replySignature: DBusSignature('as'),
      );
      return _timezones = reply.values.first.asStringArray().toList();
    } catch (e) {
      debugPrint('🦜 Erro listando fusos: $e');
      return const [];
    }
  }

  // interactive=false: sem diálogo de senha, o polkit decide sozinho
  Future<void> _call(String method, List<DBusValue> args) async {
    try {
      await _object.callMethod(interface, method, [
        ...args,
        const DBusBoolean(false),
      ], replySignature: DBusSignature(''));
    } catch (e) {
      debugPrint('🦜 Erro no $method: $e');
    }
  }

  @override
  Future<void> setTimezone(String timezone) =>
      _call('SetTimezone', [DBusString(timezone)]);

  /// NTPSynchronized não avisa quando muda: relê tudo depois.
  @override
  Future<void> setNtp(bool enabled) async {
    await _call('SetNTP', [DBusBoolean(enabled)]);
    try {
      await _reload();
    } catch (e) {
      debugPrint('🦜 Erro relendo $busName: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _changes?.cancel();
    _state.dispose();
  }
}

class FakeTimeService implements TimeService {
  final ValueNotifier<PsitoTimeState> _state;
  final DateTime Function() _clock;

  FakeTimeService({PsitoTimeState initial = sample, DateTime Function()? clock})
    : _state = ValueNotifier(initial),
      _clock = clock ?? DateTime.now;

  static const sample = PsitoTimeState(
    available: true,
    timezone: 'America/Fortaleza',
    ntp: true,
    ntpSynchronized: true,
    canNtp: true,
  );

  static const sampleTimezones = [
    'America/Fortaleza',
    'America/Sao_Paulo',
    'Asia/Tokyo',
    'Europe/Lisbon',
    'UTC',
  ];

  @override
  ValueListenable<PsitoTimeState> get state => _state;

  void set(PsitoTimeState state) => _state.value = state;

  @override
  DateTime now() => _clock();

  @override
  Future<List<String>> timezones() async => sampleTimezones;

  @override
  Future<void> setTimezone(String timezone) async =>
      _update(timezone: timezone);

  @override
  Future<void> setNtp(bool enabled) async =>
      _update(ntp: enabled, ntpSynchronized: enabled);

  void _update({String? timezone, bool? ntp, bool? ntpSynchronized}) {
    final s = _state.value;
    _state.value = PsitoTimeState(
      available: s.available,
      timezone: timezone ?? s.timezone,
      ntp: ntp ?? s.ntp,
      ntpSynchronized: ntpSynchronized ?? s.ntpSynchronized,
      canNtp: s.canNtp,
    );
  }

  @override
  Future<void> dispose() async => _state.dispose();
}
