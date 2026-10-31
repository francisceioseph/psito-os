// packages/psito_services/lib/settings_client.dart
//
// As configurações do Psito pelo barramento da sessão. Quem guarda é o shell
// (org.psito.Settings, sobre o settings.json); os apps leem e, se tiverem a
// permissão, gravam por aqui. No sandbox os apps não enxergam o ~/.config.
import 'dart:async';
import 'dart:convert';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';

const settingsBusName = 'org.psito.Settings';
const settingsInterface = 'org.psito.Settings';
final settingsPath = DBusObjectPath('/org/psito/Settings');

/// O JSON do barramento (o mesmo do arquivo).
String encodeSettings(PsitoSettings settings) =>
    jsonEncode(settings.toJson());

/// Null se não for um objeto JSON.
PsitoSettings? decodeSettings(String json) {
  try {
    final value = jsonDecode(json);
    if (value is Map<String, Object?>) return PsitoSettings.fromJson(value);
  } on FormatException {
    // cai no null
  }
  return null;
}

/// As configurações de um app: começa nos padrões, carrega do shell em
/// segundo plano e acompanha o sinal `Changed`.
class SettingsClient extends ValueNotifier<PsitoSettings> {
  final DBusClient _bus;
  late final DBusRemoteObject _shell = DBusRemoteObject(
    _bus,
    name: settingsBusName,
    path: settingsPath,
  );
  StreamSubscription<DBusSignal>? _changed;

  /// Completa quando a primeira leitura terminou, com ou sem sucesso.
  late final Future<void> ready;

  SettingsClient(this._bus) : super(PsitoSettings.defaults) {
    _changed = DBusRemoteObjectSignalStream(
      object: _shell,
      interface: settingsInterface,
      name: 'Changed',
      signature: DBusSignature('s'),
    ).listen((signal) => _set(signal.values.single.asString()));
    ready = _load();
  }

  Future<void> _load() async {
    try {
      final reply = await _shell.callMethod(
        settingsInterface,
        'Get',
        const [],
        replySignature: DBusSignature('s'),
      );
      _set(reply.values.single.asString());
    } on Exception catch (e) {
      debugPrint('🦜 configurações: shell indisponível ($e); usando padrões');
    }
  }

  void _set(String json) {
    final settings = decodeSettings(json);
    if (settings != null) value = settings;
  }

  /// Pede ao shell para gravar. O valor muda quando o `Changed` chegar; um
  /// app sem permissão recebe um erro do filtro do D-Bus.
  Future<bool> update(PsitoSettings settings) async {
    try {
      await _shell.callMethod(settingsInterface, 'Update', [
        DBusString(encodeSettings(settings)),
      ], replySignature: DBusSignature(''));
      return true;
    } on Exception catch (e) {
      debugPrint('🦜 configurações: o shell recusou ($e)');
      return false;
    }
  }

  @override
  void dispose() {
    unawaited(_changed?.cancel());
    super.dispose();
  }
}
