import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'files_localizations_en.dart';
import 'files_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of FilesLocalizations
/// returned by `FilesLocalizations.of(context)`.
///
/// Applications need to include `FilesLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/files_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: FilesLocalizations.localizationsDelegates,
///   supportedLocales: FilesLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the FilesLocalizations.supportedLocales
/// property.
abstract class FilesLocalizations {
  FilesLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static FilesLocalizations of(BuildContext context) {
    return Localizations.of<FilesLocalizations>(context, FilesLocalizations)!;
  }

  static const LocalizationsDelegate<FilesLocalizations> delegate =
      _FilesLocalizationsDelegate();

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

  /// No description provided for @sizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 byte} other{{count} bytes}}'**
  String sizeBytes(num count);

  /// No description provided for @dateToday.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String dateToday(Object time);

  /// No description provided for @dateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String dateYesterday(Object time);

  /// No description provided for @dateFull.
  ///
  /// In en, this message translates to:
  /// **'{date}, {time}'**
  String dateFull(Object date, Object time);

  /// No description provided for @placeHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get placeHome;

  /// No description provided for @placeComputer.
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get placeComputer;

  /// No description provided for @placeTrash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get placeTrash;

  /// No description provided for @kindFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get kindFolder;

  /// No description provided for @openFromTrash.
  ///
  /// In en, this message translates to:
  /// **'To open it, put the item back first.'**
  String get openFromTrash;

  /// No description provided for @deleteForeverOne.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" forever?'**
  String deleteForeverOne(Object name);

  /// No description provided for @deleteForeverMany.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} items forever?'**
  String deleteForeverMany(Object count);

  /// No description provided for @cannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get cannotUndo;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @emptyTrashQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete everything in the trash?'**
  String get emptyTrashQuestion;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get empty;

  /// No description provided for @setDefaultFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the default app ({detail})'**
  String setDefaultFailed(Object detail);

  /// No description provided for @searchingFor.
  ///
  /// In en, this message translates to:
  /// **'Searching \"{query}\"'**
  String searchingFor(Object query);

  /// No description provided for @errorFolderGone.
  ///
  /// In en, this message translates to:
  /// **'The folder no longer exists.'**
  String get errorFolderGone;

  /// No description provided for @errorNoPermission.
  ///
  /// In en, this message translates to:
  /// **'No permission to open.'**
  String get errorNoPermission;

  /// No description provided for @errorNotAFolder.
  ///
  /// In en, this message translates to:
  /// **'Not a folder.'**
  String get errorNotAFolder;

  /// No description provided for @jobAmount.
  ///
  /// In en, this message translates to:
  /// **'({done} of {total})'**
  String jobAmount(Object done, Object total);

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemCount(num count);

  /// No description provided for @itemsSelected.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {count, plural, =1{1 item} other{{count} items}} selected'**
  String itemsSelected(num count, Object selected);

  /// No description provided for @statusSearching.
  ///
  /// In en, this message translates to:
  /// **'{text}, searching...'**
  String statusSearching(Object text);

  /// No description provided for @undoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Undo {action} (Ctrl+Z)'**
  String undoTooltip(Object action);

  /// No description provided for @emptyTrashFolder.
  ///
  /// In en, this message translates to:
  /// **'The trash is empty.'**
  String get emptyTrashFolder;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searching;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found.'**
  String get nothingFound;

