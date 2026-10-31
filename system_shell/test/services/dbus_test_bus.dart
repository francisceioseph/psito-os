// Barramento D-Bus privado para testar os serviços reais sem o systemd: um
// cliente faz o papel do serviço (publica nome e objetos) e outro o do shell.
import 'dart:io';

import 'package:dbus/dbus.dart';

class DBusTestBus {
  final Directory _dir;
  final DBusServer _server;

  /// Publica os objetos falsos (hostname1, NetworkManager…).
  final DBusClient service;

  /// O que o serviço real do shell recebe.
  final DBusClient shell;

  DBusTestBus._(this._dir, this._server, this.service, this.shell);

  static Future<DBusTestBus> start() async {
    final dir = await Directory.systemTemp.createTemp('psito_dbus_');
    final server = DBusServer();
    final address = await server.listenAddress(DBusAddress.unix(dir: dir));
    return DBusTestBus._(dir, server, DBusClient(address), DBusClient(address));
  }

  /// Registra [object] e assume [name], como faria o daemon de verdade.
  Future<void> publish(String name, DBusObject object) async {
    await service.registerObject(object);
    await service.requestName(name);
  }

  Future<void> close() async {
    await shell.close();
    await service.close();
    await _server.close();
    await _dir.delete(recursive: true);
  }
}

/// Objeto com propriedades fixas numa interface, que dá para mudar e
/// anunciar com PropertiesChanged.
class FakePropertiesObject extends DBusObject {
  final String interface;
  final Map<String, DBusValue> properties;

  FakePropertiesObject(super.path, this.interface, this.properties);

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async =>
      DBusGetAllPropertiesResponse(
        interface == this.interface ? properties : {},
      );

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final value = interface == this.interface ? properties[name] : null;
    return value == null
        ? DBusMethodErrorResponse.unknownProperty()
        : DBusGetPropertyResponse(value);
  }

  Future<void> change(Map<String, DBusValue> changed) async {
    properties.addAll(changed);
    await emitPropertiesChanged(interface, changedProperties: changed);
  }
}
