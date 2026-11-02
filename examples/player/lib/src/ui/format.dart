// examples/player/lib/src/ui/format.dart
//
// Tempo e tamanho como aparecem na tela.
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../library/models.dart';

/// `3:07`, ou `1:02:07` a partir de uma hora.
String formatDuration(Duration d, Locale locale) {
  final minutes = NumberFormat('00', locale.toLanguageTag());
  final seconds = minutes.format(d.inSeconds % 60);
  if (d.inHours == 0) return '${d.inMinutes}:$seconds';
  return '${d.inHours}:${minutes.format(d.inMinutes % 60)}:$seconds';
}

/// `41 min`, `2 h 5 min` ou `4 dias e 2 h`.
String formatLength(Duration d, BuildContext context) {
  final l = context.l10n;
  if (d.inHours == 0) return l.lengthMinutes(d.inMinutes);
  if (d.inDays == 0) return l.lengthHours(d.inHours, d.inMinutes % 60);
  return l.lengthDays(d.inDays, d.inHours % 24);
}

/// `96 GB`, `2,1 GB`, `340 MB`.
String formatSize(int bytes, Locale locale) {
  const mb = 1000 * 1000;
  const gb = 1000 * mb;
  final number = NumberFormat('#,##0.#', locale.toLanguageTag());
  if (bytes >= 10 * gb) return '${(bytes / gb).round()} GB';
  if (bytes >= gb) return '${number.format(bytes / gb)} GB';
  return '${(bytes / mb).ceil()} MB';
}

/// O nome que aparece no lugar de um artista que a tag não diz.
String artistName(String artist, BuildContext context) =>
    artist.isEmpty ? context.l10n.unknownArtist : artist;

String genreName(String genre, BuildContext context) =>
    genre.isEmpty ? context.l10n.noGenre : genre;

/// As automáticas têm o nome na tela, traduzido.
String playlistName(Playlist playlist, BuildContext context) {
  final l = context.l10n;
  return switch (playlist.kind) {
    PlaylistKind.manual => playlist.name,
    PlaylistKind.favorites => l.autoFavorites,
    PlaylistKind.mostPlayed => l.autoMostPlayed,
    PlaylistKind.recentlyAdded => l.autoRecent,
  };
}
