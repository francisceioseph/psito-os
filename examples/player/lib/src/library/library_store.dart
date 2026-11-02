// examples/player/lib/src/library/library_store.dart
//
// O banco visto de quem está na tela: tudo assíncrono, para uma consulta grande
// não segurar um quadro. O IsolateStore roda num isolate próprio, e os testes
// usam o DirectStore, com o banco em memória.
import 'dart:async';
import 'dart:isolate';

import 'library_db.dart';

typedef LibraryQuery<T> = T Function(LibraryDb db);

abstract interface class LibraryStore {
  /// Roda [query] no banco. Ela atravessa para o outro isolate: não pode levar
  /// nada além de dados, e por isso as consultas moram em funções curtas.
  Future<T> run<T>(LibraryQuery<T> query);
  Future<void> close();
}

class DirectStore implements LibraryStore {
  final LibraryDb db;

  DirectStore(this.db);

  @override
  Future<T> run<T>(LibraryQuery<T> query) async => query(db);

  /// Quem abriu o banco é quem fecha.
  @override
  Future<void> close() async {}
}

class _Request<T> {
  final LibraryQuery<T> query;
  final SendPort reply;

  _Request(this.query, this.reply);

  void answer(LibraryDb db) {
    try {
      reply.send((query(db), null));
    } catch (e, stack) {
      reply.send((null, '$e\n$stack'));
    }
  }
}

class IsolateStore implements LibraryStore {
  final SendPort _requests;

  IsolateStore._(this._requests);

  /// Lança se o banco não abre.
  static Future<IsolateStore> open(String path) async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(
      _main,
      (path, ready.sendPort),
      debugName: 'psito-player-db',
      errorsAreFatal: false,
    );
    final (requests, error) = await ready.first as (SendPort?, String?);
    if (requests == null) {
      isolate.kill();
      throw StateError('$error');
    }
    return IsolateStore._(requests);
  }

  static void _main((String, SendPort) args) {
    final (path, ready) = args;
    final LibraryDb db;
    try {
      db = LibraryDb.open(path);
    } catch (e) {
      ready.send((null, '$e'));
      return;
    }
    final port = ReceivePort();
    ready.send((port.sendPort, null));
    port.listen((message) {
      if (message is _Request) {
        message.answer(db);
      } else {
        db.close();
        port.close();
      }
    });
  }

  @override
  Future<T> run<T>(LibraryQuery<T> query) async {
    final reply = ReceivePort();
    _requests.send(_Request<T>(query, reply.sendPort));
    final (value, error) = await reply.first as (Object?, String?);
    if (error != null) throw StateError(error);
    return value as T;
  }

  @override
  Future<void> close() async => _requests.send(null);
}
