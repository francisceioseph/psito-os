// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'greeter_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class GreeterLocalizationsEn extends GreeterLocalizations {
  GreeterLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get passwordHint => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get wrongPassword => 'Wrong password.';

  @override
  String signInFailed(Object detail) {
    return 'Couldn\'t sign in. $detail';
  }

  @override
  String get startFailed => 'Couldn\'t start the session.';

  @override
  String get noUsers => 'No user accounts.';

  @override
  String get otherUser => 'Choose another user';

  @override
  String get suspend => 'Suspend';

  @override
  String get reboot => 'Restart';

  @override
  String get powerOff => 'Shut down';
}
