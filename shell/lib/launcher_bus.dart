// shell/lib/launcher_bus.dart
//
// O shell abre arquivos para os apps em org.psito.Launcher:
// - Open(as paths) e OpenWith(s app, as paths): cada arquivo no app padrão
//   do tipo dele, ou no app dado;
// - AppsFor(s mime) → a(sssb): o id, o nome, o ícone e se é o padrão (sem
//   tipo, todos os apps que recebem arquivos);
// - SetDefault(s mime, s app): o padrão do usuário (mimeapps.list);
// - NextOpen() → as: um app de instância única (o Files) espera aqui pelos
//   arquivos que o shell entregaria a ele, em vez de abrir outro processo.
// O cliente é o LauncherClient do psito_services.
import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:psito_services/launcher_client.dart';

import 'opener.dart';

/// O id do app (o `.desktop`) de quem mandou a mensagem.
typedef CallerResolver = Future<String?> Function(String sender);

class LauncherBusObject extends DBusObject {
  final Opener opener;
  final CallerResolver callerOf;

  /// Abre um plano (o `DesktopEntry.launch` com os arquivos).
  final Future<void> Function(OpenPlan plan) launch;

  /// Grava o padrão do usuário.
  final Future<void> Function(String mime, String appId) setDefault;

  /// Se quem mandou a mensagem ainda está no barramento. Um app que caiu
  /// esperando no `NextOpen` não recebe mais nada: os arquivos iam se perder.
  final Future<bool> Function(String sender) isConnected;

  /// Quanto um `NextOpen` espera antes de devolver vazio. Menos que o
  /// tempo-limite das chamadas do barramento (25 s), para a resposta nunca
  /// chegar a uma chamada que já desistiu.
  final Duration waitLimit;

  /// Os `NextOpen` esperando, por app, com quem chamou.
  final _waiters = <String, List<(String, Completer<List<String>>)>>{};

  LauncherBusObject({
    required this.opener,
    required this.callerOf,
    required this.launch,
    required this.setDefault,
    this.isConnected = _always,
    this.waitLimit = const Duration(seconds: 20),
  }) : super(launcherPath);

  static Future<bool> _always(String sender) async => true;

  /// Se o app tem uma instância esperando arquivos.
  bool waiting(String appId) => _waiters[appId]?.isNotEmpty ?? false;

  /// Abre os arquivos, já com os caminhos de verdade. Um app com uma
  /// instância esperando recebe lá; os outros abrem um processo.
  Future<void> openPaths(List<String> paths, {String? withApp}) async {
    for (final plan in opener.plan(paths, withApp: withApp)) {
      // A instância que espera vê os arquivos (o Files tem files:home); os
      // que precisariam de --file vão para um processo novo
      final waiter = plan.files.isEmpty ? await _liveWaiter(plan.app.id) : null;
      if (waiter != null) {
        waiter.complete(plan.paths);
      } else {
        await launch(plan);
      }
    }
  }

