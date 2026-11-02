import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'shell_localizations_en.dart';
import 'shell_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of ShellLocalizations
/// returned by `ShellLocalizations.of(context)`.
///
/// Applications need to include `ShellLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/shell_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: ShellLocalizations.localizationsDelegates,
///   supportedLocales: ShellLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the ShellLocalizations.supportedLocales
/// property.
abstract class ShellLocalizations {
  ShellLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static ShellLocalizations of(BuildContext context) {
    return Localizations.of<ShellLocalizations>(context, ShellLocalizations)!;
  }

  static const LocalizationsDelegate<ShellLocalizations> delegate =
      _ShellLocalizationsDelegate();

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

  /// No description provided for @transferMore.
  ///
  /// In en, this message translates to:
  /// **'(and {count} more)'**
  String transferMore(Object count);

  /// No description provided for @newDocumentFile.
  ///
  /// In en, this message translates to:
  /// **'New document.txt'**
  String get newDocumentFile;

  /// No description provided for @shortcutBroken.
  ///
  /// In en, this message translates to:
  /// **'Broken shortcut'**
  String get shortcutBroken;

  /// No description provided for @shortcutBrokenBody.
  ///
  /// In en, this message translates to:
  /// **'The program for \"{name}\" no longer exists.'**
  String shortcutBrokenBody(Object name);

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemCount(Object count);

  /// No description provided for @pasteItems.
  ///
  /// In en, this message translates to:
  /// **'Paste {count} items'**
  String pasteItems(Object count);

  /// No description provided for @desktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get desktop;

  /// No description provided for @notification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notification;

  /// No description provided for @trustBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" hasn\'t been marked as trusted, and can open any program.'**
  String trustBody(Object name);

  /// No description provided for @closeWindows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Close} other{Close {count} windows}}'**
  String closeWindows(num count);

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home folder'**
  String get home;

  /// No description provided for @trash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trash;

  /// No description provided for @cantRename.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rename'**
  String get cantRename;

  /// No description provided for @renameAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameAction;

  /// No description provided for @cantCreateFolder.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the folder'**
  String get cantCreateFolder;

  /// No description provided for @cantTrash.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t move to the trash'**
  String get cantTrash;

  /// No description provided for @cantUndo.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t undo'**
  String get cantUndo;

  /// No description provided for @cantPaste.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t paste'**
  String get cantPaste;

  /// No description provided for @cantBringToDesk.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t bring to the desktop'**
  String get cantBringToDesk;

  /// No description provided for @cantCreateShortcut.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the shortcut'**
  String get cantCreateShortcut;

  /// No description provided for @cantCreateDocument.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the document'**
  String get cantCreateDocument;

  /// No description provided for @cantPreview.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t preview'**
  String get cantPreview;

  /// No description provided for @cantOpen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open'**
  String get cantOpen;

  /// No description provided for @cantTrust.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t trust the shortcut'**
  String get cantTrust;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @newDocumentEllipsis.
  ///
  /// In en, this message translates to:
  /// **'New document…'**
  String get newDocumentEllipsis;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @arrangeBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by…'**
  String get arrangeBy;

  /// No description provided for @cleanUp.
  ///
  /// In en, this message translates to:
  /// **'Clean up'**
  String get cleanUp;

  /// No description provided for @openInFiles.
  ///
  /// In en, this message translates to:
  /// **'Open in Files'**
  String get openInFiles;

  /// No description provided for @openTerminalHere.
  ///
  /// In en, this message translates to:
  /// **'Open terminal here'**
  String get openTerminalHere;

  /// No description provided for @changeWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Change wallpaper'**
  String get changeWallpaper;

  /// No description provided for @arrangeByTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get arrangeByTitle;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @sortKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get sortKind;

  /// No description provided for @sortDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get sortDate;

  /// No description provided for @sortSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sortSize;

  /// No description provided for @newDocument.
  ///
  /// In en, this message translates to:
  /// **'New document'**
  String get newDocument;

  /// No description provided for @emptyDocument.
  ///
  /// In en, this message translates to:
  /// **'Empty document'**
  String get emptyDocument;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

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

  /// No description provided for @moveToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to trash'**
  String get moveToTrash;

  /// No description provided for @emptyTrash.
  ///
  /// In en, this message translates to:
  /// **'Empty trash'**
  String get emptyTrash;

  /// No description provided for @openWithEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Open with…'**
  String get openWithEllipsis;

  /// No description provided for @showInFiles.
  ///
  /// In en, this message translates to:
  /// **'Show in Files'**
  String get showInFiles;

  /// No description provided for @pinToDock.
  ///
  /// In en, this message translates to:
  /// **'Pin to Dock'**
  String get pinToDock;

  /// No description provided for @openWith.
  ///
  /// In en, this message translates to:
  /// **'Open with'**
  String get openWith;

  /// No description provided for @otherEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Other…'**
  String get otherEllipsis;

  /// No description provided for @apps.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get apps;

  /// No description provided for @newWindow.
  ///
  /// In en, this message translates to:
  /// **'New window'**
  String get newWindow;

  /// No description provided for @openAtLogin.
  ///
  /// In en, this message translates to:
  /// **'Open at login'**
  String get openAtLogin;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @removeFromDock.
  ///
  /// In en, this message translates to:
  /// **'Remove from Dock'**
  String get removeFromDock;

  /// No description provided for @keepInDock.
  ///
  /// In en, this message translates to:
  /// **'Keep in Dock'**
  String get keepInDock;

