// examples/player/lib/src/ui/molecules/album_card.dart
//
// Um álbum numa grade: capa, título e artista. Tocar aparece ao passar o ponteiro
// ou com o foco.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/models.dart';
import '../atoms/cover_art.dart';
import '../format.dart';

class AlbumCard extends StatefulWidget {
  /// O que os textos ocupam abaixo da capa, para a grade reservar.
  static const textHeight = 44.0;

  final Album album;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  const AlbumCard({
    super.key,
    required this.album,
    required this.onOpen,
    required this.onPlay,
  });

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final album = widget.album;
    final artist = artistName(album.artist, context);
    final detail = album.year == null ? artist : '$artist · ${album.year}';
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: '${album.title}, $artist',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.onOpen,
                onFocusChange: (v) => setState(() => _focused = v),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CoverArt(
                        path: album.coverPath,
                        seed: '${album.title}|${album.artist}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_hovered || _focused)
            Positioned(
              right: 8,
              bottom: AlbumCard.textHeight + 8,
              child: IconButton.filled(
                tooltip: l.playAlbum(album.title),
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: widget.onPlay,
              ),
            ),
        ],
      ),
    );
  }
}
