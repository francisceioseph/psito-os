// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'greeter_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class GreeterLocalizationsPt extends GreeterLocalizations {
  GreeterLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get passwordHint => 'Senha';

  @override
  String get signIn => 'Entrar';

  @override
  String get wrongPassword => 'Senha incorreta.';

  @override
  String signInFailed(Object detail) {
    return 'Não foi possível entrar. $detail';
  }

  @override
  String get startFailed => 'Não foi possível abrir a sessão.';

  @override
  String get noUsers => 'Nenhuma conta de usuário.';

  @override
  String get otherUser => 'Escolher outro usuário';

  @override
  String get suspend => 'Suspender';

  @override
  String get reboot => 'Reiniciar';

  @override
  String get powerOff => 'Desligar';
}
