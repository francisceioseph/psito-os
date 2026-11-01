import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

const polkitBusName = 'org.freedesktop.PolicyKit1';
const polkitAgentPath = '/org/psito/PolkitAgent';
const polkitAgentInterface = 'org.freedesktop.PolicyKit1.AuthenticationAgent';
const polkitHelper = '/usr/lib/polkit-1/polkit-agent-helper-1';

/// Com várias contas que podem autorizar, vale a de quem está na sessão, e
/// senão a primeira. Devolve o login, ou null se nenhuma existe no passwd.
String? pickPolkitUser(List<int> uids, String passwd, String me) {
  final names = <int, String>{};
  for (final line in const LineSplitter().convert(passwd)) {
    final fields = line.split(':');
    final uid = fields.length > 2 ? int.tryParse(fields[2]) : null;
    if (uid != null) names[uid] = fields[0];
  }
  final known = [for (final uid in uids) ?names[uid]];
  if (known.contains(me)) return me;
  return known.firstOrNull;
}

/// Um pedido de senha do polkit. Quem confere é o `polkit-agent-helper-1`, que
/// é setuid e avisa o polkitd sozinho: o shell só leva a senha até ele. Cada
/// helper confere uma vez, e por isso uma senha errada sobe outro.
class PolkitRequest extends ChangeNotifier {
  final String message;
  final String user;
  final String cookie;
  final String helper;
  final _result = Completer<bool>();

  Process? _process;
  bool _answered = false;

  /// O que o PAM pediu, ou null enquanto ele confere.
  String? prompt;
  bool wrong = false;

  /// O que o PAM avisou (a conta bloqueada, por exemplo).
  String? info;

  PolkitRequest({
    required this.message,
    required this.user,
    required this.cookie,
    this.helper = polkitHelper,
  });

  /// Termina quando o pedido acaba: true com a senha aceita.
  Future<bool> get result => _result.future;

  Future<void> start() async {
    if (_result.isCompleted) return;
    _answered = false;
    final Process process;
    try {
      process = await Process.start(helper, [user]);
    } on ProcessException catch (e) {
      debugPrint('🦜 polkit: sem o helper ($e)');
      _finish(false);
      return;
    }
    _process = process;
    unawaited(process.stderr.drain<void>());
    process.stdin.writeln(cookie);
    var ended = false;
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line == 'SUCCESS' || line == 'FAILURE') ended = true;
            _onLine(line);
          },
          onDone: () {
            // O helper caiu sem dizer como foi
            if (!ended) _finish(false);
          },
        );
  }

  void _onLine(String line) {
    if (_result.isCompleted) return;
    final space = line.indexOf(' ');
    final kind = space < 0 ? line : line.substring(0, space);
    final text = space < 0 ? '' : line.substring(space + 1).trim();
    switch (kind) {
      case 'PAM_PROMPT_ECHO_OFF' || 'PAM_PROMPT_ECHO_ON':
        prompt = text;
        notifyListeners();
      case 'PAM_ERROR_MSG' || 'PAM_TEXT_INFO':
        info = text;
        notifyListeners();
      case 'SUCCESS':
        _finish(true);
      case 'FAILURE':
        // Sem ter pedido nada, tentar de novo daria no mesmo, para sempre
        if (!_answered) {
          _finish(false);
          return;
        }
        wrong = true;
        notifyListeners();
        unawaited(start());
    }
  }

  void answer(String password) {
    final process = _process;
    if (process == null || prompt == null || password.isEmpty) return;
    prompt = null;
    wrong = false;
    info = null;
    _answered = true;
    process.stdin.writeln(password);
    notifyListeners();
  }

  void cancel() => _finish(false);

  void _finish(bool ok) {
    if (_result.isCompleted) return;
    _process?.kill();
    _result.complete(ok);
  }
}

/// O agente de autenticação da sessão: o polkitd chama aqui quando uma ação
/// precisa de senha. Um pedido aparece por vez, em [current].
class PolkitAgent extends DBusObject {
  /// Lido a cada pedido: uma conta nova não pede para reiniciar o shell.
  final String Function() passwd;
  final String _me;
  final String helper;

  /// Só o polkitd pede: outro no barramento estaria pescando uma senha.
  Future<bool> Function(String sender) isAuthority = _nobody;

  final current = ValueNotifier<PolkitRequest?>(null);
  final _waiting = <PolkitRequest>[];

  PolkitAgent({
    this.passwd = _readPasswd,
    String? me,
    this.helper = polkitHelper,
  }) : _me = me ?? Platform.environment['USER'] ?? '',
       super(DBusObjectPath(polkitAgentPath));

  static Future<bool> _nobody(String sender) async => false;

