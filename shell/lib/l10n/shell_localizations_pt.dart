// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'shell_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class ShellLocalizationsPt extends ShellLocalizations {
  ShellLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String transferMore(Object count) {
    return '(e mais $count)';
  }

  @override
  String get newDocumentFile => 'Novo documento.txt';

  @override
  String get shortcutBroken => 'Atalho quebrado';

  @override
  String shortcutBrokenBody(Object name) {
    return 'O programa de \"$name\" não existe mais.';
  }

  @override
  String itemCount(Object count) {
    return '$count itens';
  }

  @override
  String pasteItems(Object count) {
    return 'Colar $count itens';
  }

  @override
  String get desktop => 'Área de trabalho';

  @override
  String get notification => 'Notificação';

  @override
  String trustBody(Object name) {
    return '\"$name\" não foi marcado como confiável, e pode abrir qualquer programa.';
  }

  @override
  String closeWindows(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fechar $count janelas',
      one: 'Fechar',
    );
    return '$_temp0';
  }

  @override
  String get home => 'Pasta pessoal';

  @override
  String get trash => 'Lixeira';

  @override
  String get cantRename => 'Sem como renomear';

  @override
  String get renameAction => 'Renomear';

  @override
  String get cantCreateFolder => 'Sem como criar a pasta';

  @override
  String get cantTrash => 'Sem como mover para a lixeira';

  @override
  String get cantUndo => 'Sem como desfazer';

  @override
  String get cantPaste => 'Sem como colar';

  @override
  String get cantBringToDesk => 'Sem como trazer para a mesa';

  @override
  String get cantCreateShortcut => 'Sem como criar o atalho';

  @override
  String get cantCreateDocument => 'Sem como criar o documento';

  @override
  String get cantPreview => 'Sem como pré-visualizar';

  @override
  String get cantOpen => 'Sem como abrir';

  @override
  String get cantTrust => 'Sem como confiar no atalho';

  @override
  String get newFolder => 'Nova pasta';

  @override
  String get newDocumentEllipsis => 'Novo documento…';

  @override
  String get paste => 'Colar';

  @override
  String get undo => 'Desfazer';

  @override
  String get arrangeBy => 'Organizar por…';

  @override
  String get cleanUp => 'Limpar';

  @override
  String get openInFiles => 'Abrir no Files';

  @override
  String get openTerminalHere => 'Abrir o terminal aqui';

  @override
  String get changeWallpaper => 'Mudar o papel de parede';

  @override
  String get arrangeByTitle => 'Organizar por';

  @override
  String get sortName => 'Nome';

  @override
  String get sortKind => 'Tipo';

  @override
  String get sortDate => 'Data';

  @override
  String get sortSize => 'Tamanho';

  @override
  String get newDocument => 'Novo documento';

  @override
  String get emptyDocument => 'Documento vazio';

  @override
  String get open => 'Abrir';

  @override
  String get copy => 'Copiar';

  @override
  String get cut => 'Recortar';

  @override
  String get moveToTrash => 'Mover para a lixeira';

  @override
  String get emptyTrash => 'Esvaziar a lixeira';

  @override
  String get openWithEllipsis => 'Abrir com…';

  @override
  String get showInFiles => 'Mostrar no Files';

  @override
  String get pinToDock => 'Fixar na Dock';

  @override
  String get openWith => 'Abrir com';

  @override
  String get otherEllipsis => 'Outro…';

  @override
  String get apps => 'Apps';

  @override
  String get newWindow => 'Nova janela';

  @override
  String get openAtLogin => 'Abrir ao iniciar a sessão';

  @override
  String get hide => 'Ocultar';

  @override
  String get removeFromDock => 'Remover da Dock';

  @override
  String get keepInDock => 'Manter na Dock';

  @override
  String get createDeskShortcut => 'Criar atalho na mesa';

  @override
  String get emptyTrashQuestion => 'Esvaziar a lixeira?';

  @override
  String get emptyTrashBody => 'Os itens da lixeira serão apagados de vez.';

  @override
  String get emptyAction => 'Esvaziar';

  @override
  String get trustQuestion => 'Confiar neste atalho?';

  @override
  String get trustAndOpen => 'Confiar e abrir';

  @override
  String get polkitTitle => 'Autenticação necessária';

  @override
  String polkitPasswordOf(Object user) {
    return 'Senha de $user';
  }

  @override
  String get polkitWrongPassword => 'Senha incorreta.';

  @override
  String get polkitAuthenticate => 'Autenticar';

  @override
  String get polkitCancel => 'Cancelar';
}
