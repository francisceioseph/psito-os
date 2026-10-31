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

/// Objeto com propriedades em uma ou mais interfaces, que dá para mudar e
/// anunciar com PropertiesChanged. Aparece no GetManagedObjects quando fica
/// abaixo de um [DBusObject] com `isObjectManager`.
class FakeDBusObject extends DBusObject {
  final Map<String, Map<String, DBusValue>> interfaces;

  /// Métodos chamados neste objeto (ex.: Enable do NetworkManager).
  final List<DBusMethodCall> calls = [];

  /// Resposta por nome de método; sem entrada, responde vazio.
  final Map<String, List<DBusValue>> replies = {};

  FakeDBusObject(super.path, this.interfaces);

  /// Uma interface só.
  FakeDBusObject.single(
    DBusObjectPath path,
    String interface,
    Map<String, DBusValue> properties,
  ) : this(path, {interface: properties});

  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => interfaces;

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async =>
      DBusGetAllPropertiesResponse(interfaces[interface] ?? {});

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final value = interfaces[interface]?[name];
    return value == null
        ? DBusMethodErrorResponse.unknownProperty()
        : DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    calls.add(call);
    return DBusMethodSuccessResponse(replies[call.name] ?? []);
  }

  Future<void> change(String interface, Map<String, DBusValue> changed) async {
    interfaces[interface]!.addAll(changed);
    await emitPropertiesChanged(interface, changedProperties: changed);
  }
}
