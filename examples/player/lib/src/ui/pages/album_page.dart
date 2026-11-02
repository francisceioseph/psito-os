// examples/player/lib/src/ui/pages/album_page.dart
//
// Um álbum: capa, dados, a pasta de origem, Tocar, Aleatório e as faixas.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/models.dart';
import '../../player/playback_controller.dart';
import '../atoms/cover_art.dart';
import '../atoms/tag_chip.dart';
import '../format.dart';
import '../molecules/collection_actions.dart';
import '../organisms/track_list.dart';
import '../templates/collection_template.dart';

class AlbumPage extends StatefulWidget {
  final Album album;
  final LibraryController library;
  final PlaybackController playback;
  final VoidCallback onBack;

  const AlbumPage({
    super.key,
    required this.album,
    required this.library,
    required this.playback,
    required this.onBack,
  });

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  List<Track> _tracks = const [];
  int _revision = -1;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(AlbumPage old) {
    super.didUpdateWidget(old);
    if (old.album.id != widget.album.id ||
        _revision != widget.library.revision) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    _revision = widget.library.revision;
    final tracks = await widget.library.store.albumTracks(widget.album.id);
    if (mounted) setState(() => _tracks = tracks);
  }

  Widget _details(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final album = widget.album;
    final facts = [
      if (album.year != null) '${album.year}',
      l.trackCount(album.trackCount),
      formatLength(album.duration, context),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          artistName(album.artist, context),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        Text(facts, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final format in album.formats)
              TagChip(label: format, icon: Icons.graphic_eq_rounded),
            TagChip(
              label: prettyPath(album.folder, Platform.environment['HOME']),
              icon: Icons.folder_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        CollectionActions(playback: widget.playback, tracks: _tracks),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    return CollectionTemplate(
      title: album.title,
      onBack: widget.onBack,
      art: CoverArt(
        path: album.coverPath,
        seed: '${album.title}|${album.artist}',
      ),
      details: _details(context),
      slivers: [
        TrackList(
          tracks: _tracks,
          library: widget.library,
          playback: widget.playback,
          numbered: true,
        ),
      ],
    );
  }
}
