// shell/lib/displays_bus.dart
//
// O shell serve os monitores em org.psito.Displays:
// - List() → aa{sv}, e o sinal Changed() quando muda;
// - Apply(aa{sv}) → s: o PsitoDisplaysResult. O shell pergunta se fica;
// - SetPrimary(s conector).
// Quem passa é o filtro do sandbox (`settings`), e o que muda alguma coisa
// confere também o cgroup de quem chama. O cliente é o DisplaysClient do
// psito_services.
import 'package:dbus/dbus.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/displays_client.dart';

class DisplaysBusObject extends DBusObject {
  final PsitoDisplays displays;

  /// A segunda trava, além do filtro do sandbox. Sem ela, todos podem.
  final Future<bool> Function(String sender)? mayChange;

  DisplaysBusObject(this.displays, {this.mayChange}) : super(displaysPath) {
    displays.displays.addListener(_changed);
  }

  void detach() => displays.displays.removeListener(_changed);

  void _changed() => emitSignal(displaysInterface, 'Changed');

  @override
  List<DBusIntrospectInterface> introspect() => [
    DBusIntrospectInterface(
      displaysInterface,
      methods: [
        DBusIntrospectMethod(
          'List',
          args: [
            DBusIntrospectArgument(
              DBusSignature('aa{sv}'),
              DBusArgumentDirection.out,
            ),
          ],
        ),
        DBusIntrospectMethod(
          'Apply',
          args: [
            DBusIntrospectArgument(
              DBusSignature('aa{sv}'),
              DBusArgumentDirection.in_,
            ),
            DBusIntrospectArgument(
              DBusSignature('s'),
              DBusArgumentDirection.out,
            ),
          ],
        ),
        DBusIntrospectMethod(
          'SetPrimary',
          args: [
            DBusIntrospectArgument(
              DBusSignature('s'),
              DBusArgumentDirection.in_,
            ),
          ],
        ),
      ],
      signals: [DBusIntrospectSignal('Changed')],
    ),
  ];

  Future<bool> _allowed(DBusMethodCall call) async {
    if (mayChange == null) return true;
    final sender = call.sender;
    return sender != null && await mayChange!(sender);
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    final call = methodCall;
    if (call.interface != displaysInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch ((call.name, call.signature.value)) {
      case ('List', ''):
        return DBusMethodSuccessResponse([
          DBusArray(DBusSignature('a{sv}'), [
            for (final display in displays.displays.value)
              displayToDBus(display),
          ]),
        ]);
      case ('Apply', 'aa{sv}'):
        if (!await _allowed(call)) return _denied;
        final result = await displays.apply(
          call.values[0].asArray().map(displayFromDBus).toList(),
        );
        return DBusMethodSuccessResponse([DBusString(result.name)]);
      case ('SetPrimary', 's'):
        if (!await _allowed(call)) return _denied;
        await displays.setPrimary(call.values[0].asString());
        return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }

  static final _denied = DBusMethodErrorResponse.accessDenied(
    'the app lacks the settings permission',
  );
}

Future<void> publishDisplays(DBusClient bus, DisplaysBusObject object) async {
  await bus.registerObject(object);
  await bus.requestName(
    displaysBusName,
    flags: {
      DBusRequestNameFlag.replaceExisting,
      DBusRequestNameFlag.doNotQueue,
    },
  );
}
