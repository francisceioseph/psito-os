// packages/psito_services/lib/launcher_client.dart
//
// Abrir arquivos pelo shell (org.psito.Launcher na sessão): ele sabe o app
// padrão de cada tipo e abre o app no escopo e no sandbox certos, com acesso
// só ao arquivo. O servidor é o shell/lib/launcher_bus.dart.
import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:psito_sdk/psito_sdk.dart';

const launcherBusName = 'org.psito.Launcher';
const launcherInterface = 'org.psito.Launcher';
final launcherPath = DBusObjectPath('/org/psito/Launcher');

/// O erro de quando nenhum app abre o arquivo.
const launcherNoAppError = 'org.psito.Launcher.Error.NoApp';

class LauncherClient {
  final DBusClient _bus;
  late final DBusRemoteObject _shell = DBusRemoteObject(
    _bus,
    name: launcherBusName,
    path: launcherPath,
  );

  LauncherClient(this._bus);

  Future<void> open(List<String> paths, {String? withApp}) async {
    try {
      if (withApp == null) {
        await _shell.callMethod(launcherInterface, 'Open', [
          DBusArray.string(paths),
        ], replySignature: DBusSignature(''));
      } else {
        await _shell.callMethod(launcherInterface, 'OpenWith', [
          DBusString(withApp),
          DBusArray.string(paths),
        ], replySignature: DBusSignature(''));
      }
    } on DBusMethodResponseException catch (e) {
      throw e.errorName == launcherNoAppError
          ? PsitoOpenException(
              PsitoOpenError.noApp,
              e.response.values.firstOrNull?.asString() ?? '',
            )
          : PsitoOpenException(PsitoOpenError.failed, '$e');
    } on Exception catch (e) {
      throw PsitoOpenException(PsitoOpenError.failed, '$e');
    }
  }

  Future<List<PsitoAppChoice>> appsFor(String mimeType) async {
    try {
      final reply = await _shell.callMethod(launcherInterface, 'AppsFor', [
        DBusString(mimeType),
      ], replySignature: DBusSignature('a(sssb)'));
      return [
        for (final item in reply.values.single.asArray())
          if (item.asStruct() case [
            final id,
            final name,
            final icon,
            final isDefault,
          ])
            PsitoAppChoice(
              id: id.asString(),
              name: name.asString(),
              icon: icon.asString().isEmpty ? null : icon.asString(),
              isDefault: isDefault.asBoolean(),
            ),
      ];
    } on Exception catch (e) {
      debugPrint('🦜 launcher: sem os apps de $mimeType ($e)');
      return const [];
    }
  }

  Future<void> setDefault(String mimeType, String appId) async {
    await _shell.callMethod(launcherInterface, 'SetDefault', [
      DBusString(mimeType),
      DBusString(appId),
    ], replySignature: DBusSignature(''));
  }

  /// Diz ao shell o que este app começou a arrastar: é o que deixa um app no
  /// sandbox receber esses arquivos.
  Future<void> offerDrag(List<String> paths) async {
    try {
      await _shell.callMethod(launcherInterface, 'OfferDrag', [
        DBusArray.string(paths),
      ], replySignature: DBusSignature(''));
    } on Exception catch (e) {
      debugPrint('🦜 launcher: sem oferecer o arrastar ($e)');
    }
  }

  /// Se o shell abre neste app o que estão soltando na janela dele.
  Future<bool> acceptsDrop(List<String> paths) =>
      _dropCall('AcceptsDrop', paths);

  /// Abre o que foi solto na janela deste app, numa janela nova.
  Future<bool> openDropped(List<String> paths) =>
      _dropCall('OpenDropped', paths);

  Future<bool> _dropCall(String method, List<String> paths) async {
    try {
      final reply = await _shell.callMethod(launcherInterface, method, [
        DBusArray.string(paths),
      ], replySignature: DBusSignature('b'));
      return reply.values.single.asBoolean();
    } on Exception catch (e) {
      debugPrint('🦜 launcher: $method falhou ($e)');
      return false;
    }
  }

  /// Os arquivos que o shell manda para este app, um pedido por vez. O
  /// shell segura cada chamada até ter algo (ou devolve vazio depois de um
  /// tempo, e a chamada se repete). Só para apps de instância única.
  Stream<List<String>> openRequests() {
    var cancelled = false;
    late final StreamController<List<String>> controller;
    Future<void> loop() async {
      var failures = 0;
      while (!cancelled) {
        try {
          final reply = await _shell.callMethod(
            launcherInterface,
            'NextOpen',
            const [],
            replySignature: DBusSignature('as'),
          );
          failures = 0;
          final paths = reply.values.single.asStringArray().toList();
          if (paths.isNotEmpty && !cancelled) controller.add(paths);
        } on Exception catch (e) {
          if (cancelled) break;
          // O shell reiniciando: tenta de novo, cada vez mais devagar
          if (failures++ == 0) debugPrint('🦜 launcher: sem o shell ($e)');
          await Future<void>.delayed(Duration(seconds: failures.clamp(1, 30)));
        }
      }
    }

    controller = StreamController(
      onListen: () => unawaited(loop()),
      onCancel: () => cancelled = true,
    );
    return controller.stream;
  }
}
