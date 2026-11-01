// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'hello_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class HelloLocalizationsEn extends HelloLocalizations {
  HelloLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get connected => 'Connected';

  @override
  String noConnection(Object error) {
    return 'No connection: $error';
  }

  @override
  String get networkUnavailable => 'Network unavailable to the app';

  @override
  String get networkConnected => 'Network connected';

  @override
  String get networkNone => 'No network';

  @override
  String get networkLimited => 'Limited network';

  @override
  String get testing => 'Testing...';

  @override
  String get testConnection => 'Test connection';

  @override
  String get exitWithError => 'Exit with error';
}
