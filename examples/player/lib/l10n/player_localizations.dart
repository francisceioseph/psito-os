import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'player_localizations_en.dart';
import 'player_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of PlayerLocalizations
/// returned by `PlayerLocalizations.of(context)`.
///
/// Applications need to include `PlayerLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/player_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: PlayerLocalizations.localizationsDelegates,
///   supportedLocales: PlayerLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the PlayerLocalizations.supportedLocales
/// property.
abstract class PlayerLocalizations {
  PlayerLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static PlayerLocalizations of(BuildContext context) {
    return Localizations.of<PlayerLocalizations>(context, PlayerLocalizations)!;
  }

  static const LocalizationsDelegate<PlayerLocalizations> delegate =
      _PlayerLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Music Player'**
  String get appName;

  /// No description provided for @noTrack.
  ///
  /// In en, this message translates to:
  /// **'No track'**
  String get noTrack;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @folders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @engineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The audio engine is unavailable: {error}'**
  String engineUnavailable(Object error);

  /// No description provided for @openFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play this file: {error}'**
  String openFailed(Object error);

  /// No description provided for @addFolder.
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get addFolder;

  /// No description provided for @addMusicFolder.
  ///
  /// In en, this message translates to:
  /// **'Add music folder'**
  String get addMusicFolder;

  /// No description provided for @folderNotVisible.
  ///
  /// In en, this message translates to:
  /// **'The player can\'t see this folder. Choose one in your home or on an external disk.'**
  String get folderNotVisible;

  /// No description provided for @folderAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'This folder is already in the library.'**
  String get folderAlreadyAdded;

  /// No description provided for @libraryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open the library: {error}'**
  String libraryUnavailable(String error);

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @unknownArtist.
  ///
  /// In en, this message translates to:
  /// **'Unknown artist'**
  String get unknownArtist;

  /// No description provided for @playAlbum.
  ///
  /// In en, this message translates to:
  /// **'Play {album}'**
  String playAlbum(String album);

  /// No description provided for @hasLyrics.
  ///
  /// In en, this message translates to:
  /// **'Has lyrics'**
  String get hasLyrics;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get playNext;

  /// No description provided for @addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get addToQueue;

  /// No description provided for @removeFromQueue.
  ///
  /// In en, this message translates to:
  /// **'Remove from queue'**
  String get removeFromQueue;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'The queue is empty'**
  String get queueEmpty;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @previousTrack.
  ///
  /// In en, this message translates to:
  /// **'Previous track'**
  String get previousTrack;

  /// No description provided for @nextTrack.
  ///
  /// In en, this message translates to:
  /// **'Next track'**
  String get nextTrack;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat: off'**
  String get repeatOff;

  /// No description provided for @repeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat: all'**
  String get repeatAll;

  /// No description provided for @repeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat: one'**
  String get repeatOne;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your local library, the way you left it'**
  String get homeSubtitle;

  /// No description provided for @continueListening.
  ///
  /// In en, this message translates to:
  /// **'Continue where you left off'**
  String get continueListening;

  /// No description provided for @continuePlaying.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continuePlaying;

  /// No description provided for @stoppedAt.
  ///
  /// In en, this message translates to:
  /// **'{artist} · stopped at {position} of {duration}'**
  String stoppedAt(String artist, String position, String duration);

  /// No description provided for @shuffleAll.
  ///
  /// In en, this message translates to:
  /// **'Shuffle everything'**
  String get shuffleAll;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get recentlyAdded;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @mostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most played'**
  String get mostPlayed;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'This screen arrives in a later phase.'**
  String get comingSoon;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get emptyTitle;

  /// No description provided for @emptyBody.
  ///
  /// In en, this message translates to:
  /// **'Point to the folder where your music is. The player reads the files directly from your computer and sends nothing out.'**
  String get emptyBody;

  /// No description provided for @useFolder.
  ///
  /// In en, this message translates to:
  /// **'Use {folder}'**
  String useFolder(String folder);

  /// No description provided for @acceptedFormats.
  ///
  /// In en, this message translates to:
  /// **'Accepted formats'**
  String get acceptedFormats;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Reading your library'**
  String get scanning;

  /// No description provided for @scanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reading in progress: you can already listen to what was found'**
  String get scanSubtitle;

  /// No description provided for @scanFiles.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} files'**
  String scanFiles(int done, int total);

  /// No description provided for @scanLessThanMinute.
  ///
  /// In en, this message translates to:
  /// **'less than a minute left'**
  String get scanLessThanMinute;

  /// No description provided for @scanMinutesLeft.
  ///
  /// In en, this message translates to:
  /// **'about {n} min left'**
  String scanMinutesLeft(int n);

  /// No description provided for @pauseScan.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseScan;

  /// No description provided for @resumeScan.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeScan;

  /// No description provided for @cancelScan.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelScan;

  /// No description provided for @scanKeepsGoing.
  ///
  /// In en, this message translates to:
  /// **'Reading continues if you leave this screen'**
  String get scanKeepsGoing;

  /// No description provided for @foundSoFar.
  ///
  /// In en, this message translates to:
  /// **'Found so far'**
  String get foundSoFar;

  /// No description provided for @updateAll.
  ///
  /// In en, this message translates to:
  /// **'Update all'**
  String get updateAll;

  /// No description provided for @updateFolder.
  ///
  /// In en, this message translates to:
  /// **'Update folder'**
  String get updateFolder;

  /// No description provided for @removeFolder.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get removeFolder;

  /// No description provided for @folderMissing.
  ///
  /// In en, this message translates to:
  /// **'Disk not found'**
  String get folderMissing;

  /// No description provided for @notScanned.
  ///
  /// In en, this message translates to:
  /// **'Not read yet'**
  String get notScanned;

  /// No description provided for @scannedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Updated just now'**
  String get scannedJustNow;

  /// No description provided for @scannedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Updated {n} min ago'**
  String scannedMinutes(int n);

  /// No description provided for @scannedHours.
  ///
  /// In en, this message translates to:
  /// **'Updated {n} h ago'**
  String scannedHours(int n);

  /// No description provided for @scannedDays.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{Updated today} =1{Updated yesterday} other{Updated {n} days ago}}'**
  String scannedDays(int n);

  /// No description provided for @lengthMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String lengthMinutes(int n);

  /// No description provided for @lengthHours.
  ///
  /// In en, this message translates to:
  /// **'{h} h {m} min'**
  String lengthHours(int h, int m);

  /// No description provided for @albumCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{0 albums} =1{1 album} other{{n} albums}}'**
  String albumCount(int n);

  /// No description provided for @trackCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{0 tracks} =1{1 track} other{{n} tracks}}'**
  String trackCount(int n);

  /// No description provided for @folderCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{0 folders} =1{1 folder} other{{n} folders}}'**
  String folderCount(int n);

  /// No description provided for @coversFound.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{0 covers found} =1{1 cover found} other{{n} covers found}}'**
  String coversFound(int n);

  /// No description provided for @filesSkipped.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{0 files skipped} =1{1 file skipped} other{{n} files skipped}}'**
  String filesSkipped(int n);
}

class _PlayerLocalizationsDelegate
    extends LocalizationsDelegate<PlayerLocalizations> {
  const _PlayerLocalizationsDelegate();

  @override
  Future<PlayerLocalizations> load(Locale locale) {
    return SynchronousFuture<PlayerLocalizations>(
      lookupPlayerLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_PlayerLocalizationsDelegate old) => false;
}

PlayerLocalizations lookupPlayerLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return PlayerLocalizationsEn();
    case 'pt':
      return PlayerLocalizationsPt();
  }

  throw FlutterError(
    'PlayerLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