  /// No description provided for @emptyFolder.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty.'**
  String get emptyFolder;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @pasteItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Paste 1 item} other{Paste {count} items}}'**
  String pasteItems(num count);

  /// No description provided for @modifiedAt.
  ///
  /// In en, this message translates to:
  /// **'Modified: {date}'**
  String modifiedAt(Object date);

  /// No description provided for @sizeWithBytes.
  ///
  /// In en, this message translates to:
  /// **'{size} ({bytes} bytes)'**
  String sizeWithBytes(Object bytes, Object size);

  /// No description provided for @sizeAndItems.
  ///
  /// In en, this message translates to:
  /// **'{size}, {count, plural, =1{1 item} other{{count} items}}'**
  String sizeAndItems(num count, Object size);

  /// No description provided for @conflictExists.
  ///
  /// In en, this message translates to:
  /// **'An item named \"{name}\" already exists in \"{folder}\".'**
  String conflictExists(Object folder, Object name);

  /// No description provided for @appDefault.
  ///
  /// In en, this message translates to:
  /// **'{app} (default)'**
  String appDefault(Object app);

  /// No description provided for @alwaysOpenWith.
  ///
  /// In en, this message translates to:
  /// **'Always open \"{kind}\" with it'**
  String alwaysOpenWith(Object kind);

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @calculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating...'**
  String get calculating;

  /// No description provided for @kind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get kind;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @wherefrom.
  ///
  /// In en, this message translates to:
  /// **'Came from'**
  String get wherefrom;

  /// No description provided for @where.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get where;

  /// No description provided for @pointsTo.
  ///
  /// In en, this message translates to:
  /// **'Points to'**
  String get pointsTo;

  /// No description provided for @deletedAt.
  ///
  /// In en, this message translates to:
  /// **'Deleted on'**
  String get deletedAt;

  /// No description provided for @modified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get modified;

  /// No description provided for @accessed.
  ///
  /// In en, this message translates to:
  /// **'Accessed'**
  String get accessed;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @openWith.
  ///
  /// In en, this message translates to:
  /// **'Open with'**
  String get openWith;

  /// No description provided for @noApp.
  ///
  /// In en, this message translates to:
  /// **'No app'**
  String get noApp;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @conflictFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Replacing swaps the whole folder, with what\'s inside it.'**
  String get conflictFolderHint;

  /// No description provided for @conflictFileHint.
  ///
  /// In en, this message translates to:
  /// **'Replacing deletes what\'s there.'**
  String get conflictFileHint;

  /// No description provided for @applyToNext.
  ///
  /// In en, this message translates to:
  /// **'Do the same for the next ones'**
  String get applyToNext;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @keepBoth.
  ///
  /// In en, this message translates to:
  /// **'Keep both'**
  String get keepBoth;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @noAppTakesFiles.
  ///
  /// In en, this message translates to:
  /// **'No app takes files.'**
  String get noAppTakesFiles;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @emptyTrashEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Empty trash...'**
  String get emptyTrashEllipsis;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Put back'**
  String get restore;

  /// No description provided for @deleteNow.
  ///
  /// In en, this message translates to:
  /// **'Delete immediately...'**
  String get deleteNow;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @keySpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get keySpace;

  /// No description provided for @getInfo.
  ///
  /// In en, this message translates to:
  /// **'Get info'**
  String get getInfo;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @viewIcons.
  ///
  /// In en, this message translates to:
  /// **'Icons'**
  String get viewIcons;

  /// No description provided for @viewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewList;

  /// No description provided for @viewColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get viewColumns;

  /// No description provided for @viewAs.
  ///
  /// In en, this message translates to:
  /// **'View as'**
  String get viewAs;

  /// No description provided for @hideHidden.
  ///
  /// In en, this message translates to:
  /// **'Hide hidden files'**
  String get hideHidden;

  /// No description provided for @showHidden.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get showHidden;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other...'**
  String get other;

  /// No description provided for @openInNewTab.
  ///
  /// In en, this message translates to:
  /// **'Open in new tab'**
  String get openInNewTab;

  /// No description provided for @moveToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to trash'**
  String get moveToTrash;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @cut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cut;

  /// No description provided for @addToSidebar.
  ///
  /// In en, this message translates to:
  /// **'Add to sidebar'**
  String get addToSidebar;

  /// No description provided for @showInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get showInFolder;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @removeFromSidebar.
  ///
  /// In en, this message translates to:
  /// **'Remove from sidebar'**
  String get removeFromSidebar;

  /// No description provided for @places.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get places;

  /// No description provided for @sidebar.
  ///
  /// In en, this message translates to:
  /// **'Sidebar'**
  String get sidebar;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back (Alt+←)'**
  String get back;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward (Alt+→)'**
  String get forward;

  /// No description provided for @viewIconsTip.
  ///
  /// In en, this message translates to:
  /// **'Icons (Ctrl+1)'**
  String get viewIconsTip;

  /// No description provided for @viewListTip.
  ///
  /// In en, this message translates to:
  /// **'List (Ctrl+2)'**
  String get viewListTip;

  /// No description provided for @viewColumnsTip.
  ///
  /// In en, this message translates to:
  /// **'Columns (Ctrl+3)'**
  String get viewColumnsTip;

  /// No description provided for @newFolderTip.
  ///
  /// In en, this message translates to:
  /// **'New folder (Ctrl+Shift+N)'**
  String get newFolderTip;

  /// No description provided for @newTabTip.
  ///
  /// In en, this message translates to:
  /// **'New tab (Ctrl+T)'**
  String get newTabTip;

  /// No description provided for @undoTip.
  ///
  /// In en, this message translates to:
  /// **'Undo (Ctrl+Z)'**
  String get undoTip;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @sortModified.
  ///
  /// In en, this message translates to:
  /// **'Date modified'**
  String get sortModified;

  /// No description provided for @reverseOrder.
  ///
  /// In en, this message translates to:
  /// **'Reverse order'**
  String get reverseOrder;

  /// No description provided for @foldersFirst.
  ///
  /// In en, this message translates to:
  /// **'Folders first'**
  String get foldersFirst;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @showHiddenTip.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files (Ctrl+H)'**
  String get showHiddenTip;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;
}

class _FilesLocalizationsDelegate
    extends LocalizationsDelegate<FilesLocalizations> {
  const _FilesLocalizationsDelegate();

  @override
  Future<FilesLocalizations> load(Locale locale) {
    return SynchronousFuture<FilesLocalizations>(
      lookupFilesLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_FilesLocalizationsDelegate old) => false;
}

FilesLocalizations lookupFilesLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return FilesLocalizationsEn();
    case 'pt':
      return FilesLocalizationsPt();
  }

  throw FlutterError(
    'FilesLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
