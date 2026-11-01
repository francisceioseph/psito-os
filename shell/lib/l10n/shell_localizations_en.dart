// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'shell_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class ShellLocalizationsEn extends ShellLocalizations {
  ShellLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String transferMore(Object count) {
    return '(and $count more)';
  }

  @override
  String get newDocumentFile => 'New document.txt';

  @override
  String get shortcutBroken => 'Broken shortcut';

  @override
  String shortcutBrokenBody(Object name) {
    return 'The program for \"$name\" no longer exists.';
  }

  @override
  String itemCount(Object count) {
    return '$count items';
  }

  @override
  String pasteItems(Object count) {
    return 'Paste $count items';
  }

  @override
  String get desktop => 'Desktop';

  @override
  String get notification => 'Notification';

  @override
  String trustBody(Object name) {
    return '\"$name\" hasn\'t been marked as trusted, and can open any program.';
  }

  @override
  String closeWindows(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Close $count windows',
      one: 'Close',
    );
    return '$_temp0';
  }

  @override
  String get home => 'Home folder';

  @override
  String get trash => 'Trash';

  @override
  String get cantRename => 'Couldn\'t rename';

  @override
  String get renameAction => 'Rename';

  @override
  String get cantCreateFolder => 'Couldn\'t create the folder';

  @override
  String get cantTrash => 'Couldn\'t move to the trash';

  @override
  String get cantUndo => 'Couldn\'t undo';

  @override
  String get cantPaste => 'Couldn\'t paste';

  @override
  String get cantBringToDesk => 'Couldn\'t bring to the desktop';

  @override
  String get cantCreateShortcut => 'Couldn\'t create the shortcut';

  @override
  String get cantCreateDocument => 'Couldn\'t create the document';

  @override
  String get cantPreview => 'Couldn\'t preview';

  @override
  String get cantOpen => 'Couldn\'t open';

  @override
  String get cantTrust => 'Couldn\'t trust the shortcut';

  @override
  String get newFolder => 'New folder';

  @override
  String get newDocumentEllipsis => 'New document…';

  @override
  String get paste => 'Paste';

  @override
  String get undo => 'Undo';

  @override
  String get arrangeBy => 'Sort by…';

  @override
  String get cleanUp => 'Clean up';

  @override
  String get openInFiles => 'Open in Files';

  @override
  String get openTerminalHere => 'Open terminal here';

  @override
  String get changeWallpaper => 'Change wallpaper';

  @override
  String get arrangeByTitle => 'Sort by';

  @override
  String get sortName => 'Name';

  @override
  String get sortKind => 'Kind';

  @override
  String get sortDate => 'Date';

  @override
  String get sortSize => 'Size';

  @override
  String get newDocument => 'New document';

  @override
  String get emptyDocument => 'Empty document';

  @override
  String get open => 'Open';

  @override
  String get copy => 'Copy';

  @override
  String get cut => 'Cut';

  @override
  String get moveToTrash => 'Move to trash';

  @override
  String get emptyTrash => 'Empty trash';

  @override
  String get openWithEllipsis => 'Open with…';

  @override
  String get showInFiles => 'Show in Files';

  @override
  String get pinToDock => 'Pin to Dock';

  @override
  String get openWith => 'Open with';

  @override
  String get otherEllipsis => 'Other…';

  @override
  String get apps => 'Apps';

  @override
  String get newWindow => 'New window';

  @override
  String get openAtLogin => 'Open at login';

  @override
  String get hide => 'Hide';

  @override
  String get removeFromDock => 'Remove from Dock';

  @override
  String get keepInDock => 'Keep in Dock';

  @override
  String get createDeskShortcut => 'Create desktop shortcut';

  @override
  String get emptyTrashQuestion => 'Empty the trash?';

  @override
  String get emptyTrashBody =>
      'The items in the trash will be deleted for good.';

  @override
  String get emptyAction => 'Empty';

  @override
  String get trustQuestion => 'Trust this shortcut?';

  @override
  String get trustAndOpen => 'Trust and open';

  @override
  String get polkitTitle => 'Authentication required';

  @override
  String polkitPasswordOf(Object user) {
    return 'Password for $user';
  }

  @override
  String get polkitWrongPassword => 'Wrong password.';

  @override
  String get polkitAuthenticate => 'Authenticate';

  @override
  String get polkitCancel => 'Cancel';

  @override
  String get logoutQuestion => 'Log out of Psito OS?';

  @override
  String get logoutBody => 'Open apps will be closed.';

  @override
  String get logoutAction => 'Log out';

  @override
  String get networkApp => 'Network';

  @override
  String get portalTitle => 'This network asks you to log in';

  @override
  String get portalBody => 'Click to open the login page in the browser.';
}
