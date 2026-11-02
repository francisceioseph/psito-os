import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:psito_sdk/psito_sdk.dart';

import 'l10n/l10n.dart';
import 'settings_ui.dart';

const _scales = [1.0, 1.25, 1.5, 1.75, 2.0];

// Até onde um monitor gruda na borda de cima ou de baixo do vizinho
const _alignDistance = 40.0;

/// Onde [moving] encosta: no lado de outro monitor mais perto de onde está, sem
/// cobrir ninguém.
Offset snapDisplay(Rect moving, List<Rect> others) {
  if (others.isEmpty) return Offset.zero;
  double aligned(double value, double start, double end, double length) {
    final clamped = value.clamp(start - length + 1, end - 1);
    if ((clamped - start).abs() < _alignDistance) return start;
    if ((clamped + length - end).abs() < _alignDistance) return end - length;
    return clamped;
  }

  bool free(Offset at) {
    final rect = (at & moving.size).deflate(0.5);
    return !others.any(rect.overlaps);
  }

  final candidates = [
    for (final other in others) ...[
      Offset(
        other.right,
        aligned(moving.top, other.top, other.bottom, moving.height),
      ),
      Offset(
        other.left - moving.width,
        aligned(moving.top, other.top, other.bottom, moving.height),
      ),
      Offset(
        aligned(moving.left, other.left, other.right, moving.width),
        other.bottom,
      ),
      Offset(
        aligned(moving.left, other.left, other.right, moving.width),
        other.top - moving.height,
      ),
    ],
  ].where(free);
  final best = candidates.reduce(
    (a, b) =>
        (a - moving.topLeft).distanceSquared <=
            (b - moving.topLeft).distanceSquared
        ? a
        : b,
  );
  return Offset(best.dx.roundToDouble(), best.dy.roundToDouble());
}

/// Do outro lado de todos os monitores, para quem não arrasta.
Offset besideDisplays(Rect moving, List<Rect> others, AxisDirection side) {
  if (others.isEmpty) return Offset.zero;
  final all = others.reduce((a, b) => a.expandToInclude(b));
  return switch (side) {
    AxisDirection.left => Offset(all.left - moving.width, all.top),
    AxisDirection.right => Offset(all.right, all.top),
    AxisDirection.up => Offset(all.left, all.top - moving.height),
    AxisDirection.down => Offset(all.left, all.bottom),
  };
}

/// Os tamanhos, do maior para o menor, um de cada.
List<PsitoDisplayMode> displaySizes(List<PsitoDisplayMode> modes) {
  final sizes = <PsitoDisplayMode>[];
  for (final mode in modes) {
    if (!sizes.any(mode.sameSize)) sizes.add(mode);
  }
  return sizes
    ..sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
}

/// O melhor modo de um tamanho: a maior frequência.
PsitoDisplayMode bestRefresh(
  List<PsitoDisplayMode> modes,
  PsitoDisplayMode size,
) => modes.where(size.sameSize).reduce((a, b) => b.refresh > a.refresh ? b : a);

/// A forma de um monitor recém-ligado: o tamanho que ele prefere.
PsitoDisplayMode? preferredMode(List<PsitoDisplayMode> modes) {
  if (modes.isEmpty) return null;
  final size =
      modes.where((m) => m.preferred).firstOrNull ?? displaySizes(modes).first;
  return bestRefresh(modes, size);
}

/// Os tamanhos que todos têm, para espelhar.
List<PsitoDisplayMode> commonSizes(Iterable<PsitoDisplay> displays) {
  final first = displays.firstOrNull;
  if (first == null) return const [];
  return displaySizes(first.modes)
      .where((size) => displays.every((d) => d.modes.any(size.sameSize)))
      .toList();
}

/// A seção Monitores. Mexer só muda o rascunho, e o "Aplicar" pede ao shell, que
/// pergunta se a configuração fica. Só o principal vale na hora.
class DisplaysSection extends StatefulWidget {
  final PsitoDisplays displays;

  const DisplaysSection({super.key, required this.displays});

  @override
  State<DisplaysSection> createState() => _DisplaysSectionState();
}

class _DisplaysSectionState extends State<DisplaysSection> {
  final _focus = FocusNode(debugLabel: 'displays-layout');
  List<PsitoDisplay> _draft = const [];
  String? _selected;
  bool _editing = false;
  bool _applying = false;
  PsitoDisplaysResult? _result;

  // Durante o arrastar, a escala do desenho fica parada e a posição é fracionada
  ({double factor, Offset origin})? _frozen;
  Offset? _dragAt;

  List<PsitoDisplay> get _live => widget.displays.displays.value;

  @override
  void initState() {
    super.initState();
    widget.displays.displays.addListener(_changed);
    _follow();
  }

