// shell/lib/volumes_bus.dart
//
// O shell dá os discos externos aos apps em org.psito.Volumes:
// - List() → aa{sv}, e o sinal Changed() quando a lista muda;
// - Mount(s id) → s: onde montou, ou vazio;
// - Unlock(s id) → s: onde montou, ou vazio. O shell pede a senha, e o app não
//   a vê nem pode tentar outras;
// - Unmount(s id), Eject(s id) → s: o PsitoDiskResult;
// - UsersOf(s id) → as: o nome de quem está segurando o disco.
// Quem passa é o filtro do sandbox (`files:removable`). O cliente é o
// VolumesClient do psito_services.
import 'package:dbus/dbus.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:psito_services/disks_service.dart';
import 'package:psito_services/volumes_client.dart';

class VolumesBusObject extends DBusObject {
  final DisksService disks;

  VolumesBusObject(this.disks) : super(volumesPath) {
    disks.volumes.addListener(_changed);
  }

  void _changed() => emitSignal(volumesInterface, 'Changed');

  void detach() => disks.volumes.removeListener(_changed);

  @override
  List<DBusIntrospectInterface> introspect() => [
    DBusIntrospectInterface(
      volumesInterface,
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
      ],
      signals: [DBusIntrospectSignal('Changed')],
    ),
  ];

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    final call = methodCall;
    if (call.interface != volumesInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    DBusMethodResponse result(PsitoDiskResult r) =>
        DBusMethodSuccessResponse([DBusString(r.name)]);
    switch ((call.name, call.signature.value)) {
      case ('List', ''):
        return DBusMethodSuccessResponse([
          DBusArray(DBusSignature('a{sv}'), [
            for (final volume in disks.volumes.value) volumeToDBus(volume),
          ]),
        ]);
      case ('Mount', 's'):
        final where = await disks.mount(call.values[0].asString());
        return DBusMethodSuccessResponse([DBusString(where ?? '')]);
      case ('Unmount', 's'):
        return result(await disks.unmount(call.values[0].asString()));
      case ('Eject', 's'):
        return result(await disks.eject(call.values[0].asString()));
      case ('UsersOf', 's'):
        return DBusMethodSuccessResponse([
          DBusArray.string(await disks.usersOf(call.values[0].asString())),
        ]);
      case ('Unlock', 's'):
        final where = await disks.unlock(call.values[0].asString());
        return DBusMethodSuccessResponse([DBusString(where ?? '')]);
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

Future<void> publishVolumes(DBusClient bus, VolumesBusObject object) async {
  await bus.registerObject(object);
  await bus.requestName(
    volumesBusName,
    flags: {
      DBusRequestNameFlag.replaceExisting,
      DBusRequestNameFlag.doNotQueue,
    },
  );
}
