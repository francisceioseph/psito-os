// packages/psito_services/lib/displays_client.dart
//
// Os monitores para as Configurações (org.psito.Displays na sessão). No sandbox,
// só passa quem tem `settings`. O servidor é o shell/lib/displays_bus.dart.
import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';

const displaysBusName = 'org.psito.Displays';
const displaysInterface = 'org.psito.Displays';
final displaysPath = DBusObjectPath('/org/psito/Displays');

DBusValue _modeToDBus(PsitoDisplayMode mode) => DBusStruct([
  DBusInt32(mode.width),
  DBusInt32(mode.height),
  DBusInt32(mode.refresh),
  DBusBoolean(mode.preferred),
]);

PsitoDisplayMode _modeFromDBus(DBusValue value) {
  final fields = value.asStruct();
  return PsitoDisplayMode(
    fields[0].asInt32(),
    fields[1].asInt32(),
    refresh: fields[2].asInt32(),
    preferred: fields[3].asBoolean(),
  );
}

/// Como um monitor vai pelo barramento. Sem modo, a lista de `mode` fica vazia.
DBusValue displayToDBus(PsitoDisplay d) => DBusDict.stringVariant({
  'name': DBusString(d.name),
  'label': DBusString(d.label),
  'enabled': DBusBoolean(d.enabled),
  'primary': DBusBoolean(d.primary),
  'x': DBusInt32(d.x),
  'y': DBusInt32(d.y),
  'transform': DBusInt32(d.transform),
  'scale': DBusDouble(d.scale),
  'mode': DBusArray(DBusSignature('(iiib)'), [
    if (d.mode case final mode?) _modeToDBus(mode),
  ]),
  'modes': DBusArray(DBusSignature('(iiib)'), d.modes.map(_modeToDBus)),
});

PsitoDisplay displayFromDBus(DBusValue value) {
  final map = value.asStringVariantDict();
  return PsitoDisplay(
    name: map['name']?.asString() ?? '',
    label: map['label']?.asString() ?? '',
    enabled: map['enabled']?.asBoolean() ?? false,
    primary: map['primary']?.asBoolean() ?? false,
    x: map['x']?.asInt32() ?? 0,
    y: map['y']?.asInt32() ?? 0,
    transform: map['transform']?.asInt32() ?? 0,
    scale: map['scale']?.asDouble() ?? 1,
    mode: map['mode']?.asArray().map(_modeFromDBus).firstOrNull,
    modes: map['modes']?.asArray().map(_modeFromDBus).toList() ?? const [],
  );
}

class DisplaysClient implements PsitoDisplays {
  late final DBusRemoteObject _object = DBusRemoteObject(
    _bus,
    name: displaysBusName,
    path: displaysPath,
  );
  final DBusClient _bus;
  final _displays = ValueNotifier<List<PsitoDisplay>>(const []);
  StreamSubscription<DBusSignal>? _changed;

  DisplaysClient(this._bus) {
    _changed = DBusSignalStream(
      _bus,
      interface: displaysInterface,
      name: 'Changed',
      path: displaysPath,
    ).listen((_) => unawaited(load()));
    unawaited(load());
  }

  Future<void> dispose() async {
    await _changed?.cancel();
    _displays.dispose();
  }

  @override
  ValueListenable<List<PsitoDisplay>> get displays => _displays;

  @visibleForTesting
  Future<void> load() async {
    try {
      final reply = await _object.callMethod(
        displaysInterface,
        'List',
        const [],
        replySignature: DBusSignature('aa{sv}'),
      );
      _displays.value = reply.returnValues[0]
          .asArray()
          .map(displayFromDBus)
          .toList();
    } catch (e) {
      debugPrint('🦜 Sem a lista dos monitores: $e');
    }
  }

  @override
  Future<PsitoDisplaysResult> apply(List<PsitoDisplay> displays) async {
    try {
      final reply = await _object.callMethod(displaysInterface, 'Apply', [
        DBusArray(DBusSignature('a{sv}'), displays.map(displayToDBus)),
      ], replySignature: DBusSignature('s'));
      return PsitoDisplaysResult.values.asNameMap()[reply.returnValues[0]
              .asString()] ??
          PsitoDisplaysResult.failed;
    } catch (e) {
      debugPrint('🦜 Sem aplicar os monitores: $e');
      return PsitoDisplaysResult.failed;
    }
  }

  @override
  Future<void> setPrimary(String name) async {
    try {
      await _object.callMethod(displaysInterface, 'SetPrimary', [
        DBusString(name),
      ], replySignature: DBusSignature(''));
    } catch (e) {
      debugPrint('🦜 Sem trocar o monitor principal: $e');
    }
  }
}

/// Dois monitores lado a lado, sem pedir confirmação a ninguém.
class FakeDisplays implements PsitoDisplays {
  static const laptopName = 'Psito Laptop';
  static const monitorName = 'Psito Monitor';
  static const modes = [
    PsitoDisplayMode(2560, 1440, preferred: true),
    PsitoDisplayMode(2560, 1440, refresh: 144000),
    PsitoDisplayMode(1920, 1080),
    PsitoDisplayMode(1280, 720),
  ];
  static const laptopModes = [
    PsitoDisplayMode(1920, 1080, preferred: true),
    PsitoDisplayMode(1280, 720),
  ];

  final ValueNotifier<List<PsitoDisplay>> list;
  PsitoDisplaysResult result = PsitoDisplaysResult.ok;
  final applied = <List<PsitoDisplay>>[];

  FakeDisplays({List<PsitoDisplay>? displays})
    : list = ValueNotifier(
        displays ??
            [
              PsitoDisplay(
                name: 'eDP-1',
                label: laptopName,
                primary: true,
                mode: laptopModes.first,
                modes: laptopModes,
              ),
              PsitoDisplay(
                name: 'HDMI-A-1',
                label: monitorName,
                x: 1920,
                mode: modes.first,
                modes: modes,
              ),
            ],
      );

  @override
  ValueListenable<List<PsitoDisplay>> get displays => list;

  @override
  Future<PsitoDisplaysResult> apply(List<PsitoDisplay> displays) async {
    applied.add(displays);
    if (result == PsitoDisplaysResult.ok) list.value = displays;
    return result;
  }

  @override
  Future<void> setPrimary(String name) async {
    list.value = [
      for (final display in list.value)
        display.copyWith(primary: display.name == name),
    ];
  }
}
