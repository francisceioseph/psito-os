// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'files_ui_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class FilesUiLocalizationsEn extends FilesUiLocalizations {
  FilesUiLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get fsErrorEmptyName => 'The name can\'t be empty.';

  @override
  String get fsErrorSlashInName => 'The name can\'t contain \"/\".';

  @override
  String get fsErrorReservedName => 'That name is reserved.';

  @override
  String get fsErrorNameTooLong => 'The name is too long.';

  @override
  String fsErrorNameTaken(Object name) {
    return 'An item named \"$name\" already exists.';
  }

  @override
  String fsErrorIntoItself(Object name) {
    return '\"$name\" can\'t go inside itself.';
  }

  @override
  String fsErrorReplacesParent(Object name) {
    return '\"$name\" can\'t replace the folder it\'s in.';
  }

  @override
  String fsErrorSystem(Object detail, Object name) {
    return '$name: $detail';
  }

  @override
  String get fsActionRename => 'Rename';

  @override
  String get fsActionNewFolder => 'New folder';

  @override
  String get fsActionNewDocument => 'New document';

  @override
  String get fsActionCreateShortcut => 'Create shortcut';

  @override
  String get fsActionTrash => 'Move to trash';

  @override
  String get fsActionCopy => 'Copy';

  @override
  String get fsActionMove => 'Move';

  @override
  String get fsActionDuplicate => 'Duplicate';

  @override
  String get fsActionArrange => 'Arrange';

  @override
  String get fsActionCleanUp => 'Clean up';

  @override
  String undoAction(Object action) {
    return 'Undo $action';
  }

  @override
  String get undo => 'Undo';

  @override
  String get newFolderName => 'New folder';

  @override
  String get copyWord => 'copy';

  @override
  String get jobCopying => 'Copying';

  @override
  String get jobMoving => 'Moving';

  @override
  String get jobDuplicating => 'Duplicating';
}
