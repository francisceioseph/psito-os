// examples/player/lib/src/ui/organisms/cover_panel.dart
//
// A aba Capa: a capa grande e o que se sabe do arquivo.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/library_store.dart';
import '../../library/models.dart';
import '../atoms/cover_art.dart';

class CoverPanel extends StatefulWidget {
  final Track track;
  final LibraryStore store;

  const CoverPanel({super.key, required this.track, required this.store});

  @override
  State<CoverPanel> createState() => _CoverPanelState();
}

class _CoverPanelState extends State<CoverPanel> {
  TrackDetails? _details;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(CoverPanel old) {
    super.didUpdateWidget(old);
    if (old.track.path != widget.track.path) unawaited(_load());
  }

  Future<void> _load() async {
    final path = widget.track.path;
    final details = await widget.store.trackDetails(path);
    if (!mounted || widget.track.path != path) return;
    setState(() => _details = details);
  }

  String _file(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final kilo = NumberFormat('#,##0.#', locale);
    final details = _details;
    final rate = details?.sampleRate;
    final bitrate = details?.bitrate;
    return [
      if (widget.track.format.isNotEmpty) widget.track.format,
      if (rate != null && rate > 0) '${kilo.format(rate / 1000)} kHz',
      if (bitrate != null && bitrate > 0) '${(bitrate / 1000).round()} kbps',
    ].join(' · ');
  }

  String _cover(BuildContext context) {
    final l = context.l10n;
    return switch (_details?.coverSource) {
      null => l.coverGenerated,
      'embedded' => l.coverEmbedded,
      final file => file,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final track = widget.track;
    final genre = track.genre?.trim() ?? '';
    final rows = [
      if (track.album.isNotEmpty)
        (
          l.detailAlbum,
          track.year == null ? track.album : '${track.album} · ${track.year}',
        ),
      if (genre.isNotEmpty) (l.detailGenre, genre),
      (l.detailFile, _file(context)),
      (l.detailCover, _cover(context)),
      (
        l.detailFolder,
        prettyPath(p.dirname(track.path), Platform.environment['HOME']),
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: CoverArt(
              path: track.coverPath,
              seed: '${track.album}|${track.artist}',
            ),
          ),
          const SizedBox(height: 12),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(value, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
