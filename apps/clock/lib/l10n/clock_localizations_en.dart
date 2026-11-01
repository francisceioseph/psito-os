// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'clock_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class ClockLocalizationsEn extends ClockLocalizations {
  ClockLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Clock';

  @override
  String get timerDone => 'Timer finished';

  @override
  String get timerDoneBody => '10 seconds have passed.';

  @override
  String get timerIdle => '10 s timer';

  @override
  String timerRemaining(Object seconds) {
    return '$seconds s left';
  }

  @override
  String get timerStart => 'Start timer';
}
