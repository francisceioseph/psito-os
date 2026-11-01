// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'lock_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class LockLocalizationsPt extends LockLocalizations {
  LockLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get passwordHint => 'Senha';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get wrongPassword => 'Senha incorreta.';

  @override
  String waitSeconds(Object seconds) {
    return 'Senha incorreta. Tente de novo em $seconds s.';
  }

  @override
  String get suspend => 'Suspender';

  @override
  String get powerOff => 'Desligar';
}
