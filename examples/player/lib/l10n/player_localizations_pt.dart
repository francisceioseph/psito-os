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
  String openFailed(Object error) {
    return 'Não foi possível tocar este arquivo: $error';
  }

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
}
