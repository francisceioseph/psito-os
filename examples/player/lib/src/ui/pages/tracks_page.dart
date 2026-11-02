// examples/player/lib/src/ui/pages/tracks_page.dart
//
// As faixas de um artista, de um gênero ou de uma pasta. As três diferem só na arte
// e na consulta.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/models.dart';
import '../../player/playback_controller.dart';
import '../format.dart';
import '../molecules/collection_actions.dart';
import '../molecules/section_heading.dart';
import '../organisms/album_grid.dart';
import '../organisms/track_list.dart';
import '../templates/collection_template.dart';

class TracksPage extends StatefulWidget {
  final String title;
  final Widget art;
  final TrackQuery query;
  final LibraryController library;
  final PlaybackController playback;
  final VoidCallback onBack;
  final ValueChanged<Album> onOpenAlbum;

  const TracksPage({
    super.key,
    required this.title,
    required this.art,
    required this.query,
    required this.library,
    required this.playback,
    required this.onBack,
    required this.onOpenAlbum,
  });

  @override
  State<TracksPage> createState() => _TracksPageState();
}

class _TracksPageState extends State<TracksPage> {
  List<Track> _tracks = const [];
  List<Album> _albums = const [];
  int _revision = -1;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(TracksPage old) {
    super.didUpdateWidget(old);
    if (_revision != widget.library.revision) unawaited(_load());
  }

  Future<void> _load() async {
    final store = widget.library.store;
    _revision = widget.library.revision;
    final artist = widget.query.artistId;
    final (tracks, albums) = await (
      store.tracks(widget.query),
      artist == null
          ? Future.value(const <Album>[])
          : store.artistAlbums(artist),
    ).wait;
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _albums = albums;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final total = _tracks.fold(Duration.zero, (sum, t) => sum + t.duration);
    return CollectionTemplate(
      title: widget.title,
      onBack: widget.onBack,
      art: widget.art,
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (_albums.isNotEmpty) l.albumCount(_albums.length),
              l.trackCount(_tracks.length),
              formatLength(total, context),
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          CollectionActions(playback: widget.playback, tracks: _tracks),
        ],
      ),
      slivers: [
        if (_albums.isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionHeading(l.albums)),
          AlbumGrid(
            albums: _albums,
            onOpen: widget.onOpenAlbum,
            onPlay: (album) => unawaited(widget.playback.playAlbum(album.id)),
          ),
          SliverToBoxAdapter(child: SectionHeading(l.songs)),
        ],
        TrackList(
          tracks: _tracks,
          library: widget.library,
          playback: widget.playback,
          columns: true,
        ),
      ],
    );
  }
}
