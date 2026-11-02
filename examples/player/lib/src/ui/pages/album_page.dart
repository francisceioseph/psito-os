// examples/player/lib/src/ui/pages/album_page.dart
//
// Um álbum: capa, dados, a pasta de origem, Tocar, Aleatório e as faixas.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/models.dart';
import '../../player/engine.dart';
import '../../player/playback_controller.dart';
import '../atoms/cover_art.dart';
import '../atoms/tag_chip.dart';
import '../format.dart';
import '../molecules/track_row.dart';
import '../organisms/player_bar.dart';
import '../templates/page_template.dart';

class AlbumPage extends StatefulWidget {
  /// A partir desta largura, a capa fica ao lado dos dados.
  static const coverMinWidth = 420.0;

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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(AlbumPage old) {
    super.didUpdateWidget(old);
    if (old.album.id != widget.album.id) unawaited(_load());
  }

  Future<void> _load() async {
    final tracks = await widget.library.store.albumTracks(widget.album.id);
    if (mounted) setState(() => _tracks = tracks);
  }

  Widget _header(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final album = widget.album;
    final playback = widget.playback;
    final facts = [
      if (album.year != null) '${album.year}',
      l.trackCount(album.trackCount),
      formatLength(album.duration, context),
    ].join(' · ');
    final details = Column(
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => unawaited(playback.playTracks(_tracks)),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l.play),
            ),
            FilledButton.tonalIcon(
              onPressed: () => unawaited(playback.shuffleTracks(_tracks)),
              icon: const Icon(Icons.shuffle_rounded),
              label: Text(l.shuffle),
            ),
            IconButton.outlined(
              tooltip: l.addToQueue,
              icon: const Icon(Icons.playlist_add_rounded),
              onPressed: () => unawaited(playback.albumToQueue(album.id)),
            ),
          ],
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AlbumPage.coverMinWidth) return details;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(
              path: album.coverPath,
              seed: '${album.title}|${album.artist}',
              size: 180,
            ),
            const SizedBox(width: 20),
            Expanded(child: details),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final playback = widget.playback;
    return PageTemplate(
      title: widget.album.title,
      back: TextButton.icon(
        onPressed: widget.onBack,
        icon: const Icon(Icons.arrow_back_rounded),
        label: Text(l.albums),
      ),
      slivers: [
        SliverToBoxAdapter(child: _header(context)),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ValueListenableBuilder<PlayerState>(
          valueListenable: playback.engine.state,
          builder: (context, s, _) {
            final current = playback.current?.path;
            return SliverList.builder(
              itemCount: _tracks.length,
              itemBuilder: (context, i) {
                final track = _tracks[i];
                final playing = track.path == current;
                return TrackRow(
                  track: track,
                  current: playing,
                  leading: playing
                      ? const Icon(Icons.equalizer_rounded)
                      : Text('${track.trackNumber ?? i + 1}'),
                  menu: (context) => trackMenu(context, playback, track),
                  onTap: () =>
                      unawaited(playback.playTracks(_tracks, index: i)),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
