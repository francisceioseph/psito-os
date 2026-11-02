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
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get progress => 'Progress';

  @override
  String get volume => 'Volume';

  @override
  String get home => 'Home';

  @override
  String get library => 'Library';

  @override
  String get playlists => 'Playlists';

  @override
  String get folders => 'Folders';

  @override
  String get search => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String engineUnavailable(Object error) {
    return 'The audio engine is unavailable: $error';
  }

  @override
  String get openFailed => 'Could not play this file';

  @override
  String get addFolder => 'Add folder';

  @override
  String get addMusicFolder => 'Add music folder';

  @override
  String get folderNotVisible =>
      'The player can\'t see this folder. Choose one in your home or on an external disk.';

  @override
  String get folderAlreadyAdded => 'This folder is already in the library.';

  @override
  String libraryUnavailable(String error) {
    return 'Could not open the library: $error';
  }

  @override
  String get albums => 'Albums';

  @override
  String get unknownArtist => 'Unknown artist';

  @override
  String playAlbum(String album) {
    return 'Play $album';
  }

  @override
  String get hasLyrics => 'Has lyrics';

  @override
  String get moreOptions => 'More options';

  @override
  String get playNext => 'Play next';

  @override
  String get addToQueue => 'Add to queue';

  @override
  String get removeFromQueue => 'Remove from queue';

  @override
  String get queue => 'Queue';

  @override
  String get queueEmpty => 'The queue is empty';

  @override
  String get close => 'Close';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get previousTrack => 'Previous track';

  @override
  String get nextTrack => 'Next track';

  @override
  String get repeatOff => 'Repeat: off';

  @override
  String get repeatAll => 'Repeat: all';

  @override
  String get repeatOne => 'Repeat: one';

  @override
  String get homeSubtitle => 'Your local library, the way you left it';

  @override
  String get continueListening => 'Continue where you left off';

  @override
  String get continuePlaying => 'Continue';

  @override
  String stoppedAt(String artist, String position, String duration) {
    return '$artist · stopped at $position of $duration';
  }

  @override
  String get shuffleAll => 'Shuffle everything';

  @override
  String get recentlyAdded => 'Recently added';

  @override
  String get seeAll => 'See all';

  @override
  String get mostPlayed => 'Most played';

  @override
  String get comingSoon => 'This screen arrives in a later phase.';

  @override
  String get emptyTitle => 'Your library is empty';

  @override
  String get emptyBody =>
      'Point to the folder where your music is. The player reads the files directly from your computer and sends nothing out.';

  @override
  String useFolder(String folder) {
    return 'Use $folder';
  }

  @override
  String get acceptedFormats => 'Accepted formats';

  @override
  String get scanning => 'Reading your library';

  @override
  String get scanSubtitle =>
      'Reading in progress: you can already listen to what was found';

  @override
  String scanFiles(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString of $totalString files';
  }

  @override
  String get scanLessThanMinute => 'less than a minute left';

  @override
  String scanMinutesLeft(int n) {
    return 'about $n min left';
  }

  @override
  String get pauseScan => 'Pause';

  @override
  String get resumeScan => 'Resume';

  @override
  String get cancelScan => 'Cancel';

  @override
  String get scanKeepsGoing => 'Reading continues if you leave this screen';

  @override
  String get foundSoFar => 'Found so far';

  @override
  String get updateAll => 'Update all';

  @override
  String get updateFolder => 'Update folder';

  @override
  String get removeFolder => 'Remove from library';

  @override
  String get folderMissing => 'Disk not found';

  @override
  String get notScanned => 'Not read yet';

  @override
  String get scannedJustNow => 'Updated just now';

  @override
  String scannedMinutes(int n) {
    return 'Updated $n min ago';
  }

  @override
  String scannedHours(int n) {
    return 'Updated $n h ago';
  }

  @override
  String scannedDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Updated $n days ago',
      one: 'Updated yesterday',
      zero: 'Updated today',
    );
    return '$_temp0';
  }

  @override
  String lengthMinutes(int n) {
    return '$n min';
  }

  @override
  String lengthHours(int h, int m) {
    return '$h h $m min';
  }

  @override
  String albumCount(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString albums',
      one: '1 album',
      zero: '0 albums',
    );
    return '$_temp0';
  }

  @override
  String trackCount(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString tracks',
      one: '1 track',
      zero: '0 tracks',
    );
    return '$_temp0';
  }

  @override
  String folderCount(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString folders',
      one: '1 folder',
      zero: '0 folders',
    );
    return '$_temp0';
  }

  @override
  String coversFound(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString covers found',
      one: '1 cover found',
      zero: '0 covers found',
    );
    return '$_temp0';
  }

  @override
  String filesSkipped(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString files skipped',
      one: '1 file skipped',
      zero: '0 files skipped',
    );
    return '$_temp0';
  }

  @override
  String get back => 'Back';

  @override
  String get songs => 'Songs';

  @override
  String get artists => 'Artists';

  @override
  String get genres => 'Genres';

  @override
  String get allFilter => 'All';

  @override
  String get allSongs => 'All';

  @override
  String get favorites => 'Favorites';

  @override
  String get mineFilter => 'Mine';

  @override
  String get automaticFilter => 'Automatic';

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortRecent => 'Recent';

  @override
  String get sortAZ => 'A to Z';

  @override
  String get sortArtist => 'Artist';

  @override
  String get sortYear => 'Year';

  @override
  String get sortMostTracks => 'Most songs';

  @override
  String get columnTitle => 'Title';

  @override
  String get columnAlbum => 'Album';

  @override
  String get columnDuration => 'Duration';

  @override
  String get columnFormat => 'Format';

  @override
  String get viewGrid => 'Grid';

  @override
  String get viewList => 'List';

  @override
  String get searchHint => 'Search the library';

  @override
  String get searchSongsHint => 'Search songs';

  @override
  String get searchArtistsHint => 'Search artists';

  @override
  String get searchGenresHint => 'Search genres';

  @override
  String get searchAlbumsHint => 'Search albums';

  @override
  String get searchFoldersHint => 'Search folders';

  @override
  String get searchAllHint => 'Songs, albums, artists or folders';

  @override
  String get searchShortcut => 'Ctrl K';

  @override
  String get clearSearch => 'Clear search';

  @override
  String noResults(String query) {
    return 'Nothing found for \"$query\"';
  }

  @override
  String get searchPrompt => 'Type to search your library.';

  @override
  String get bestResult => 'Best result';

  @override
  String get playAll => 'Play all';

  @override
  String get kindArtist => 'Artist';

  @override
  String get kindAlbum => 'Album';

  @override
  String get kindSong => 'Song';

  @override
  String get nothingHere => 'Nothing here yet.';

  @override
  String get noGenre => 'No genre';

  @override
  String get fileUnavailable => 'This file is not available right now';

  @override
  String get nothingAvailable =>
      'These songs are not available. Is the disk connected?';

  @override
  String get watchFolders => 'Watch folders for changes';

  @override
  String get watchFoldersBody =>
      'Detects new, changed and removed files while the player is open.';

  @override
  String get newPlaylist => 'New playlist';

  @override
  String get importM3u => 'Import M3U';

  @override
  String get exportM3u => 'Export M3U';

  @override
  String get renamePlaylist => 'Rename';

  @override
  String get deletePlaylist => 'Delete playlist';

  @override
  String deletePlaylistBody(String name) {
    return 'Delete \"$name\"? The music files stay where they are.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get playlistName => 'Playlist name';

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String get removeFromPlaylist => 'Remove from playlist';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get dragToReorder => 'Drag to reorder';

  @override
  String get autoFavorites => 'Favorites';

  @override
  String get autoMostPlayed => 'Most played';

  @override
  String get autoRecent => 'Recently added';

  @override
  String get automaticSuffix => 'automatic';

  @override
  String exportFailed(String error) {
    return 'Could not write the file: $error';
  }

  @override
  String importFailed(String error) {
    return 'Could not read the file: $error';
  }

  @override
  String lengthDays(int d, int h) {
    return '$d d $h h';
  }

  @override
  String artistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n artists',
      one: '1 artist',
    );
    return '$_temp0';
  }

  @override
  String genreCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n genres',
      one: '1 genre',
    );
    return '$_temp0';
  }

  @override
  String playlistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n playlists',
      one: '1 playlist',
    );
    return '$_temp0';
  }

  @override
  String fileCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String folderChanges(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n changes',
      one: '1 change',
    );
    return '$_temp0';
  }

  @override
  String imported(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n songs imported',
      one: '1 song imported',
    );
    return '$_temp0';
  }

  @override
  String importedRemote(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n network addresses skipped',
      one: '1 network address skipped',
    );
    return '$_temp0';
  }

  @override
  String get lyricsTab => 'Lyrics';

  @override
  String get coverTab => 'Cover';

  @override
  String get noLyrics => 'This track has no lyrics';

  @override
  String get lyricsSynced => 'synced';

  @override
  String get lyricsUnsynced => 'not synced';

  @override
  String get lyricsEmbedded => 'In the tags';

  @override
  String get lyricsTiming => 'Adjust the lyrics timing';

  @override
  String get lyricsEarlier => 'Show the lyrics earlier';

  @override
  String get lyricsLater => 'Show the lyrics later';

  @override
  String get lyricsResetTiming => 'Reset the timing';

  @override
  String get withLyrics => 'With lyrics';

  @override
  String get upNext => 'Up next';

  @override
  String get clearQueue => 'Clear';

  @override
  String get saveAsPlaylist => 'Save as playlist';

  @override
  String get detailAlbum => 'Album';

  @override
  String get detailGenre => 'Genre';

  @override
  String get detailFile => 'File';

  @override
  String get detailCover => 'Cover';

  @override
  String get detailFolder => 'Folder';

  @override
  String get coverEmbedded => 'Embedded';

  @override
  String get coverGenerated => 'Generated';

  @override
  String secondsOffset(String value) {
    return '$value s';
  }

  @override
  String playlistSaved(String name) {
    return 'Saved as “$name”';
  }
}
