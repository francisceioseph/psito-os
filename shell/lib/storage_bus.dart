// shell/lib/storage_bus.dart
//
// O shell mede os discos e serve em org.psito.Storage:
// - List() → aa{sv}, e o sinal Changed() quando muda; Refresh() mede de novo;
// - LargestFolders(s pasta) → a(sx), TrashSize() → x;
// - EmptyTrash(), em que o shell pergunta, e OpenFolder(s pasta);
// - Format(s id, s tipo, s nome) → s: o PsitoDiskResult.
// Quem passa é o filtro do sandbox (`settings`), e o que muda alguma coisa
// confere também o cgroup de quem chama. O cliente é o StorageClient do
// psito_services.
import 'package:dbus/dbus.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/storage_client.dart';

class StorageBusObject extends DBusObject {
  final PsitoStorage storage;

  /// A segunda trava, além do filtro do sandbox. Sem ela, todos podem.
  final Future<bool> Function(String sender)? mayChange;

  StorageBusObject(this.storage, {this.mayChange}) : super(storagePath) {
    storage.disks.addListener(_changed);
  }

  void detach() => storage.disks.removeListener(_changed);

  void _changed() => emitSignal(storageInterface, 'Changed');

  @override
  List<DBusIntrospectInterface> introspect() => [
    DBusIntrospectInterface(
      storageInterface,
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
        DBusIntrospectMethod('Refresh'),
        DBusIntrospectMethod(
          'LargestFolders',
          args: [
            DBusIntrospectArgument(
              DBusSignature('s'),
              DBusArgumentDirection.in_,
            ),
            DBusIntrospectArgument(
              DBusSignature('a(sx)'),
              DBusArgumentDirection.out,
            ),
          ],
        ),
        DBusIntrospectMethod(
          'TrashSize',
          args: [
            DBusIntrospectArgument(
              DBusSignature('x'),
              DBusArgumentDirection.out,
            ),
          ],
        ),
        DBusIntrospectMethod('EmptyTrash'),
        DBusIntrospectMethod(
          'OpenFolder',
          args: [
            DBusIntrospectArgument(
              DBusSignature('s'),
              DBusArgumentDirection.in_,
            ),
          ],
        ),
        DBusIntrospectMethod(
          'Format',
          args: [
            for (final _ in [1, 2, 3])
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.in_,
              ),
            DBusIntrospectArgument(
              DBusSignature('s'),
              DBusArgumentDirection.out,
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
    if (call.interface != storageInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    final name = call.name, signature = call.signature.value;
    switch ((name, signature)) {
      case ('List', ''):
        return DBusMethodSuccessResponse([
          DBusArray(DBusSignature('a{sv}'), [
            for (final disk in storage.disks.value) diskUsageToDBus(disk),
          ]),
        ]);
      case ('Refresh', ''):
        await storage.refresh();
        return DBusMethodSuccessResponse();
      case ('LargestFolders', 's'):
        if (!await _allowed(call)) return _denied;
        final folders = await storage.largestFolders(call.values[0].asString());
        return DBusMethodSuccessResponse([
          DBusArray(DBusSignature('(sx)'), [
            for (final folder in folders)
              DBusStruct([DBusString(folder.path), DBusInt64(folder.size)]),
          ]),
        ]);
      case ('TrashSize', ''):
        return DBusMethodSuccessResponse([
          DBusInt64(await storage.trashSize()),
        ]);
      case ('EmptyTrash', ''):
        if (!await _allowed(call)) return _denied;
        await storage.emptyTrash();
        return DBusMethodSuccessResponse();
      case ('OpenFolder', 's'):
        if (!await _allowed(call)) return _denied;
        await storage.openFolder(call.values[0].asString());
        return DBusMethodSuccessResponse();
      case ('Format', 'sss'):
        if (!await _allowed(call)) return _denied;
        final type = PsitoDiskFormat.values
            .asNameMap()[call.values[1].asString()];
        if (type == null) {
          return DBusMethodErrorResponse.invalidArgs('unknown format');
        }
        final result = await storage.format(
          call.values[0].asString(),
          type,
          call.values[2].asString(),
        );
        return DBusMethodSuccessResponse([DBusString(result.name)]);
    }
    return DBusMethodErrorResponse.unknownMethod();
  }

  static final _denied = DBusMethodErrorResponse.accessDenied(
    'the app lacks the settings permission',
  );
}

Future<void> publishStorage(DBusClient bus, StorageBusObject object) async {
  await bus.registerObject(object);
  await bus.requestName(
    storageBusName,
    flags: {
      DBusRequestNameFlag.replaceExisting,
      DBusRequestNameFlag.doNotQueue,
    },
  );
}
