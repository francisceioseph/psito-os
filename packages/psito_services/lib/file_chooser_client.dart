// packages/psito_services/lib/file_chooser_client.dart
//
// O seletor de arquivos do portal (org.freedesktop.portal.FileChooser). O Psito
// não desenha um: quem abre a janela é o xdg-desktop-portal-gtk.
import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

class FileChooserClient {
  static const _name = 'org.freedesktop.portal.Desktop';
  static final _path = DBusObjectPath('/org/freedesktop/portal/desktop');
  static const _interface = 'org.freedesktop.portal.FileChooser';
  static const _request = 'org.freedesktop.portal.Request';

  final DBusClient _bus;
  int _nextToken = 0;

  FileChooserClient(this._bus);

  /// O caminho escolhido, ou null se a pessoa cancelou ou o portal não existe.
  Future<String?> pickFile({
    required String title,
    List<String> patterns = const [],
  }) async {
    StreamSubscription<DBusSignal>? subscription;
    try {
      // Só depois do ping o cliente tem o nome único, de que o caminho depende
      await _bus.ping(_name);
      final token = 'psito${_nextToken++}';
      final sender = _bus.uniqueName.substring(1).replaceAll('.', '_');
      final handle = DBusObjectPath(
        '/org/freedesktop/portal/desktop/request/$sender/$token',
      );
      final answer = Completer<DBusSignal>();
      // A assinatura vem antes da chamada, ou a resposta poderia passar antes
      subscription =
          DBusRemoteObjectSignalStream(
            object: DBusRemoteObject(_bus, name: _name, path: handle),
            interface: _request,
            name: 'Response',
          ).listen((signal) {
            if (!answer.isCompleted) answer.complete(signal);
          });
      await DBusRemoteObject(_bus, name: _name, path: _path).callMethod(
        _interface,
        'OpenFile',
        [
          const DBusString(''),
          DBusString(title),
          DBusDict.stringVariant({
            'handle_token': DBusString(token),
            if (patterns.isNotEmpty)
              'filters': DBusArray(DBusSignature('(sa(us))'), [
                _filter(title, patterns),
              ]),
          }),
        ],
        replySignature: DBusSignature('o'),
      );
      final response = await answer.future;
      return pickedPath(
        response.values[0].asUint32(),
        response.values[1].asStringVariantDict(),
      );
    } catch (e) {
      debugPrint('🦜 Erro no seletor de arquivos: $e');
      return null;
    } finally {
      await subscription?.cancel();
    }
  }

  static DBusStruct _filter(String name, List<String> patterns) => DBusStruct([
    DBusString(name),
    DBusArray(DBusSignature('(us)'), [
      for (final pattern in patterns)
        DBusStruct([const DBusUint32(0), DBusString(pattern)]),
    ]),
  ]);
}

/// O caminho numa resposta do portal: o código 0 é sucesso, e os outros são
/// cancelado ou erro.
@visibleForTesting
String? pickedPath(int code, Map<String, DBusValue> results) {
  if (code != 0) return null;
  final uri = results['uris']?.asStringArray().firstOrNull;
  return uri == null ? null : Uri.parse(uri).toFilePath();
}
