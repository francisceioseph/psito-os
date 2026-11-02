// examples/player/lib/src/ui/molecules/seek_bar.dart
//
// O progresso da faixa. O motor só fica sabendo ao soltar.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../format.dart';

class SeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  /// Abaixo disto, os tempos saem.
  static const timesMinWidth = 200.0;

  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final seconds = widget.duration.inMilliseconds / 1000;
    final position = (_dragging ?? widget.position.inMilliseconds / 1000)
        .clamp(0, seconds > 0 ? seconds : 0)
        .toDouble();
    final elapsed = Duration(milliseconds: (position * 1000).round());
    Widget time(Duration value) => Text(
      formatDuration(value, locale),
      maxLines: 1,
      style: theme.textTheme.labelSmall,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final times = constraints.maxWidth >= SeekBar.timesMinWidth;
        return Row(
          children: [
            if (times) time(elapsed),
            Expanded(
              child: SizedBox(
                height: 20,
                child: Semantics(
                  label: context.l10n.progress,
                  child: Slider(
                    value: position,
                    max: seconds > 0 ? seconds : 1,
                    onChanged: seconds > 0
                        ? (v) => setState(() => _dragging = v)
                        : null,
                    onChangeEnd: (v) {
                      setState(() => _dragging = null);
                      unawaited(
                        Future.sync(
                          () => widget.onSeek(
                            Duration(milliseconds: (v * 1000).round()),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (times) time(widget.duration),
          ],
        );
      },
    );
  }
}
