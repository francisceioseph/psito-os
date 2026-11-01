// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'clock_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class ClockLocalizationsPt extends ClockLocalizations {
  ClockLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Relógio';

  @override
  String get timerDone => 'Timer concluído';

  @override
  String get timerDoneBody => '10 segundos se passaram.';

  @override
  String get timerIdle => 'Timer de 10 s';

  @override
  String timerRemaining(Object seconds) {
    return 'Faltam $seconds s';
  }

  @override
  String get timerStart => 'Iniciar timer';
}
