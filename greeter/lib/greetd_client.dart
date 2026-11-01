import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Uma pergunta e uma resposta ao greetd, em JSON.
typedef GreetdRequest = Future<Map<String, Object?>> Function(
  Map<String, Object?> message,
);

/// O socket do greetd (`$GREETD_SOCK`): cada mensagem é o tamanho em 32 bits,
/// na ordem da máquina, e o JSON.
class GreetdClient {
  final Socket _socket;
  final _pending = <Completer<Map<String, Object?>>>[];
  final _buffer = BytesBuilder();

  GreetdClient._(this._socket) {
    _socket.listen(_onData, onDone: _onDone, onError: (Object _) => _onDone());
  }

  static Future<GreetdClient> connect(String path) async => GreetdClient._(
    await Socket.connect(
      InternetAddress(path, type: InternetAddressType.unix),
      0,
    ),
  );

  Future<Map<String, Object?>> request(Map<String, Object?> message) {
    final body = utf8.encode(jsonEncode(message));
    final size = ByteData(4)..setUint32(0, body.length, Endian.host);
    _socket
      ..add(size.buffer.asUint8List())
      ..add(body);
    final reply = Completer<Map<String, Object?>>();
    _pending.add(reply);
    return reply.future;
  }

  void _onData(Uint8List data) {
    _buffer.add(data);
    var bytes = _buffer.toBytes();
    while (bytes.length >= 4) {
      final size = ByteData.sublistView(bytes, 0, 4).getUint32(0, Endian.host);
      if (bytes.length < 4 + size) break;
      final json = jsonDecode(utf8.decode(bytes.sublist(4, 4 + size)));
      bytes = bytes.sublist(4 + size);
      if (_pending.isNotEmpty) {
        _pending.removeAt(0).complete(json as Map<String, Object?>);
      }
    }
    _buffer
      ..clear()
      ..add(bytes);
  }

  void _onDone() {
    debugPrint('🦜 greeter: o greetd fechou o socket');
    for (final reply in _pending) {
      reply.complete({
        'type': 'error',
        'error_type': 'error',
        'description': '',
      });
    }
    _pending.clear();
  }

  Future<void> close() => _socket.close();
}

/// O que o greetd devolve para quem está na tela.
enum LoginState { idle, asking, checking, wrong, failed, started }

/// Uma tentativa de entrar: quem, o que o PAM pergunta, e a sessão no fim.
class LoginFlow extends ChangeNotifier {
  final GreetdRequest _request;

  /// O comando e o ambiente da sessão, que o greetd abre quando o greeter sai.
  final List<String> command;
  final List<String> environment;

  LoginState state = LoginState.idle;
  String? user;
  String? prompt;
  bool secret = true;

  /// O que o PAM avisou (a conta expirada, por exemplo).
  String? detail;

  bool _wrongAgain = false;

  LoginFlow(this._request, {required this.command, required this.environment});

  Future<void> select(String name) async {
    if (user != null) await _request({'type': 'cancel_session'});
    user = name;
    detail = null;
    await _create();
  }

  /// Volta para a lista de contas.
  Future<void> cancel() async {
    if (user == null) return;
    user = null;
    detail = null;
    state = LoginState.idle;
    notifyListeners();
    await _request({'type': 'cancel_session'});
  }

  Future<void> _create() async {
    state = LoginState.checking;
    notifyListeners();
    await _handle(await _request({'type': 'create_session', 'username': user}));
  }

  Future<void> answer(String response) async {
    if (state != LoginState.asking && state != LoginState.wrong) return;
    state = LoginState.checking;
    notifyListeners();
    await _handle(
      await _request({
        'type': 'post_auth_message_response',
        'response': response,
      }),
    );
  }

  Future<void> _handle(Map<String, Object?> reply) async {
    switch (reply['type']) {
      case 'auth_message':
        final kind = reply['auth_message_type'];
        final text = (reply['auth_message'] as String? ?? '').trim();
        if (kind == 'secret' || kind == 'visible') {
          // Depois de uma senha errada, continua dizendo isso até a próxima
          state = state == LoginState.checking && _wrongAgain
              ? LoginState.wrong
              : LoginState.asking;
          _wrongAgain = false;
          prompt = text;
          secret = kind == 'secret';
          notifyListeners();
          return;
        }
        // Um aviso: mostra, e o greetd segue sem resposta
        detail = text;
        await _handle(await _request({'type': 'post_auth_message_response'}));
      case 'success':
        await _start();
      case 'error':
        await _request({'type': 'cancel_session'});
        if (reply['error_type'] == 'auth_error') {
          _wrongAgain = true;
          await _create();
          return;
        }
        debugPrint('🦜 greeter: ${reply['description']}');
        detail = reply['description'] as String?;
        state = LoginState.failed;
        notifyListeners();
    }
  }

  Future<void> _start() async {
    final reply = await _request({
      'type': 'start_session',
      'cmd': command,
      'env': environment,
    });
    if (reply['type'] == 'success') {
      state = LoginState.started;
    } else {
      debugPrint('🦜 greeter: ${reply['description']}');
      await _request({'type': 'cancel_session'});
      state = LoginState.failed;
    }
    notifyListeners();
  }
}

/// Uma conta que pode entrar.
class LoginUser {
  final String login;
  final String name;
  const LoginUser(this.login, this.name);
}

/// As contas de pessoas no `/etc/passwd`, sem as de sistema.
List<LoginUser> loginUsers(String passwd) {
  final users = <LoginUser>[];
  for (final line in const LineSplitter().convert(passwd)) {
    final f = line.split(':');
    if (f.length < 7) continue;
    final uid = int.tryParse(f[2]) ?? 0;
    if (uid < 1000 || uid >= 60000) continue;
    if (f[6].endsWith('nologin') || f[6].endsWith('false')) continue;
    final name = f[4].split(',').first.trim();
    users.add(LoginUser(f[0], name.isEmpty ? f[0] : name));
  }
  return users;
}
