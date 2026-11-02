// examples/player/lib/src/ui/organisms/card_grids.dart
//
// As grades de artistas, playlists e gêneros, na mesma medida da de álbuns.
import 'package:flutter/material.dart';

import '../../library/models.dart';
import '../molecules/album_card.dart';
import '../molecules/artist_card.dart';
import '../molecules/genre_card.dart';
import '../molecules/playlist_card.dart';
import 'album_grid.dart';

class ArtistGrid extends StatelessWidget {
  final List<Artist> artists;
  final ValueChanged<Artist> onOpen;

  const ArtistGrid({super.key, required this.artists, required this.onOpen});

  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate: const CardGridDelegate(AlbumCard.textHeight),
    itemCount: artists.length,
    itemBuilder: (context, i) => ArtistCard(
      key: ValueKey(artists[i].id),
      artist: artists[i],
      onOpen: () => onOpen(artists[i]),
    ),
  );
}

class PlaylistGrid extends StatelessWidget {
  final List<Playlist> playlists;
  final ValueChanged<Playlist> onOpen;

  const PlaylistGrid({
    super.key,
    required this.playlists,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate: const CardGridDelegate(AlbumCard.textHeight),
    itemCount: playlists.length,
    itemBuilder: (context, i) => PlaylistCard(
      key: ValueKey('${playlists[i].kind.name}${playlists[i].id}'),
      playlist: playlists[i],
      onOpen: () => onOpen(playlists[i]),
    ),
  );
}

class GenreGrid extends StatelessWidget {
  final List<Genre> genres;
  final ValueChanged<Genre> onOpen;

  const GenreGrid({super.key, required this.genres, required this.onOpen});

  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 280,
      mainAxisExtent: 96,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
    ),
    itemCount: genres.length,
    itemBuilder: (context, i) => GenreCard(
      key: ValueKey(genres[i].name),
      genre: genres[i],
      onOpen: () => onOpen(genres[i]),
    ),
  );
}
