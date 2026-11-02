// examples/player/lib/src/ui/organisms/lyrics_view.dart
//
// A aba Letra: a linha da vez grande e centralizada, as vizinhas médias e as outras
// discretas. Clicar pula, e rolar com o mouse segura a rolagem por alguns segundos.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../../lyrics/lyrics.dart';
import '../../lyrics/lyrics_controller.dart';
import '../atoms/empty_note.dart';
import '../atoms/tag_chip.dart';

class LyricsView extends StatefulWidget {
  /// Abaixo desta altura, o selo sai.
  static const footerMinHeight = 180.0;

  /// Quanto a rolagem automática espera depois de a pessoa rolar.
  static const holdAfterScroll = Duration(seconds: 4);

  final LyricsController controller;

  const LyricsView({super.key, required this.controller});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  bool _timing = false;

  Widget _footer(BuildContext context, Lyrics lyrics) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_timing && lyrics.synced)
            _TimingStrip(controller: widget.controller),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: TagChip(
                        icon: Icons.subtitles_outlined,
                        label: lyrics.fileName ?? l.lyricsEmbedded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lyrics.synced ? l.lyricsSynced : l.lyricsUnsynced,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              if (lyrics.synced)
                IconButton(
                  tooltip: l.lyricsTiming,
                  isSelected: _timing,
                  icon: const Icon(Icons.schedule_rounded, size: 20),
                  onPressed: () => setState(() => _timing = !_timing),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final lyrics = controller.lyrics;
      if (lyrics == null) {
        return controller.loading
            ? const SizedBox.expand()
            : Center(child: EmptyNote(context.l10n.noLyrics));
      }
      return LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Expanded(
              child: _Lines(
                key: ObjectKey(lyrics),
                lyrics: lyrics,
                controller: controller,
              ),
            ),
            if (constraints.maxHeight >= LyricsView.footerMinHeight)
              _footer(context, lyrics),
          ],
        ),
      );
    },
  );
}

class _TimingStrip extends StatelessWidget {
  final LyricsController controller;

  const _TimingStrip({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final offset = controller.offsetMs;
    final number = NumberFormat(
      '+0.0;-0.0',
      Localizations.localeOf(context).toLanguageTag(),
    );
    const step = LyricsController.offsetStep;
    return Row(
      children: [
        IconButton(
          tooltip: l.lyricsLater,
          icon: const Icon(Icons.remove_rounded),
          onPressed: () => controller.setOffset(offset - step),
        ),
        Expanded(
          child: Text(
            l.secondsOffset(number.format(offset / 1000)),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
        IconButton(
          tooltip: l.lyricsEarlier,
          icon: const Icon(Icons.add_rounded),
          onPressed: () => controller.setOffset(offset + step),
        ),
        IconButton(
          tooltip: l.lyricsResetTiming,
          icon: const Icon(Icons.restart_alt_rounded),
          onPressed: offset == 0 ? null : () => controller.setOffset(0),
        ),
      ],
    );
  }
}

class _Lines extends StatefulWidget {
  final Lyrics lyrics;
  final LyricsController controller;

  const _Lines({super.key, required this.lyrics, required this.controller});

  @override
  State<_Lines> createState() => _LinesState();
}

class _LinesState extends State<_Lines> with SingleTickerProviderStateMixin {
  static const _scrollTime = Duration(milliseconds: 300);

  final _scroll = ScrollController();

  /// À mão: o animateTo do Scrollable ignora os cliques enquanto anda, e a linha
  /// muda a cada poucos segundos.
  late final _glide = AnimationController(vsync: this, duration: _scrollTime)
    ..addListener(_onGlide);
  double _glideFrom = 0;
  double _glideTo = 0;
  late final List<GlobalKey> _keys = [
    for (final _ in widget.lyrics.lines) GlobalKey(),
  ];
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    widget.controller.line.addListener(_follow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow(jump: true));
  }

  @override
  void dispose() {
    _hold?.cancel();
    _glide.dispose();
    _scroll.dispose();
    widget.controller.line.removeListener(_follow);
    super.dispose();
  }

  void _follow({bool jump = false}) {
    if (_hold != null || !mounted) return;
    final line = widget.controller.line.value;
    if (line < 0) return;
    // Depois do quadro: a linha da vez muda de tamanho, e a conta usa o novo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[line].currentContext?.findRenderObject();
      if (!mounted || target == null || !_scroll.hasClients) return;
      final position = _scroll.position;
      _glideTo = RenderAbstractViewport.of(target)
          .getOffsetToReveal(target, 0.5)
          .offset
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (jump || MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(_glideTo);
        return;
      }
      _glideFrom = position.pixels;
      unawaited(_glide.forward(from: 0));
    });
  }

  void _onGlide() {
    if (!_scroll.hasClients) return;
    final t = Curves.easeOut.transform(_glide.value);
    _scroll.jumpTo(_glideFrom + (_glideTo - _glideFrom) * t);
  }

  bool _onScroll(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.idle) return false;
    _glide.stop();
    _hold?.cancel();
    _hold = Timer(LyricsView.holdAfterScroll, () {
      _hold = null;
      _follow();
    });
    return false;
  }

  TextStyle _style(ThemeData theme, int index, int current) {
    final text = theme.textTheme;
    final scheme = theme.colorScheme;
    if (!widget.lyrics.synced) {
      return text.bodyLarge!.copyWith(color: scheme.onSurface);
    }
    if (index == current) {
      return text.titleLarge!.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w700,
      );
    }
    if (current >= 0 && (index - current).abs() == 1) {
      return text.titleMedium!.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      );
    }
    return text.bodyLarge!.copyWith(color: scheme.onSurfaceVariant);
  }

  Widget _line(BuildContext context, int index, int current) {
    final line = widget.lyrics.lines[index];
    if (line.text.isEmpty) {
      return SizedBox(key: _keys[index], height: 16);
    }
    final still = MediaQuery.disableAnimationsOf(context);
    final text = AnimatedDefaultTextStyle(
      duration: still ? Duration.zero : const Duration(milliseconds: 200),
      style: _style(Theme.of(context), index, current),
      child: Text(line.text),
    );
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SizedBox(width: double.infinity, child: text),
    );
    if (!widget.lyrics.synced) {
      return KeyedSubtree(key: _keys[index], child: padded);
    }
    return InkWell(
      key: _keys[index],
      borderRadius: BorderRadius.circular(8),
      onTap: () => unawaited(widget.controller.seekToLine(index)),
      child: padded,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        NotificationListener<UserScrollNotification>(
          onNotification: _onScroll,
          child: SingleChildScrollView(
            controller: _scroll,
            // A primeira e a última também chegam ao centro
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: widget.lyrics.synced ? constraints.maxHeight * .4 : 8,
            ),
            child: ValueListenableBuilder(
              valueListenable: widget.controller.line,
              builder: (context, current, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < widget.lyrics.lines.length; i++)
                    _line(context, i, current),
                ],
              ),
            ),
          ),
        ),
  );
}