  /// A primeira espera de [appId] de quem ainda está no barramento; as de
  /// quem saiu são descartadas.
  Future<Completer<List<String>>?> _liveWaiter(String appId) async {
    final waiters = _waiters[appId];
    while (waiters != null && waiters.isNotEmpty) {
      final (sender, completer) = waiters.removeAt(0);
      if (await isConnected(sender)) return completer;
      completer.complete(const []);
    }
    return null;
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != launcherInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    final sender = methodCall.sender;
    final caller = sender == null ? null : await callerOf(sender);
    final values = methodCall.values;
    try {
      switch (methodCall.name) {
        case 'Open' when methodCall.signature == DBusSignature('as'):
          final paths = _fromCaller(caller, values[0].asStringArray());
          if (paths == null) return _denied();
          await openPaths(paths);
          return DBusMethodSuccessResponse();
        case 'OpenWith' when methodCall.signature == DBusSignature('sas'):
          final paths = _fromCaller(caller, values[1].asStringArray());
          if (paths == null) return _denied();
          await openPaths(paths, withApp: values[0].asString());
          return DBusMethodSuccessResponse();
        case 'AppsFor' when methodCall.signature == DBusSignature('s'):
          final apps = opener.appsFor(values[0].asString());
          return DBusMethodSuccessResponse([
            DBusArray(DBusSignature('(sssb)'), [
              for (final (i, app) in apps.indexed)
                DBusStruct([
                  DBusString(app.id),
                  DBusString(app.name),
                  DBusString(app.icon ?? ''),
                  DBusBoolean(i == 0 && values[0].asString().isNotEmpty),
                ]),
            ]),
          ]);
        case 'SetDefault' when methodCall.signature == DBusSignature('ss'):
          if (!_maySetDefault(caller)) return _denied();
          final appId = values[1].asString();
          if (opener.entry(appId) == null) {
            return DBusMethodErrorResponse.invalidArgs('app desconhecido');
          }
          await setDefault(values[0].asString(), appId);
          return DBusMethodSuccessResponse();
        case 'NextOpen' when methodCall.signature == DBusSignature(''):
          // Fora de um app ninguém entrega nada
          final paths = caller == null || sender == null
              ? const <String>[]
              : await _next(caller, sender);
          return DBusMethodSuccessResponse([DBusArray.string(paths)]);
        default:
          return DBusMethodErrorResponse.unknownMethod();
      }
    } on NoAppException catch (e) {
      return DBusMethodErrorResponse(launcherNoAppError, [DBusString('$e')]);
    } on Exception catch (e) {
      debugPrint('🦜 launcher: ${methodCall.name} falhou ($e)');
      return DBusMethodErrorResponse.failed('$e');
    }
  }

  List<String>? _fromCaller(String? caller, Iterable<String> paths) {
    final out = <String>[];
    for (final path in paths) {
      final real = opener.fromCaller(caller, path);
      if (real == null) return null;
      out.add(real);
    }
    return out;
  }

  /// A segunda trava do `SetDefault`, além do filtro do sandbox: um app do
  /// Psito só com `files:home`.
  bool _maySetDefault(String? caller) {
    final app = caller == null ? null : opener.entry(caller);
    if (app == null || app.psitoApp == null) return true;
    return app.permissions.contains('files:home');
  }

  DBusMethodErrorResponse _denied() => DBusMethodErrorResponse.accessDenied(
    'o app não vê esse caminho ou não tem a permissão',
  );

  Future<List<String>> _next(String appId, String sender) {
    final completer = Completer<List<String>>();
    final waiter = (sender, completer);
    (_waiters[appId] ??= []).add(waiter);
    return completer.future.timeout(
      waitLimit,
      onTimeout: () {
        _waiters[appId]?.remove(waiter);
        return const [];
      },
    );
  }

  @override
  List<DBusIntrospectInterface> introspect() {
    DBusIntrospectArgument arg(String sig, String name, {bool out = false}) =>
        DBusIntrospectArgument(
          DBusSignature(sig),
          out ? DBusArgumentDirection.out : DBusArgumentDirection.in_,
          name: name,
        );
    return [
      DBusIntrospectInterface(
        launcherInterface,
        methods: [
          DBusIntrospectMethod('Open', args: [arg('as', 'paths')]),
          DBusIntrospectMethod(
            'OpenWith',
            args: [arg('s', 'app'), arg('as', 'paths')],
          ),
          DBusIntrospectMethod(
            'AppsFor',
            args: [arg('s', 'mime'), arg('a(sssb)', 'apps', out: true)],
          ),
          DBusIntrospectMethod(
            'SetDefault',
            args: [arg('s', 'mime'), arg('s', 'app')],
          ),
          DBusIntrospectMethod(
            'NextOpen',
            args: [arg('as', 'paths', out: true)],
          ),
        ],
      ),
    ];
  }
}

/// Registra o launcher numa conexão só dele (o filtro do sandbox decide por
/// conexão, como no org.psito.Settings).
Future<void> publishLauncher(DBusClient bus, LauncherBusObject object) async {
  await bus.registerObject(object);
  await bus.requestName(
    launcherBusName,
    flags: {
      DBusRequestNameFlag.replaceExisting,
      DBusRequestNameFlag.doNotQueue,
    },
  );
}