  @override
  void dispose() {
    widget.displays.displays.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _follow() {
    _draft = _live;
    _editing = false;
    if (!_draft.any((d) => d.name == _selected)) {
      _selected =
          (_draft.where((d) => d.primary).firstOrNull ?? _draft.firstOrNull)
              ?.name;
    }
  }

  void _changed() {
    final live = _live;
    final sameMonitors =
        live.length == _draft.length &&
        live.every((d) => _draft.any((other) => other.name == d.name));
    setState(() {
      if (_editing && sameMonitors) {
        // O rascunho continua, e o principal não faz parte dele
        _draft = [
          for (final display in _draft)
            display.copyWith(
              primary: live.firstWhere((d) => d.name == display.name).primary,
            ),
        ];
      } else {
        _follow();
      }
    });
  }

  bool get _dirty =>
      _editing &&
      _draft.any((d) {
        final live = _live.where((other) => other.name == d.name).firstOrNull;
        return live == null || !d.sameConfig(live);
      });

  PsitoDisplay? get _current =>
      _draft.where((d) => d.name == _selected).firstOrNull;

  Iterable<PsitoDisplay> get _enabled =>
      _draft.where((d) => d.enabled && d.mode != null);

  bool get _mirrored {
    final enabled = _enabled.toList();
    return enabled.length >= 2 &&
        enabled.every((d) => d.rect == enabled.first.rect);
  }

  void _edit(
    PsitoDisplay Function(PsitoDisplay) change, {
    bool resized = false,
  }) {
    setState(() {
      _editing = true;
      _result = null;
      _draft = [
        for (final display in _draft)
          if (display.name == _selected) change(display) else display,
      ];
      if (resized) _snapSelected();
    });
  }

  List<Rect> _othersOf(String? name) => [
    for (final display in _enabled)
      if (display.name != name) display.rect,
  ];

  void _moveSelected(Offset to) {
    _draft = [
      for (final display in _draft)
        if (display.name == _selected)
          display.copyWith(x: to.dx.round(), y: to.dy.round())
        else
          display,
    ];
  }

  void _snapSelected() {
    final current = _current;
    if (current == null || !current.enabled || current.mode == null) return;
    _moveSelected(snapDisplay(current.rect, _othersOf(current.name)));
  }

  void _setMirror(bool on) {
    setState(() {
      _editing = true;
      _result = null;
      if (on) {
        final size = commonSizes(_enabled).first;
        _draft = [
          for (final display in _draft)
            display.enabled && display.mode != null
                ? display.copyWith(
                    x: 0,
                    y: 0,
                    transform: 0,
                    scale: 1,
                    mode: bestRefresh(display.modes, size),
                  )
                : display,
        ];
      } else {
        var right = 0;
        _draft = [
          for (final display in _draft)
            if (display.enabled && display.mode != null)
              () {
                final next = display.copyWith(
                  x: right,
                  y: 0,
                  mode: preferredMode(display.modes),
                );
                right += next.rect.width.ceil();
                return next;
              }()
            else
              display,
        ];
      }
    });
  }

  void _setMirrorSize(PsitoDisplayMode size) {
    setState(() {
      _editing = true;
      _result = null;
      _draft = [
        for (final display in _draft)
          display.enabled && display.mode != null
              ? display.copyWith(mode: bestRefresh(display.modes, size))
              : display,
      ];
    });
  }

  void _setEnabled(PsitoDisplay display, bool on) {
    _edit((d) {
      if (!on) return d.copyWith(enabled: false);
      return d.copyWith(enabled: true, mode: d.mode ?? preferredMode(d.modes));
    }, resized: on);
  }

  void _moveBeside(AxisDirection side) {
    final current = _current;
    if (current == null || !current.enabled || current.mode == null) return;
    setState(() {
      _editing = true;
      _result = null;
      _moveSelected(
        besideDisplays(current.rect, _othersOf(current.name), side),
      );
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final side = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => AxisDirection.left,
      LogicalKeyboardKey.arrowRight => AxisDirection.right,
      LogicalKeyboardKey.arrowUp => AxisDirection.up,
      LogicalKeyboardKey.arrowDown => AxisDirection.down,
      _ => null,
    };
    if (side == null) return KeyEventResult.ignored;
    _moveBeside(side);
    return KeyEventResult.handled;
  }

  Future<void> _apply() async {
    setState(() {
      _applying = true;
      _result = null;
    });
    final result = await widget.displays.apply(_draft);
    if (!mounted) return;
    setState(() {
      _applying = false;
      _result = result;
      // Daqui em diante vale o que o shell disser, inclusive se voltar
      if (result == PsitoDisplaysResult.ok) _follow();
    });
  }

  /// O número do monitor, como a dock diz: da esquerda para a direita.
  int _numberOf(PsitoDisplay display) {
    final enabled = _live.where((d) => d.enabled).toList()
      ..sort((a, b) {
        final x = a.x.compareTo(b.x);
        return x != 0 ? x : a.y.compareTo(b.y);
      });
    final at = enabled.indexWhere((d) => d.name == display.name);
    return at >= 0 ? at + 1 : enabled.length + 1;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_draft.isEmpty) return SettingsNote(l.displaysUnavailable);
    final current = _current;
    final mirrored = _mirrored;
    final common = commonSizes(_enabled);
    final actions = [
      if (_result case final result? when result != PsitoDisplaysResult.ok)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SettingsNote(
            result == PsitoDisplaysResult.busy
                ? l.displaysBusy
                : l.displaysFailed,
          ),
        ),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            key: const ValueKey('displays-discard'),
            onPressed: _dirty && !_applying
                ? () => setState(() {
                    _result = null;
                    _follow();
                  })
                : null,
            child: Text(l.displaysDiscard),
          ),
          FilledButton(
            key: const ValueKey('displays-apply'),
            onPressed: _dirty && !_applying ? () => unawaited(_apply()) : null,
            child: Text(l.displaysApply),
          ),
        ],
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_draft.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final display
                    in _draft.toList()
                      ..sort((a, b) => _numberOf(a).compareTo(_numberOf(b))))
                  ChoiceChip(
                    key: ValueKey('display-chip-${display.name}'),
                    label: Text(
                      l.displaysTile(_numberOf(display), display.label),
                    ),
                    selected: display.name == _selected,
                    onSelected: (_) => setState(() => _selected = display.name),
                  ),
              ],
            ),
          ),
        if (mirrored)
          SettingsGroup(
            children: [SettingsPad(child: Text(l.displaysMirrorNote))],
          )
        else if (_draft.length > 1 && _enabled.isNotEmpty)
          SettingsGroup(
            title: l.displaysLayout,
            footer: l.displaysHint,
            children: [_layout(l)],
          ),
        // Com a arrumação, logo abaixo dela: é de lá que se vem depois de arrastar
        if (_draft.length > 1) ...[...actions, const SizedBox(height: 20)],
        SettingsGroup(
          footer: _enabled.length >= 2 && common.isEmpty
              ? l.displaysMirrorNone
              : null,
          children: [
            if (_enabled.length >= 2 || mirrored)
              SettingsRow(
                title: l.displaysMirror,
                control: Semantics(
                  label: l.displaysMirror,
                  child: Switch(
                    key: const ValueKey('displays-mirror'),
                    value: mirrored,
                    onChanged: common.isEmpty ? null : _setMirror,
                  ),
                ),
              ),
            if (mirrored)
              _dropdown<PsitoDisplayMode>(
                key: 'display-resolution',
                title: l.displaysResolution,
                value: common.firstWhere(_enabled.first.mode!.sameSize),
                items: {
                  for (final size in common)
                    size: l.displaysResolutionValue(size.width, size.height),
                },
                onChanged: _setMirrorSize,
              )
            else if (current != null)
              ..._controls(l, current),
          ],
        ),
        if (_draft.length == 1) ...actions,
      ],
    );
  }

  List<Widget> _controls(SettingsLocalizations l, PsitoDisplay display) {
    final mode = display.mode;
    final sizes = displaySizes(display.modes);
    final refreshes = mode == null
        ? const <PsitoDisplayMode>[]
        : (display.modes.where(mode.sameSize).toList()
            ..sort((a, b) => b.refresh.compareTo(a.refresh)));
    final hertz = NumberFormat('0.##', l.localeName);
    return [
      SettingsRow(
        title: l.displaysEnabled,
        control: Semantics(
          label: l.displaysEnabled,
          child: Switch(
            key: const ValueKey('display-enabled'),
            value: display.enabled,
            // Sempre sobra um ligado
            onChanged:
                (display.enabled && _enabled.length < 2) ||
                    preferredMode(display.modes) == null
                ? null
                : (on) => _setEnabled(display, on),
          ),
        ),
      ),
      if (display.enabled && mode != null) ...[
        _dropdown<PsitoDisplayMode>(
          key: 'display-resolution',
          title: l.displaysResolution,
          value: sizes.firstWhere(mode.sameSize),
          items: {
            for (final size in sizes)
              size: l.displaysResolutionValue(size.width, size.height),
          },
          onChanged: (size) => _edit(
            (d) => d.copyWith(mode: bestRefresh(d.modes, size)),
            resized: true,
          ),
        ),
        if (refreshes.length > 1)
          _dropdown<PsitoDisplayMode>(
            key: 'display-refresh',
            title: l.displaysRefresh,
            value: mode,
            items: {
              for (final option in refreshes)
                option: l.displaysRefreshValue(
                  hertz.format(option.refresh / 1000),
                ),
            },
            onChanged: (option) => _edit((d) => d.copyWith(mode: option)),
          ),
        _dropdown<int>(
          key: 'display-rotation',
          title: l.displaysRotation,
          value: display.transform & 3,
          items: {
            0: l.displaysRotationNormal,
            1: l.displaysRotationLeft,
            2: l.displaysRotationInverted,
            3: l.displaysRotationRight,
          },
          onChanged: (transform) =>
              _edit((d) => d.copyWith(transform: transform), resized: true),
        ),
        _dropdown<double>(
          key: 'display-scale',
          title: l.displaysScale,
          value: display.scale,
          items: {
            for (final scale in {..._scales, display.scale})
              scale: l.displaysScaleValue((scale * 100).round()),
          },
          onChanged: (scale) =>
              _edit((d) => d.copyWith(scale: scale), resized: true),
        ),
        if (_draft.length > 1)
          SettingsRow(
            title: l.displaysPrimary,
            control: display.primary
                ? Text(
                    l.displaysIsPrimary,
                    style: TextStyle(color: context.palette.textSecondary),
                  )
                : TextButton(
                    key: const ValueKey('display-make-primary'),
                    onPressed: () =>
                        unawaited(widget.displays.setPrimary(display.name)),
                    child: Text(l.displaysMakePrimary),
                  ),
          ),
      ],
    ];
  }

  Widget _dropdown<T>({
    required String key,
    required String title,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) => SettingsRow(
    title: title,
    // Largura fixa: numa janela estreita, o texto é que encolhe
    control: SizedBox(
      width: 200,
      child: DropdownButton<T>(
        key: ValueKey(key),
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: [
          for (final MapEntry(key: option, value: label) in items.entries)
            DropdownMenuItem(
              value: option,
              child: Text(label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (option) {
          if (option != null && option != value) onChanged(option);
        },
      ),
    ),
  );

  Widget _layout(SettingsLocalizations l) => Focus(
    focusNode: _focus,
    onKeyEvent: _onKey,
    child: SizedBox(
      height: 220,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final enabled = _enabled.toList();
          final bounds = enabled
              .map((d) => d.rect)
              .reduce((a, b) => a.expandToInclude(b));
          const margin = 20.0;
          final factor =
              _frozen?.factor ??
              math.min(
                (constraints.maxWidth - 2 * margin) / bounds.width,
                (constraints.maxHeight - 2 * margin) / bounds.height,
              );
          final origin =
              _frozen?.origin ??
              Offset(
                (constraints.maxWidth - bounds.width * factor) / 2 -
                    bounds.left * factor,
                (constraints.maxHeight - bounds.height * factor) / 2 -
                    bounds.top * factor,
              );
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final display in enabled) _tile(l, display, factor, origin),
            ],
          );
        },
      ),
    ),
  );

  Widget _tile(
    SettingsLocalizations l,
    PsitoDisplay display,
    double factor,
    Offset origin,
  ) {
    final palette = context.palette;
    final selected = display.name == _selected;
    var rect = display.rect;
    if (selected && _dragAt != null) rect = _dragAt! & rect.size;
    void select() {
      setState(() => _selected = display.name);
      _focus.requestFocus();
    }

    return Positioned(
      left: origin.dx + rect.left * factor,
      top: origin.dy + rect.top * factor,
      width: rect.width * factor,
      height: rect.height * factor,
      child: Semantics(
        button: true,
        selected: selected,
        label: l.displaysTile(_numberOf(display), display.label),
        onTap: select,
        customSemanticsActions: {
          for (final (label, side) in [
            (l.displaysMoveLeft, AxisDirection.left),
            (l.displaysMoveRight, AxisDirection.right),
            (l.displaysMoveUp, AxisDirection.up),
            (l.displaysMoveDown, AxisDirection.down),
          ])
            CustomSemanticsAction(label: label): () {
              setState(() => _selected = display.name);
              _moveBeside(side);
            },
        },
        child: GestureDetector(
          key: ValueKey('display-${display.name}'),
          excludeFromSemantics: true,
          // O monitor segue o ponteiro desde o aperto, sem perder o começo
          dragStartBehavior: DragStartBehavior.down,
          onTap: select,
          onPanStart: (_) => setState(() {
            _selected = display.name;
            _frozen = (factor: factor, origin: origin);
            _dragAt = display.rect.topLeft;
          }),
          onPanUpdate: (details) =>
              setState(() => _dragAt = _dragAt! + details.delta / factor),
          onPanEnd: (_) => setState(() {
            _editing = true;
            _result = null;
            _moveSelected(
              snapDisplay(
                _dragAt! & display.rect.size,
                _othersOf(display.name),
              ),
            );
            _dragAt = null;
            _frozen = null;
          }),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.panelAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : palette.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_numberOf(display)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (display.primary)
                        Text(
                          l.displaysPrimaryBadge,
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
