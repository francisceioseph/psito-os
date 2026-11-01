// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'files_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class FilesLocalizationsPt extends FilesLocalizations {
  FilesLocalizationsPt([String locale = 'pt']) : super(locale);

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
    return 'Hoje, $time';
  }

  @override
  String dateYesterday(Object time) {
    return 'Ontem, $time';
  }

  @override
  String dateFull(Object date, Object time) {
    return '$date, $time';
  }

  @override
  String get placeHome => 'Início';

  @override
  String get placeComputer => 'Computador';

  @override
  String get placeTrash => 'Lixeira';

  @override
  String get kindFolder => 'Pasta';

  @override
  String get openFromTrash => 'Para abrir, ponha o item de volta primeiro.';

  @override
  String deleteForeverOne(Object name) {
    return 'Apagar \"$name\" para sempre?';
  }

  @override
  String deleteForeverMany(Object count) {
    return 'Apagar $count itens para sempre?';
  }

  @override
  String get cannotUndo => 'Não dá para desfazer.';

  @override
  String get delete => 'Apagar';

  @override
  String get emptyTrashQuestion => 'Apagar tudo o que está na lixeira?';

  @override
  String get empty => 'Esvaziar';

  @override
  String setDefaultFailed(Object detail) {
    return 'Não foi possível mudar o app padrão ($detail)';
  }

  @override
  String searchingFor(Object query) {
    return 'Buscando \"$query\"';
  }

  @override
  String get errorFolderGone => 'A pasta não existe mais.';

  @override
  String get errorNoPermission => 'Sem permissão para abrir.';

  @override
  String get errorNotAFolder => 'Não é uma pasta.';

  @override
  String jobAmount(Object done, Object total) {
    return '($done de $total)';
  }

  @override
  String itemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String itemsSelected(num count, Object selected) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$selected de $_temp0 selecionados';
  }

  @override
  String statusSearching(Object text) {
    return '$text, buscando...';
  }

  @override
  String undoTooltip(Object action) {
    return 'Desfazer $action (Ctrl+Z)';
  }

  @override
  String get emptyTrashFolder => 'A lixeira está vazia.';

  @override
  String get searching => 'Buscando...';

  @override
  String get nothingFound => 'Nada encontrado.';

  @override
  String get emptyFolder => 'Esta pasta está vazia.';

  @override
  String get paste => 'Colar';

  @override
  String pasteItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Colar $count itens',
      one: 'Colar 1 item',
    );
    return '$_temp0';
  }

  @override
  String modifiedAt(Object date) {
    return 'Modificado: $date';
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
      other: '$count itens',
      one: '1 item',
    );
    return '$size, $_temp0';
  }

  @override
  String conflictExists(Object folder, Object name) {
    return 'Já existe um item chamado \"$name\" em \"$folder\".';
  }

  @override
  String appDefault(Object app) {
    return '$app (padrão)';
  }

  @override
  String alwaysOpenWith(Object kind) {
    return 'Sempre abrir \"$kind\" com ele';
  }

  @override
  String get open => 'Abrir';

  @override
  String get calculating => 'Calculando...';

  @override
  String get kind => 'Tipo';

  @override
  String get size => 'Tamanho';

  @override
  String get wherefrom => 'Saiu de';

  @override
  String get where => 'Onde';

  @override
  String get pointsTo => 'Aponta para';

  @override
  String get deletedAt => 'Apagado em';

  @override
  String get modified => 'Modificado';

  @override
  String get accessed => 'Acessado';

  @override
  String get permissions => 'Permissões';

  @override
  String get openWith => 'Abrir com';

  @override
  String get noApp => 'Nenhum app';

  @override
  String get close => 'Fechar';

  @override
  String get conflictFolderHint =>
      'Substituir troca a pasta inteira, com o que tiver dentro.';

  @override
  String get conflictFileHint => 'Substituir apaga o que está lá.';

  @override
  String get applyToNext => 'Fazer o mesmo com os próximos';

  @override
  String get skip => 'Pular';

  @override
  String get keepBoth => 'Manter os dois';

  @override
  String get replace => 'Substituir';

  @override
  String get noAppTakesFiles => 'Nenhum app recebe arquivos.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get emptyTrashEllipsis => 'Esvaziar a lixeira...';

  @override
  String get restore => 'Pôr de volta';

  @override
  String get deleteNow => 'Apagar imediatamente...';

  @override
  String get preview => 'Pré-visualizar';

  @override
  String get keySpace => 'Espaço';

  @override
  String get getInfo => 'Obter informações';

  @override
  String get newFolder => 'Nova pasta';

  @override
  String get viewIcons => 'Ícones';

  @override
  String get viewList => 'Lista';

  @override
  String get viewColumns => 'Colunas';

  @override
  String get viewAs => 'Ver como';

  @override
  String get hideHidden => 'Esconder ocultos';

  @override
  String get showHidden => 'Mostrar ocultos';

  @override
  String get other => 'Outro...';

  @override
  String get openInNewTab => 'Abrir em nova aba';

  @override
  String get moveToTrash => 'Mover para a lixeira';

  @override
  String get rename => 'Renomear';

  @override
  String get duplicate => 'Duplicar';

  @override
  String get copy => 'Copiar';

  @override
  String get cut => 'Recortar';

  @override
  String get addToSidebar => 'Adicionar à barra lateral';

  @override
  String get showInFolder => 'Mostrar na pasta';

  @override
  String get favorites => 'Favoritos';

  @override
  String get removeFromSidebar => 'Remover da barra lateral';

  @override
  String get places => 'Locais';

  @override
  String get sidebar => 'Barra lateral';

  @override
  String get back => 'Voltar (Alt+←)';

  @override
  String get forward => 'Avançar (Alt+→)';

  @override
  String get viewIconsTip => 'Ícones (Ctrl+1)';

  @override
  String get viewListTip => 'Lista (Ctrl+2)';

  @override
  String get viewColumnsTip => 'Colunas (Ctrl+3)';

  @override
  String get newFolderTip => 'Nova pasta (Ctrl+Shift+N)';

  @override
  String get newTabTip => 'Nova aba (Ctrl+T)';

  @override
  String get undoTip => 'Desfazer (Ctrl+Z)';

  @override
  String get sortName => 'Nome';

  @override
  String get sortModified => 'Data de modificação';

  @override
  String get reverseOrder => 'Ordem inversa';

  @override
  String get foldersFirst => 'Pastas primeiro';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get showHiddenTip => 'Mostrar ocultos (Ctrl+H)';

  @override
  String get actions => 'Ações';

  @override
  String get search => 'Buscar';
}
