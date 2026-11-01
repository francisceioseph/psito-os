// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'notepad_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class NotepadLocalizationsPt extends NotepadLocalizations {
  NotepadLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Bloco de notas';

  @override
  String get welcome =>
      'Bem-vindo ao Psito Notepad!\n\nEscreva suas anotações aqui...';

  @override
  String get statusSessionOnly => 'Nota só nesta sessão';

  @override
  String get statusSaving => 'Salvando...';

  @override
  String statusSaved(Object file) {
    return 'Salvo em $file';
  }

  @override
  String get clear => 'Limpar';

  @override
  String get hint => 'Digite algo...';
}
