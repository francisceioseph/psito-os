// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'files_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class FilesLocalizationsEn extends FilesLocalizations {
  FilesLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String sizeBytes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bytes',
      one: '1 byte',
    );
    return '$_temp0';
  }

  @override
  String dateToday(Object time) {
    return 'Today, $time';
  }

  @override
  String dateYesterday(Object time) {
    return 'Yesterday, $time';
  }

  @override
  String dateFull(Object date, Object time) {
    return '$date, $time';
  }

  @override
  String get placeHome => 'Home';

  @override
  String get placeComputer => 'Computer';

  @override
  String get placeTrash => 'Trash';

  @override
  String get kindFolder => 'Folder';

  @override
  String get openFromTrash => 'To open it, put the item back first.';

  @override
  String deleteForeverOne(Object name) {
    return 'Delete \"$name\" forever?';
  }

  @override
  String deleteForeverMany(Object count) {
    return 'Delete $count items forever?';
  }

  @override
  String get cannotUndo => 'This can\'t be undone.';

  @override
  String get delete => 'Delete';

  @override
  String get emptyTrashQuestion => 'Delete everything in the trash?';

  @override
  String get empty => 'Empty';

  @override
  String setDefaultFailed(Object detail) {
    return 'Couldn\'t change the default app ($detail)';
  }

  @override
  String searchingFor(Object query) {
    return 'Searching \"$query\"';
  }

  @override
  String get errorFolderGone => 'The folder no longer exists.';

  @override
  String get errorNoPermission => 'No permission to open.';

  @override
  String get errorNotAFolder => 'Not a folder.';

  @override
  String jobAmount(Object done, Object total) {
    return '($done of $total)';
  }

  @override
  String itemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String itemsSelected(num count, Object selected) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$selected of $_temp0 selected';
  }

  @override
  String statusSearching(Object text) {
    return '$text, searching...';
  }

  @override
  String undoTooltip(Object action) {
    return 'Undo $action (Ctrl+Z)';
  }

  @override
  String get emptyTrashFolder => 'The trash is empty.';

  @override
  String get searching => 'Searching...';

  @override
  String get nothingFound => 'Nothing found.';

  @override
  String get emptyFolder => 'This folder is empty.';

  @override
  String get paste => 'Paste';

  @override
  String pasteItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Paste $count items',
      one: 'Paste 1 item',
    );
    return '$_temp0';
  }

  @override
  String modifiedAt(Object date) {
    return 'Modified: $date';
  }

  @override
  String sizeWithBytes(Object bytes, Object size) {
    return '$size ($bytes bytes)';
  }

  @override
  String sizeAndItems(num count, Object size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$size, $_temp0';
  }

  @override
  String conflictExists(Object folder, Object name) {
    return 'An item named \"$name\" already exists in \"$folder\".';
  }

  @override
  String appDefault(Object app) {
    return '$app (default)';
  }

  @override
  String alwaysOpenWith(Object kind) {
    return 'Always open \"$kind\" with it';
  }

  @override
  String get open => 'Open';

  @override
  String get calculating => 'Calculating...';

  @override
  String get kind => 'Kind';

  @override
  String get size => 'Size';

  @override
  String get wherefrom => 'Came from';

  @override
  String get where => 'Where';

  @override
  String get pointsTo => 'Points to';

  @override
  String get deletedAt => 'Deleted on';

  @override
  String get modified => 'Modified';

  @override
  String get accessed => 'Accessed';

  @override
  String get permissions => 'Permissions';

  @override
  String get openWith => 'Open with';

  @override
  String get noApp => 'No app';

  @override
  String get close => 'Close';

  @override
  String get conflictFolderHint =>
      'Replacing swaps the whole folder, with what\'s inside it.';

  @override
  String get conflictFileHint => 'Replacing deletes what\'s there.';

  @override
  String get applyToNext => 'Do the same for the next ones';

  @override
  String get skip => 'Skip';

  @override
  String get keepBoth => 'Keep both';

  @override
  String get replace => 'Replace';

  @override
  String get noAppTakesFiles => 'No app takes files.';

  @override
  String get cancel => 'Cancel';

  @override
  String get emptyTrashEllipsis => 'Empty trash...';

  @override
  String get restore => 'Put back';

  @override
  String get deleteNow => 'Delete immediately...';

  @override
  String get preview => 'Preview';

  @override
  String get keySpace => 'Space';

  @override
  String get getInfo => 'Get info';

  @override
  String get newFolder => 'New folder';

  @override
  String get viewIcons => 'Icons';

  @override
  String get viewList => 'List';

  @override
  String get viewColumns => 'Columns';

  @override
  String get viewAs => 'View as';

  @override
  String get hideHidden => 'Hide hidden files';

  @override
  String get showHidden => 'Show hidden files';

  @override
  String get other => 'Other...';

  @override
  String get openInNewTab => 'Open in new tab';

  @override
  String get moveToTrash => 'Move to trash';

  @override
  String get rename => 'Rename';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get copy => 'Copy';

  @override
  String get cut => 'Cut';

  @override
  String get addToSidebar => 'Add to sidebar';

  @override
  String get showInFolder => 'Show in folder';

  @override
  String get favorites => 'Favorites';

  @override
  String get removeFromSidebar => 'Remove from sidebar';

  @override
  String get places => 'Places';

  @override
  String get sidebar => 'Sidebar';

  @override
  String get back => 'Back (Alt+←)';

  @override
  String get forward => 'Forward (Alt+→)';

  @override
  String get viewIconsTip => 'Icons (Ctrl+1)';

  @override
  String get viewListTip => 'List (Ctrl+2)';

  @override
  String get viewColumnsTip => 'Columns (Ctrl+3)';

  @override
  String get newFolderTip => 'New folder (Ctrl+Shift+N)';

  @override
  String get newTabTip => 'New tab (Ctrl+T)';

  @override
  String get undoTip => 'Undo (Ctrl+Z)';

  @override
  String get sortName => 'Name';

  @override
  String get sortModified => 'Date modified';

  @override
  String get reverseOrder => 'Reverse order';

  @override
  String get foldersFirst => 'Folders first';

  @override
  String get sortBy => 'Sort by';

  @override
  String get showHiddenTip => 'Show hidden files (Ctrl+H)';

  @override
  String get actions => 'Actions';

  @override
  String get search => 'Search';

  @override
  String get expandFolder => 'Expand folder';

  @override
  String get collapseFolder => 'Collapse folder';
}
