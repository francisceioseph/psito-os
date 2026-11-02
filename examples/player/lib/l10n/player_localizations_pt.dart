// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'player_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class PlayerLocalizationsPt extends PlayerLocalizations {
  PlayerLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Player de música';

  @override
  String get noTrack => 'Nenhuma faixa';

  @override
  String get play => 'Tocar';

  @override
  String get pause => 'Pausar';

  @override
  String get progress => 'Progresso';

  @override
  String get volume => 'Volume';

  @override
  String get home => 'Início';

  @override
  String get library => 'Biblioteca';

  @override
  String get playlists => 'Playlists';

  @override
  String get folders => 'Pastas';

  @override
  String get search => 'Buscar';

  @override
  String get settings => 'Ajustes';

  @override
  String engineUnavailable(Object error) {
    return 'O motor de áudio não está disponível: $error';
  }

  @override
  String get openFailed => 'Não foi possível tocar este arquivo';

  @override
  String get addFolder => 'Adicionar pasta';

  @override
  String get addMusicFolder => 'Adicionar pasta de músicas';

  @override
  String get folderNotVisible =>
      'O player não enxerga esta pasta. Escolha uma no seu home ou num disco externo.';

  @override
  String get folderAlreadyAdded => 'Esta pasta já está na biblioteca.';

  @override
  String libraryUnavailable(String error) {
    return 'Não foi possível abrir a biblioteca: $error';
  }

  @override
  String get albums => 'Álbuns';

  @override
  String get unknownArtist => 'Artista desconhecido';

  @override
  String playAlbum(String album) {
    return 'Tocar $album';
  }

  @override
  String get hasLyrics => 'Tem letra';

  @override
  String get moreOptions => 'Mais opções';

  @override
  String get playNext => 'Tocar a seguir';

  @override
  String get addToQueue => 'Adicionar à fila';

  @override
  String get removeFromQueue => 'Tirar da fila';

  @override
  String get queue => 'Fila';

  @override
  String get queueEmpty => 'A fila está vazia';

  @override
  String get close => 'Fechar';

  @override
  String get shuffle => 'Aleatório';

  @override
  String get previousTrack => 'Faixa anterior';

  @override
  String get nextTrack => 'Próxima faixa';

  @override
  String get repeatOff => 'Repetir: desligado';

  @override
  String get repeatAll => 'Repetir: tudo';

  @override
  String get repeatOne => 'Repetir: esta faixa';

  @override
  String get homeSubtitle => 'Sua biblioteca local, do jeito que você deixou';

  @override
  String get continueListening => 'Continuar de onde parou';

  @override
  String get continuePlaying => 'Continuar';

  @override
  String stoppedAt(String artist, String position, String duration) {
    return '$artist · parou em $position de $duration';
  }

  @override
  String get shuffleAll => 'Tudo em aleatório';

  @override
  String get recentlyAdded => 'Adicionados recentemente';

  @override
  String get seeAll => 'Ver tudo';

  @override
  String get mostPlayed => 'Mais tocadas';

  @override
  String get comingSoon => 'Esta tela chega numa próxima fase.';

  @override
  String get emptyTitle => 'Sua biblioteca está vazia';

  @override
  String get emptyBody =>
      'Aponte para a pasta onde ficam suas músicas. O player lê os arquivos direto do seu computador e não envia nada para fora.';

  @override
  String useFolder(String folder) {
    return 'Usar $folder';
  }

  @override
  String get acceptedFormats => 'Formatos aceitos';

  @override
  String get scanning => 'Lendo sua biblioteca';

  @override
  String get scanSubtitle =>
      'Leitura em andamento: você já pode ouvir o que foi encontrado';

  @override
  String scanFiles(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString de $totalString arquivos';
  }

  @override
  String get scanLessThanMinute => 'menos de 1 min restante';

  @override
  String scanMinutesLeft(int n) {
    return 'cerca de $n min restantes';
  }

  @override
  String get pauseScan => 'Pausar';

  @override
  String get resumeScan => 'Continuar';

  @override
  String get cancelScan => 'Cancelar';

  @override
  String get scanKeepsGoing => 'A leitura continua se você fechar esta tela';

  @override
  String get foundSoFar => 'Encontrados até agora';

  @override
  String get updateAll => 'Atualizar tudo';

  @override
  String get updateFolder => 'Atualizar pasta';

  @override
  String get removeFolder => 'Remover da biblioteca';

  @override
  String get folderMissing => 'Disco não encontrado';

  @override
  String get notScanned => 'Ainda não lida';

  @override
  String get scannedJustNow => 'Atualizada agora';

  @override
  String scannedMinutes(int n) {
    return 'Atualizada há $n min';
  }

  @override
  String scannedHours(int n) {
    return 'Atualizada há $n h';
  }

  @override
  String scannedDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Atualizada há $n dias',
      one: 'Atualizada ontem',
      zero: 'Atualizada hoje',
    );
    return '$_temp0';
  }

  @override
  String lengthMinutes(int n) {
    return '$n min';
  }

  @override
  String lengthHours(int h, int m) {
    return '$h h $m min';
  }

  @override
  String albumCount(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString álbuns',
      one: '1 álbum',
      zero: '0 álbum',
    );
    return '$_temp0';
  }

  @override
  String trackCount(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString músicas',
      one: '1 música',
      zero: '0 música',
    );
    return '$_temp0';
  }

  @override
  String folderCount(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString pastas',
      one: '1 pasta',
      zero: '0 pasta',
    );
    return '$_temp0';
  }

  @override
  String coversFound(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString capas encontradas',
      one: '1 capa encontrada',
      zero: '0 capa encontrada',
    );
    return '$_temp0';
  }

  @override
  String filesSkipped(int n) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);

    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$nString arquivos ignorados',
      one: '1 arquivo ignorado',
      zero: '0 arquivo ignorado',
    );
    return '$_temp0';
  }

  @override
  String get back => 'Voltar';

  @override
  String get songs => 'Músicas';

  @override
  String get artists => 'Artistas';

  @override
  String get genres => 'Gêneros';

  @override
  String get allFilter => 'Tudo';

  @override
  String get allSongs => 'Todas';

  @override
  String get favorites => 'Favoritas';

  @override
  String get mineFilter => 'Minhas';

  @override
  String get automaticFilter => 'Automáticas';

  @override
  String get addFavorite => 'Marcar como favorita';

  @override
  String get removeFavorite => 'Tirar das favoritas';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get sortRecent => 'Recentes';

  @override
  String get sortAZ => 'A a Z';

  @override
  String get sortArtist => 'Artista';

  @override
  String get sortYear => 'Ano';

  @override
  String get sortMostTracks => 'Mais músicas';

  @override
  String get columnTitle => 'Título';

  @override
  String get columnAlbum => 'Álbum';

  @override
  String get columnDuration => 'Duração';

  @override
  String get columnFormat => 'Formato';

  @override
  String get viewGrid => 'Grade';

  @override
  String get viewList => 'Lista';

  @override
  String get searchHint => 'Buscar na biblioteca';

  @override
  String get searchSongsHint => 'Buscar músicas';

  @override
  String get searchArtistsHint => 'Buscar artistas';

  @override
  String get searchGenresHint => 'Buscar gêneros';

  @override
  String get searchAlbumsHint => 'Buscar álbuns';

  @override
  String get searchFoldersHint => 'Buscar pastas';

  @override
  String get searchAllHint => 'Músicas, álbuns, artistas ou pastas';

  @override
  String get searchShortcut => 'Ctrl K';

  @override
  String get clearSearch => 'Limpar a busca';

  @override
  String noResults(String query) {
    return 'Nada encontrado para \"$query\"';
  }

  @override
  String get searchPrompt => 'Digite para buscar na sua biblioteca.';

  @override
  String get bestResult => 'Melhor resultado';

  @override
  String get playAll => 'Tocar tudo';

  @override
  String get kindArtist => 'Artista';

  @override
  String get kindAlbum => 'Álbum';

  @override
  String get kindSong => 'Música';

  @override
  String get nothingHere => 'Nada por aqui ainda.';

  @override
  String get noGenre => 'Sem gênero';

  @override
  String get fileUnavailable => 'Este arquivo não está disponível agora';

  @override
  String get nothingAvailable =>
      'Estas músicas não estão disponíveis. O disco está ligado?';

  @override
  String get watchFolders => 'Observar mudanças nas pastas';

  @override
  String get watchFoldersBody =>
      'Detecta arquivos novos, alterados e removidos enquanto o player está aberto.';

  @override
  String get newPlaylist => 'Nova playlist';

  @override
  String get importM3u => 'Importar M3U';

  @override
  String get exportM3u => 'Exportar M3U';

  @override
  String get renamePlaylist => 'Renomear';

  @override
  String get deletePlaylist => 'Excluir playlist';

  @override
  String deletePlaylistBody(String name) {
    return 'Excluir \"$name\"? Os arquivos de música continuam onde estão.';
  }

  @override
  String get delete => 'Excluir';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Salvar';

  @override
  String get create => 'Criar';

  @override
  String get playlistName => 'Nome da playlist';

  @override
  String get addToPlaylist => 'Adicionar à playlist';

  @override
  String get removeFromPlaylist => 'Tirar da playlist';

  @override
  String get moveUp => 'Mover para cima';

  @override
  String get moveDown => 'Mover para baixo';

  @override
  String get dragToReorder => 'Arrastar para reordenar';

  @override
  String get autoFavorites => 'Favoritas';

  @override
  String get autoMostPlayed => 'Mais tocadas';

  @override
  String get autoRecent => 'Adicionadas recentemente';

  @override
  String get automaticSuffix => 'automática';

  @override
  String exportFailed(String error) {
    return 'Não foi possível gravar o arquivo: $error';
  }

  @override
  String importFailed(String error) {
    return 'Não foi possível ler o arquivo: $error';
  }

  @override
  String lengthDays(int d, int h) {
    return '$d dias e $h h';
  }

  @override
  String artistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n artistas',
      one: '1 artista',
      zero: '0 artista',
    );
    return '$_temp0';
  }

  @override
  String genreCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n gêneros',
      one: '1 gênero',
      zero: '0 gênero',
    );
    return '$_temp0';
  }

  @override
  String playlistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n playlists',
      one: '1 playlist',
      zero: '0 playlist',
    );
    return '$_temp0';
  }

  @override
  String fileCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n arquivos',
      one: '1 arquivo',
      zero: '0 arquivo',
    );
    return '$_temp0';
  }

  @override
  String folderChanges(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n alterações',
      one: '1 alteração',
      zero: '0 alteração',
    );
    return '$_temp0';
  }

  @override
  String imported(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n músicas importadas',
      one: '1 música importada',
      zero: '0 música importada',
    );
    return '$_temp0';
  }

  @override
  String importedRemote(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n endereços da rede ignorados',
      one: '1 endereço da rede ignorado',
      zero: '0 endereço da rede ignorado',
    );
    return '$_temp0';
  }

  @override
  String get lyricsTab => 'Letra';

  @override
  String get coverTab => 'Capa';

  @override
  String get noLyrics => 'Esta faixa não tem letra';

  @override
  String get lyricsSynced => 'sincronizada';

  @override
  String get lyricsUnsynced => 'sem tempo';

  @override
  String get lyricsEmbedded => 'Nas tags';

  @override
  String get lyricsTiming => 'Ajustar o tempo da letra';

  @override
  String get lyricsEarlier => 'Adiantar a letra';

  @override
  String get lyricsLater => 'Atrasar a letra';

  @override
  String get lyricsResetTiming => 'Zerar o ajuste';

  @override
  String get withLyrics => 'Com letra';

  @override
  String get upNext => 'A seguir';

  @override
  String get clearQueue => 'Limpar';

  @override
  String get saveAsPlaylist => 'Salvar como playlist';

  @override
  String get detailAlbum => 'Álbum';

  @override
  String get detailGenre => 'Gênero';

  @override
  String get detailFile => 'Arquivo';

  @override
  String get detailCover => 'Capa';

  @override
  String get detailFolder => 'Pasta';

  @override
  String get coverEmbedded => 'Embutida';

  @override
  String get coverGenerated => 'Gerada';

  @override
  String secondsOffset(String value) {
    return '$value s';
  }

  @override
  String playlistSaved(String name) {
    return 'Salva como “$name”';
  }
}
