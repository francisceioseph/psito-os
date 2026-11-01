// system_shell/lib/widgets/psito_desktop_icons.dart
//
// Os ícones da mesa, por cima do papel de parede. As células contam do canto
// de cima à direita da área livre (a tela sem a top bar e a dock). Quem
// decide a célula de cada um é o modelo (o psito_desktop); aqui ficam os
// cliques, o retângulo de seleção e o foco.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:psito_desktop/psito_desktop.dart';

class DeskIcon {
  /// Identifica o item ([PsitoDesktopIcons.cells]).
  final String key;
  final String name;
  final Widget Function(double size) icon;

  /// O campo de renomear, no lugar do nome.
  final Widget? editor;

  /// Recortado: fica apagado até colar.
  final bool dimmed;

  const DeskIcon({
    required this.key,
    required this.name,
    required this.icon,
    this.editor,
    this.dimmed = false,
  });
}

class PsitoDesktopIcons extends StatefulWidget {
  final List<DeskIcon> icons;
  final Map<String, DeskCell> cells;
  final double iconSize;

  /// O que a top bar e a dock tiram da tela.
  final EdgeInsets insets;
  final Set<String> selected;

  /// O botão apertado num item; null, na mesa vazia.
  final ValueChanged<String?> onPress;
  final ValueChanged<String> onRelease;

  /// Os itens dentro do retângulo de seleção, a cada mudança.
  final ValueChanged<Set<String>> onRect;
  final ValueChanged<String> onOpen;

  /// A superfície tem o teclado: ganhando, a mesa pede o foco do Flutter, e
  /// perdendo, devolve (o que confirma um renomear no meio).
  final bool keyboard;
  final KeyEventResult Function(KeyEvent event)? onKey;

  /// O clique direito num item ou na mesa vazia (null), com o ponteiro.
  final void Function(String? key, Offset position)? onMenu;

  /// Um menu aberto na sobreposição está com o foco do Flutter: fechando, a
  /// mesa pega de volta.
  final bool popup;

  const PsitoDesktopIcons({
    super.key,
    required this.icons,
    required this.cells,
    required this.iconSize,
    required this.insets,
    this.selected = const {},
    required this.onPress,
    required this.onRelease,
    required this.onRect,
    required this.onOpen,
    this.keyboard = true,
    this.onKey,
    this.onMenu,
    this.popup = false,
  });

  @override
  State<PsitoDesktopIcons> createState() => _PsitoDesktopIconsState();
}

class _PsitoDesktopIconsState extends State<PsitoDesktopIcons> {
  final _focus = FocusNode(debugLabel: 'mesa');
  Offset? _bandStart;
  Offset? _bandEnd;
  Set<String> _bandHits = const {};

  bool get _editing => widget.icons.any((icon) => icon.editor != null);

