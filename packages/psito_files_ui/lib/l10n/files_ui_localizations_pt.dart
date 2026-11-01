// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'files_ui_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class FilesUiLocalizationsPt extends FilesUiLocalizations {
  FilesUiLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get fsErrorEmptyName => 'O nome não pode ficar vazio.';

  @override
  String get fsErrorSlashInName => 'O nome não pode ter \"/\".';

  @override
  String get fsErrorReservedName => 'Esse nome é reservado.';

  @override
  String get fsErrorNameTooLong => 'O nome é longo demais.';

  @override
  String fsErrorNameTaken(Object name) {
    return 'Já existe um item chamado \"$name\".';
  }

  @override
  String fsErrorIntoItself(Object name) {
    return '\"$name\" não pode ir para dentro dela mesma.';
  }

  @override
  String fsErrorReplacesParent(Object name) {
    return '\"$name\" não pode substituir a pasta em que está.';
  }

  @override
  String fsErrorSystem(Object detail, Object name) {
    return '$name: $detail';
  }

  @override
  String get fsActionRename => 'Renomear';

  @override
  String get fsActionNewFolder => 'Nova pasta';

  @override
  String get fsActionNewDocument => 'Novo documento';

  @override
  String get fsActionCreateShortcut => 'Criar atalho';

  @override
  String get fsActionTrash => 'Mover para a lixeira';

  @override
  String get fsActionCopy => 'Copiar';

  @override
  String get fsActionMove => 'Mover';

  @override
  String get fsActionDuplicate => 'Duplicar';

  @override
  String get fsActionArrange => 'Organizar';

  @override
  String get fsActionCleanUp => 'Limpar';

  @override
  String undoAction(Object action) {
    return 'Desfazer $action';
  }

  @override
  String get undo => 'Desfazer';

  @override
  String get newFolderName => 'Nova pasta';

  @override
  String get copyWord => 'cópia';

  @override
  String get jobCopying => 'Copiando';

  @override
  String get jobMoving => 'Movendo';

  @override
  String get jobDuplicating => 'Duplicando';
}
