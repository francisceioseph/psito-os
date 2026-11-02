// examples/player/lib/src/player/player_bar.dart
//
// A barra do player: faixa, tocar, progresso e volume. A forma final, com capa
// e fila, vem na Fase 1.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/player_localizations.dart';
import 'engine.dart';

/// `3:07`, ou `1:02:07` a partir de uma hora.
String formatDuration(Duration d, Locale locale) {
  final minutes = NumberFormat('00', locale.toLanguageTag());
  final seconds = minutes.format(d.inSeconds % 60);
  if (d.inHours == 0) return '${d.inMinutes}:$seconds';
  return '${d.inHours}:${minutes.format(d.inMinutes % 60)}:$seconds';
}

class PlayerBar extends StatefulWidget {
  final PlayerEngine engine;

  /// Abaixo desta largura, o volume sai da barra.
  static const volumeMinWidth = 360.0;

  const PlayerBar({super.key, required this.engine});

  @override
  State<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  /// A posição enquanto arrastam a barra, que o motor não sabe ainda.
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final l = PlayerLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final engine = widget.engine;
    return ValueListenableBuilder(
      valueListenable: engine.state,
      builder: (context, s, _) {
        final seconds = s.duration.inMilliseconds / 1000;
        final position = (_dragging ?? s.position.inMilliseconds / 1000)
            .clamp(0, seconds)
            .toDouble();
        final elapsed = Duration(milliseconds: (position * 1000).round());
        return Material(
          color: theme.colorScheme.surfaceContainerHigh,
          child: LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton.filled(
                    tooltip: s.playing ? l.pause : l.play,
                    icon: Icon(
                      s.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    onPressed: s.title == null ? null : engine.playOrPause,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.error == null
                              ? s.title ?? l.noTrack
                              : l.openFailed(s.error!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          '${formatDuration(elapsed, locale)}'
                          ' / ${formatDuration(s.duration, locale)}'
                          '${s.format == null ? '' : '  ${s.format}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        SizedBox(
                          height: 20,
                          child: Semantics(
                            label: l.progress,
                            child: Slider(
                              value: position,
                              max: seconds > 0 ? seconds : 1,
                              onChanged: seconds > 0
                                  ? (v) => setState(() => _dragging = v)
                                  : null,
                              onChangeEnd: (v) {
                                setState(() => _dragging = null);
                                unawaited(
                                  engine.seek(
                                    Duration(milliseconds: (v * 1000).round()),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (constraints.maxWidth >= PlayerBar.volumeMinWidth)
                    SizedBox(
                      width: 120,
                      child: Semantics(
                        label: l.volume,
                        child: Slider(
                          value: s.volume.clamp(0, 1),
                          onChanged: engine.setVolume,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
