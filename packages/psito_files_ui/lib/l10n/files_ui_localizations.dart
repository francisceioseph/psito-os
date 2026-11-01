import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'files_ui_localizations_en.dart';
import 'files_ui_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of FilesUiLocalizations
/// returned by `FilesUiLocalizations.of(context)`.
///
/// Applications need to include `FilesUiLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/files_ui_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: FilesUiLocalizations.localizationsDelegates,
///   supportedLocales: FilesUiLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the FilesUiLocalizations.supportedLocales
/// property.
abstract class FilesUiLocalizations {
  FilesUiLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static FilesUiLocalizations of(BuildContext context) {
    return Localizations.of<FilesUiLocalizations>(
      context,
      FilesUiLocalizations,
    )!;
  }

  static const LocalizationsDelegate<FilesUiLocalizations> delegate =
      _FilesUiLocalizationsDelegate();

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

  /// No description provided for @fsErrorEmptyName.
  ///
  /// In en, this message translates to:
  /// **'The name can\'t be empty.'**
  String get fsErrorEmptyName;

  /// No description provided for @fsErrorSlashInName.
  ///
  /// In en, this message translates to:
  /// **'The name can\'t contain \"/\".'**
  String get fsErrorSlashInName;

  /// No description provided for @fsErrorReservedName.
  ///
  /// In en, this message translates to:
  /// **'That name is reserved.'**
  String get fsErrorReservedName;

  /// No description provided for @fsErrorNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'The name is too long.'**
  String get fsErrorNameTooLong;

  /// No description provided for @fsErrorNameTaken.
  ///
  /// In en, this message translates to:
  /// **'An item named \"{name}\" already exists.'**
  String fsErrorNameTaken(Object name);

  /// No description provided for @fsErrorIntoItself.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" can\'t go inside itself.'**
  String fsErrorIntoItself(Object name);

  /// No description provided for @fsErrorReplacesParent.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" can\'t replace the folder it\'s in.'**
  String fsErrorReplacesParent(Object name);

  /// No description provided for @fsErrorSystem.
  ///
  /// In en, this message translates to:
  /// **'{name}: {detail}'**
  String fsErrorSystem(Object detail, Object name);

  /// No description provided for @fsActionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get fsActionRename;

  /// No description provided for @fsActionNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get fsActionNewFolder;

  /// No description provided for @fsActionNewDocument.
  ///
  /// In en, this message translates to:
  /// **'New document'**
  String get fsActionNewDocument;

  /// No description provided for @fsActionCreateShortcut.
  ///
  /// In en, this message translates to:
  /// **'Create shortcut'**
  String get fsActionCreateShortcut;

  /// No description provided for @fsActionTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to trash'**
  String get fsActionTrash;

  /// No description provided for @fsActionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get fsActionCopy;

  /// No description provided for @fsActionMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get fsActionMove;

  /// No description provided for @fsActionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get fsActionDuplicate;

  /// No description provided for @fsActionArrange.
  ///
  /// In en, this message translates to:
  /// **'Arrange'**
  String get fsActionArrange;

  /// No description provided for @fsActionCleanUp.
  ///
  /// In en, this message translates to:
  /// **'Clean up'**
  String get fsActionCleanUp;

  /// No description provided for @undoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo {action}'**
  String undoAction(Object action);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @newFolderName.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolderName;

  /// No description provided for @copyWord.
  ///
  /// In en, this message translates to:
  /// **'copy'**
  String get copyWord;

  /// No description provided for @jobCopying.
  ///
  /// In en, this message translates to:
  /// **'Copying'**
  String get jobCopying;

  /// No description provided for @jobMoving.
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get jobMoving;

  /// No description provided for @jobDuplicating.
  ///
  /// In en, this message translates to:
  /// **'Duplicating'**
  String get jobDuplicating;
}

class _FilesUiLocalizationsDelegate
    extends LocalizationsDelegate<FilesUiLocalizations> {
  const _FilesUiLocalizationsDelegate();

  @override
  Future<FilesUiLocalizations> load(Locale locale) {
    return SynchronousFuture<FilesUiLocalizations>(
      lookupFilesUiLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_FilesUiLocalizationsDelegate old) => false;
}

FilesUiLocalizations lookupFilesUiLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return FilesUiLocalizationsEn();
    case 'pt':
      return FilesUiLocalizationsPt();
  }

  throw FlutterError(
    'FilesUiLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
