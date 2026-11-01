// packages/psito_files_ui/lib/src/fs_text.dart
//
// O texto dos erros e das ações do psito_fs, que não fala língua nenhuma.
import 'package:psito_fs/psito_fs.dart';

import '../l10n/files_ui_localizations.dart';

extension FsText on FilesUiLocalizations {
  String fsError(FsError e) => switch (e.kind) {
    FsErrorKind.system =>
      e.name.isEmpty ? e.detail : fsErrorSystem(e.detail, e.name),
    FsErrorKind.emptyName => fsErrorEmptyName,
    FsErrorKind.slashInName => fsErrorSlashInName,
    FsErrorKind.reservedName => fsErrorReservedName,
    FsErrorKind.nameTooLong => fsErrorNameTooLong,
    FsErrorKind.nameTaken => fsErrorNameTaken(e.name),
    FsErrorKind.intoItself => fsErrorIntoItself(e.name),
    FsErrorKind.replacesParent => fsErrorReplacesParent(e.name),
  };

  String fsErrors(Iterable<FsError> errors) => errors.map(fsError).join('\n');

  String fsAction(FsAction action) => switch (action) {
    FsAction.rename => fsActionRename,
    FsAction.newFolder => fsActionNewFolder,
    FsAction.newDocument => fsActionNewDocument,
    FsAction.createShortcut => fsActionCreateShortcut,
    FsAction.trash => fsActionTrash,
    FsAction.copy => fsActionCopy,
    FsAction.move => fsActionMove,
    FsAction.duplicate => fsActionDuplicate,
    FsAction.arrange => fsActionArrange,
    FsAction.cleanUp => fsActionCleanUp,
  };

  String jobLabel(JobKind kind) => switch (kind) {
    JobKind.copy => jobCopying,
    JobKind.move => jobMoving,
    JobKind.duplicate => jobDuplicating,
  };
}