  @override
  void didUpdateWidget(PsitoDesktopIcons old) {
    super.didUpdateWidget(old);
    final wasEditing = old.icons.any((icon) => icon.editor != null);
    if (widget.keyboard && old.popup && !widget.popup) {
      // Depois do quadro: o menu sai da outra view neste mesmo quadro, e o foco
      // dele indo embora levaria este pedido junto. Um campo de renomear que
      // acabou de abrir pede depois, e fica com o foco
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    } else if (widget.keyboard && (!old.keyboard || (wasEditing && !_editing))) {
      _focus.requestFocus();
    } else if (!widget.keyboard && old.keyboard && _focus.hasFocus) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _press(String? key) {
    _focus.requestFocus();
    widget.onPress(key);
  }

  void _bandDown(PointerDownEvent event) {
    if (event.buttons & kPrimaryButton == 0) return;
    _press(null);
    _bandStart = event.localPosition;
  }

  void _bandMove(PointerMoveEvent event, double width) {
    final start = _bandStart;
    if (start == null) return;
    setState(() => _bandEnd = event.localPosition);
    final rect = Rect.fromPoints(start, event.localPosition);
    final hits = {
      for (final icon in widget.icons)
        if (widget.cells[icon.key] case final at?)
          if (_cellRect(at, width).overlaps(rect)) icon.key,
    };
    if (!setEquals(hits, _bandHits)) {
      _bandHits = hits;
      widget.onRect(hits);
    }
  }

  void _bandUp() {
    _bandHits = const {};
    _bandStart = null;
    if (_bandEnd != null) setState(() => _bandEnd = null);
  }

  // Sem a folga da célula: o retângulo precisa tocar o desenho
  Rect _cellRect(DeskCell at, double width) {
    final cell = deskCellSize(widget.iconSize);
    return Rect.fromLTWH(
      width - widget.insets.right - (at.column + 1) * cell.width,
      widget.insets.top + at.row * cell.height,
      cell.width,
      cell.height,
    ).deflate(12);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final cell = deskCellSize(widget.iconSize);
    final selected = widget.selected;
    // Os selecionados por último: o nome inteiro passa por cima dos vizinhos
    final ordered = [
      for (final icon in widget.icons)
        if (!selected.contains(icon.key)) icon,
      for (final icon in widget.icons)
        if (selected.contains(icon.key)) icon,
    ];
    final bandStart = _bandStart, bandEnd = _bandEnd;
    return Focus(
      focusNode: _focus,
      onKeyEvent: widget.onKey == null
          ? null
          : (_, event) => widget.onKey!(event),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _bandDown,
                onPointerMove: (event) =>
                    _bandMove(event, constraints.maxWidth),
                onPointerUp: (_) => _bandUp(),
                onPointerCancel: (_) => _bandUp(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onSecondaryTapUp: widget.onMenu == null
                      ? null
                      : (details) =>
                            widget.onMenu!(null, details.globalPosition),
                ),
              ),
            ),
            for (final icon in ordered)
              if (widget.cells[icon.key] case final at?)
                Positioned(
                  key: ValueKey('desk-${icon.key}'),
                  right: widget.insets.right + at.column * cell.width,
                  top: widget.insets.top + at.row * cell.height,
                  width: cell.width,
                  height: cell.height,
                  child: _Item(
                    icon: icon,
                    iconSize: widget.iconSize,
                    selected: selected.contains(icon.key),
                    // Só um mostra o nome inteiro: vários se cobririam
                    expanded:
                        selected.length == 1 && selected.contains(icon.key),
                    active: widget.keyboard,
                    onPress: () => _press(icon.key),
                    onRelease: () => widget.onRelease(icon.key),
                    onOpen: () => widget.onOpen(icon.key),
                    onMenu: widget.onMenu == null
                        ? null
                        : (position) => widget.onMenu!(icon.key, position),
                  ),
                ),
            if (bandStart != null && bandEnd != null)
              Positioned.fromRect(
                key: const ValueKey('desk-band'),
                rect: Rect.fromPoints(bandStart, bandEnd),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      border: Border.all(color: accent),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final DeskIcon icon;
  final double iconSize;
  final bool selected;
  final bool expanded;

  /// A mesa tem o teclado; sem ele, a seleção fica apagada.
  final bool active;
  final VoidCallback onPress;
  final VoidCallback onRelease;
  final VoidCallback onOpen;
  final ValueChanged<Offset>? onMenu;

  const _Item({
    required this.icon,
    required this.iconSize,
    required this.selected,
    required this.expanded,
    required this.active,
    required this.onPress,
    required this.onRelease,
    required this.onOpen,
    this.onMenu,
  });

  static const _shadow = [
    Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = active
        ? Theme.of(context).colorScheme.primary
        : Colors.blueGrey;
    final editor = icon.editor;
    // Seleciona já no apertar: um onTapDown esperaria o tempo do duplo clique.
    // Com o campo aberto, os cliques são dele
    return Listener(
      onPointerDown: editor != null
          ? null
          : (event) {
              if (event.buttons & kPrimaryButton != 0) onPress();
            },
      onPointerUp: editor != null ? null : (_) => onRelease(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: editor != null ? null : onOpen,
        onSecondaryTapUp: editor != null || onMenu == null
            ? null
            : (details) => onMenu!(details.globalPosition),
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: selected ? accent.withValues(alpha: 0.28) : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Opacity(
                    opacity: icon.dimmed ? 0.45 : 1,
                    child: icon.icon(iconSize),
                  ),
                ),
                const SizedBox(height: 3),
                editor ??
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? accent.withValues(alpha: 0.85) : null,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        icon.name,
                        maxLines: expanded ? null : 2,
                        overflow: expanded ? null : TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          shadows: selected ? null : _shadow,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
