// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'lock_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LockLocalizationsEn extends LockLocalizations {
  LockLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get passwordHint => 'Password';

  @override
  String get unlock => 'Unlock';

  @override
  String get wrongPassword => 'Wrong password.';

  @override
  String waitSeconds(Object seconds) {
    return 'Wrong password. Try again in $seconds s.';
  }

  @override
  String get suspend => 'Suspend';

  @override
  String get powerOff => 'Shut down';
}