  /// No description provided for @createDeskShortcut.
  ///
  /// In en, this message translates to:
  /// **'Create desktop shortcut'**
  String get createDeskShortcut;

  /// No description provided for @emptyTrashQuestion.
  ///
  /// In en, this message translates to:
  /// **'Empty the trash?'**
  String get emptyTrashQuestion;

  /// No description provided for @emptyTrashBody.
  ///
  /// In en, this message translates to:
  /// **'The items in the trash will be deleted for good.'**
  String get emptyTrashBody;

  /// No description provided for @emptyAction.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get emptyAction;

  /// No description provided for @trustQuestion.
  ///
  /// In en, this message translates to:
  /// **'Trust this shortcut?'**
  String get trustQuestion;

  /// No description provided for @trustAndOpen.
  ///
  /// In en, this message translates to:
  /// **'Trust and open'**
  String get trustAndOpen;

  /// No description provided for @polkitTitle.
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get polkitTitle;

  /// No description provided for @polkitPasswordOf.
  ///
  /// In en, this message translates to:
  /// **'Password for {user}'**
  String polkitPasswordOf(Object user);

  /// No description provided for @polkitWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password.'**
  String get polkitWrongPassword;

  /// No description provided for @polkitAuthenticate.
  ///
  /// In en, this message translates to:
  /// **'Authenticate'**
  String get polkitAuthenticate;

  /// No description provided for @polkitCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get polkitCancel;

  /// No description provided for @logoutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Log out of Psito OS?'**
  String get logoutQuestion;

  /// No description provided for @logoutBody.
  ///
  /// In en, this message translates to:
  /// **'Open apps will be closed.'**
  String get logoutBody;

  /// No description provided for @logoutAction.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logoutAction;

  /// No description provided for @networkApp.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkApp;

  /// No description provided for @portalTitle.
  ///
  /// In en, this message translates to:
  /// **'This network asks you to log in'**
  String get portalTitle;

  /// No description provided for @portalBody.
  ///
  /// In en, this message translates to:
  /// **'Click to open the login page in the browser.'**
  String get portalBody;

  /// No description provided for @disksApp.
  ///
  /// In en, this message translates to:
  /// **'Disks'**
  String get disksApp;

  /// No description provided for @diskUnnamed.
  ///
  /// In en, this message translates to:
  /// **'External disk'**
  String get diskUnnamed;

  /// No description provided for @diskEject.
  ///
  /// In en, this message translates to:
  /// **'Eject'**
  String get diskEject;

  /// No description provided for @diskPluggedBody.
  ///
  /// In en, this message translates to:
  /// **'Disk connected. Click to open it.'**
  String get diskPluggedBody;

  /// No description provided for @diskLockedBody.
  ///
  /// In en, this message translates to:
  /// **'This disk is encrypted. Click to enter its password.'**
  String get diskLockedBody;

  /// No description provided for @diskUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock {name}'**
  String diskUnlockTitle(Object name);

  /// No description provided for @diskUnlockBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the password of this disk.'**
  String get diskUnlockBody;

  /// No description provided for @diskUnlockHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get diskUnlockHint;

  /// No description provided for @diskUnlockWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong password.'**
  String get diskUnlockWrong;

  /// No description provided for @diskUnlockAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get diskUnlockAction;

  /// No description provided for @diskUnlockCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get diskUnlockCancel;

  /// No description provided for @diskUnlockShow.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get diskUnlockShow;

  /// No description provided for @diskUnlockHide.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get diskUnlockHide;

  /// No description provided for @diskOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this disk.'**
  String get diskOpenFailed;

  /// No description provided for @diskSafeToRemove.
  ///
  /// In en, this message translates to:
  /// **'You can remove the disk now.'**
  String get diskSafeToRemove;

  /// No description provided for @diskBusy.
  ///
  /// In en, this message translates to:
  /// **'The disk is in use. Close what is using it and try again.'**
  String get diskBusy;

  /// No description provided for @diskEjectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not eject the disk.'**
  String get diskEjectFailed;

  /// No description provided for @diskBusyBy.
  ///
  /// In en, this message translates to:
  /// **'The disk is in use by {names}. Close it and try again.'**
  String diskBusyBy(String names);

  /// No description provided for @diskWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing to the disk. Do not remove it yet.'**
  String get diskWriting;

  /// No description provided for @diskPulledBody.
  ///
  /// In en, this message translates to:
  /// **'The disk was removed without ejecting. Recent files may be incomplete.'**
  String get diskPulledBody;

  /// No description provided for @diskFullTitle.
  ///
  /// In en, this message translates to:
  /// **'The disk is almost full'**
  String get diskFullTitle;

  /// No description provided for @diskFullBody.
  ///
  /// In en, this message translates to:
  /// **'{free} left. Click to see what takes up space.'**
  String diskFullBody(String free);

  /// Window in the dock menu, when there are several monitors
  ///
  /// In en, this message translates to:
  /// **'{title} (screen {screen})'**
  String windowOnScreen(String title, int screen);
}

class _ShellLocalizationsDelegate
    extends LocalizationsDelegate<ShellLocalizations> {
  const _ShellLocalizationsDelegate();

  @override
  Future<ShellLocalizations> load(Locale locale) {
    return SynchronousFuture<ShellLocalizations>(
      lookupShellLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_ShellLocalizationsDelegate old) => false;
}

ShellLocalizations lookupShellLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return ShellLocalizationsEn();
    case 'pt':
      return ShellLocalizationsPt();
  }

  throw FlutterError(
    'ShellLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
