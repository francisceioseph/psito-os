// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'player_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class PlayerLocalizationsEn extends PlayerLocalizations {
  PlayerLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Music Player';

  @override
  String get noTrack => 'No track';

  @override
  String get openFile => 'Open file';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get progress => 'Progress';

  @override
  String get volume => 'Volume';

  @override
  String get library => 'Library';

  @override
  String get songs => 'Songs';

  @override
  String get artists => 'Artists';

  @override
  String get playlists => 'Playlists';

  @override
  String get folders => 'Folders';

  @override
  String get genres => 'Genres';

  @override
  String engineUnavailable(Object error) {
    return 'The audio engine is unavailable: $error';
  }

  @override
  String openFailed(Object error) {
    return 'Could not play this file: $error';
  }
}
