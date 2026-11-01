// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'notepad_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class NotepadLocalizationsEn extends NotepadLocalizations {
  NotepadLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Notepad';

  @override
  String get welcome => 'Welcome to Psito Notepad!\n\nWrite your notes here...';

  @override
  String get statusSessionOnly => 'Note for this session only';

  @override
  String get statusSaving => 'Saving...';

  @override
  String statusSaved(Object file) {
    return 'Saved to $file';
  }

  @override
  String get clear => 'Clear';

  @override
  String get hint => 'Type something...';
}
