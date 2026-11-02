// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'player_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class PlayerLocalizationsPt extends PlayerLocalizations {
  PlayerLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Player de música';

  @override
  String get noTrack => 'Nenhuma faixa';

  @override
  String get openFile => 'Abrir arquivo';

  @override
  String get play => 'Tocar';

  @override
  String get pause => 'Pausar';

  @override
  String get progress => 'Progresso';

  @override
  String get volume => 'Volume';

  @override
  String get home => 'Início';

  @override
  String get library => 'Biblioteca';

  @override
  String get playlists => 'Playlists';

  @override
  String get folders => 'Pastas';

  @override
  String get search => 'Buscar';

  @override
  String get settings => 'Ajustes';

  @override
  String engineUnavailable(Object error) {
    return 'O motor de áudio não está disponível: $error';
  }

  @override
  String openFailed(Object error) {
    return 'Não foi possível tocar este arquivo: $error';
  }
}