  static String _readPasswd() {
    try {
      return File('/etc/passwd').readAsStringSync();
    } on FileSystemException {
      return '';
    }
  }

  /// A tela vai bloquear: ninguém responderia ao diálogo.
  void cancelAll() {
    for (final request in [..._waiting]) {
      request.cancel();
    }
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != polkitAgentInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    final sender = methodCall.sender;
    if (sender == null || !await isAuthority(sender)) {
      return DBusMethodErrorResponse.accessDenied();
    }
    switch (methodCall.name) {
      case 'BeginAuthentication'
          when methodCall.signature.value == 'sssa{ss}sa(sa{sv})':
        return _begin(methodCall.values);
      case 'CancelAuthentication' when methodCall.signature.value == 's':
        final cookie = methodCall.values[0].asString();
        for (final request in [..._waiting]) {
          if (request.cookie == cookie) request.cancel();
        }
        return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }

  Future<DBusMethodResponse> _begin(List<DBusValue> values) async {
    final uids = <int>[];
    for (final identity in values[5].asArray()) {
      final fields = identity.asStruct();
      if (fields[0].asString() != 'unix-user') continue;
      final uid = fields[1].asStringVariantDict()['uid'];
      if (uid is DBusUint32) uids.add(uid.value);
      if (uid is DBusInt32) uids.add(uid.value);
    }
    final user = pickPolkitUser(uids, passwd(), _me);
    if (user == null) {
      return DBusMethodErrorResponse(
        'org.freedesktop.PolicyKit1.Error.Failed',
        [const DBusString('no known user can authorize this')],
      );
    }
    final request = PolkitRequest(
      message: values[1].asString(),
      user: user,
      cookie: values[4].asString(),
      helper: helper,
    );
    _waiting.add(request);
    if (_waiting.length == 1) _show();
    final ok = await request.result;
    final wasShown = identical(_waiting.first, request);
    _waiting.remove(request);
    request.dispose();
    if (wasShown) _show();
    if (ok) return DBusMethodSuccessResponse();
    return DBusMethodErrorResponse(
      'org.freedesktop.PolicyKit1.Error.Cancelled',
      [const DBusString('cancelled')],
    );
  }

  void _show() {
    final next = _waiting.firstOrNull;
    current.value = next;
    if (next != null) unawaited(next.start());
  }
}

/// Registra o agente para a sessão gráfica do usuário, numa conexão com o
/// barramento do sistema. O shell é uma unidade do systemd, então ele não está
/// na sessão: quem diz qual é o logind.
class PolkitRegistration {
  final DBusClient _bus;
  final DBusStruct _subject;
  String _locale;

  PolkitRegistration._(this._bus, this._subject, this._locale);

  DBusRemoteObject get _authority => DBusRemoteObject(
    _bus,
    name: polkitBusName,
    path: DBusObjectPath('/org/freedesktop/PolicyKit1/Authority'),
  );

  static Future<PolkitRegistration> publish(
    DBusClient bus,
    PolkitAgent agent,
    String locale,
  ) async {
    final display = await DBusRemoteObject(
      bus,
      name: 'org.freedesktop.login1',
      path: DBusObjectPath('/org/freedesktop/login1/user/self'),
    ).getProperty('org.freedesktop.login1.User', 'Display');
    final session = display.asStruct()[0];
    agent.isAuthority = (sender) async =>
        sender == await bus.getNameOwner(polkitBusName);
    await bus.registerObject(agent);
    final registration = PolkitRegistration._(
      bus,
      DBusStruct([
        const DBusString('unix-session'),
        DBusDict.stringVariant({'session-id': session}),
      ]),
      locale,
    );
    await registration._register();
    return registration;
  }

  Future<void> _register() => _authority.callMethod(
    'org.freedesktop.PolicyKit1.Authority',
    'RegisterAuthenticationAgent',
    [_subject, DBusString(_locale), const DBusString(polkitAgentPath)],
    replySignature: DBusSignature(''),
  );

  /// As mensagens vêm do polkitd, na língua dita aqui: mudar o idioma do Psito
  /// pede outro registro.
  Future<void> setLocale(String locale) async {
    if (locale == _locale) return;
    _locale = locale;
    await _authority.callMethod(
      'org.freedesktop.PolicyKit1.Authority',
      'UnregisterAuthenticationAgent',
      [_subject, const DBusString(polkitAgentPath)],
      replySignature: DBusSignature(''),
    );
    await _register();
  }
}

/// O idioma do Psito no formato do gettext, que é o que o polkitd entende.
String polkitLocale(String language, String systemLang) => switch (language) {
  'pt' => 'pt_BR.UTF-8',
  'en' => 'en_US.UTF-8',
  _ => systemLang.isEmpty ? 'C' : systemLang,
};
