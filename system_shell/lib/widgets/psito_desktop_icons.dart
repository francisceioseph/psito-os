// system_shell/lib/widgets/psito_desktop_icons.dart
//
// Os ícones da mesa, por cima do papel de parede. As células contam do canto
// de cima à direita da área livre (a tela sem a top bar e a dock). Quem
// decide a célula de cada um é o modelo (o psito_desktop); aqui ficam os
// cliques, o retângulo de seleção, o arrastar e o foco.
//
// O fundo fica por baixo das janelas, então o arrastar de um arquivo vai pelo
// sistema desde o começo, e quem desenha o ícone é o compositor. O Draggable
// segue vivo por baixo: de volta à mesa, ele solta nos DragTargets daqui.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:flutter/rendering.dart';
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

  /// É um arquivo, que dá para levar para fora da mesa. O home e a lixeira só
  /// mudam de célula.
  final bool leavesDesk;

  const DeskIcon({
    required this.key,
    required this.name,
    required this.icon,
    this.editor,
    this.dimmed = false,
    this.leavesDesk = true,
  });
}

/// O que está sendo arrastado dentro da mesa.
class _DeskDrag {
  final String grabbed;
  final Set<String> keys;

  const _DeskDrag(this.grabbed, this.keys);
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

  /// O arrastar começou em [key].
  final ValueChanged<String>? onDragStart;

  /// Leva [keys] para fora da mesa, pelo sistema: tem que sair com o botão
  /// ainda apertado. [icon] é o PNG do ícone, pego em [hotspot].
  final void Function(Set<String> keys, Uint8List? icon, Offset hotspot)?
  onDragOut;

  /// Soltou na mesa, com [grabbed] levado para o ponto [position]. Sem ele, os
  /// ícones não arrastam.
  final void Function(String grabbed, Set<String> keys, Offset position)?
  onMove;

  /// Se o item [target] aceita [keys] soltos em cima dele.
  final bool Function(String target, Set<String> keys)? canDropOn;
  final void Function(String target, Set<String> keys)? onDropOn;

  /// Põe em volta de um item o alvo do que vem de fora; [child] recebe se tem
  /// algo aceitável em cima dele.
  final Widget Function(String key, Widget Function(bool hovering) child)?
  wrapItem;

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
    this.onDragStart,
    this.onDragOut,
    this.onMove,
    this.canDropOn,
    this.onDropOn,
    this.wrapItem,
  });

  @override
  State<PsitoDesktopIcons> createState() => _PsitoDesktopIconsState();
}

class _PsitoDesktopIconsState extends State<PsitoDesktopIcons> {
  final _focus = FocusNode(debugLabel: 'mesa');
  Offset? _bandStart;
  Offset? _bandEnd;
  Set<String> _bandHits = const {};
  final _boundaries = <String, GlobalKey>{};
  Set<String>? _dragging;
  Future<Uint8List?>? _dragImage;
  Offset _dragHotspot = Offset.zero;

  /// O arrastar saiu pelo sistema: o compositor desenha o ícone, e não o
  /// Flutter.
  final _outside = ValueNotifier(false);

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
    } else if (widget.keyboard &&
        (!old.keyboard || (wasEditing && !_editing))) {
      _focus.requestFocus();
    } else if (!widget.keyboard && old.keyboard && _focus.hasFocus) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _outside.dispose();
    super.dispose();
  }

  void _press(String? key) {
    _focus.requestFocus();
    // Um arrastar cujo item sumiu no meio não avisa que acabou
    _dragging = null;
    widget.onPress(key);
  }

  void _pressItem(DeskIcon icon, Offset position) {
    _prepareDragImage(icon, position);
    _press(icon.key);
  }

  // O PNG tem que estar pronto quando o arrastar começar, porque o sistema só
  // aceita com o botão apertado. Fica no apertar, antes de a seleção repintar
  void _prepareDragImage(DeskIcon icon, Offset position) {
    _dragImage = null;
    if (widget.onDragOut == null || !icon.leavesDesk) return;
    final box = _boundaries[icon.key]?.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary) return;
    _dragHotspot = box.globalToLocal(position);
    final count = !widget.selected.contains(icon.key)
        ? 1
        : widget.icons
              .where((i) => i.leavesDesk && widget.selected.contains(i.key))
              .length;
    _dragImage = _renderDragImage(
      box,
      count,
      Theme.of(context).colorScheme.primary,
    );
  }

  void _dragStarted(String key, Set<String> keys) {
    setState(() => _dragging = keys);
    widget.onDragStart?.call(key);
    final out = widget.onDragOut;
    final leaves = widget.icons.any(
      (icon) => icon.leavesDesk && keys.contains(icon.key),
    );
    if (out == null || !leaves) return;
    _outside.value = true;
    final image = _dragImage;
    if (image == null) {
      out(keys, null, Offset.zero);
      return;
    }
    final hotspot = _dragHotspot;
    image.then((png) {
      // Soltou antes de o PNG ficar pronto: sem o botão, não tem arrastar
      if (mounted && identical(_dragging, keys)) out(keys, png, hotspot);
    });
  }

  void _dragEnded() {
    _outside.value = false;
    if (mounted && _dragging != null) setState(() => _dragging = null);
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
      child: DragTarget<_DeskDrag>(
        onAcceptWithDetails: (details) => widget.onMove?.call(
          details.data.grabbed,
          details.data.keys,
          details.offset,
        ),
        builder: (context, _, _) => LayoutBuilder(
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
                    child: _target(icon),
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
      ),
    );
  }

  // O item é alvo do que vem da mesa e, pelo wrapItem, do que vem de fora
  Widget _target(DeskIcon icon) {
    Widget build(bool outside) => DragTarget<_DeskDrag>(
      onWillAcceptWithDetails: (details) =>
          !details.data.keys.contains(icon.key) &&
          (widget.canDropOn?.call(icon.key, details.data.keys) ?? false),
      onAcceptWithDetails: (details) =>
          widget.onDropOn?.call(icon.key, details.data.keys),
      builder: (context, candidates, _) =>
          _draggable(icon, outside || candidates.isNotEmpty),
    );
    return widget.wrapItem?.call(icon.key, build) ?? build(false);
  }

  Widget _draggable(DeskIcon icon, bool hovering) {
    final selected = widget.selected;
    final item = _Item(
      icon: icon,
      iconSize: widget.iconSize,
      selected: selected.contains(icon.key) || hovering,
      // Só um mostra o nome inteiro: vários se cobririam
      expanded: selected.length == 1 && selected.contains(icon.key),
      active: widget.keyboard,
      ghost: _dragging?.contains(icon.key) ?? false,
      boundary: _boundaries.putIfAbsent(icon.key, GlobalKey.new),
      onPress: (position) => _pressItem(icon, position),
      // Um arrastar que acabou não é um clique: a seleção fica
      onRelease: () {
        if (_dragging == null) widget.onRelease(icon.key);
      },
      onOpen: () => widget.onOpen(icon.key),
      onMenu: widget.onMenu == null
          ? null
          : (position) => widget.onMenu!(icon.key, position),
    );
    if (widget.onMove == null) return item;
    final keys = selected.contains(icon.key) ? selected : {icon.key};
    final cell = deskCellSize(widget.iconSize);
    return Draggable<_DeskDrag>(
      data: _DeskDrag(icon.key, keys),
      maxSimultaneousDrags: icon.editor == null ? 1 : 0,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () => _dragStarted(icon.key, keys),
      onDragEnd: (_) => _dragEnded(),
      feedback: ValueListenableBuilder(
        valueListenable: _outside,
        builder: (context, outside, _) => outside
            ? const SizedBox.shrink()
            : Transform.translate(
                offset: Offset(-cell.width / 2, -cell.height / 2),
                child: SizedBox.fromSize(
                  size: cell,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Opacity(
                      opacity: 0.8,
                      child: _ItemBody(
                        icon: icon,
                        iconSize: widget.iconSize,
                        accent: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
      ),
      child: item,
    );
  }
}

/// O item como imagem, com a bolinha de quantos vão quando são vários.
Future<Uint8List?> _renderDragImage(
  RenderRepaintBoundary box,
  int count,
  Color accent,
) async {
  try {
    final item = await box.toImage();
    var image = item;
    if (count > 1) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawImage(item, Offset.zero, Paint());
      const radius = 11.0;
      final center = Offset(item.width - radius, radius);
      canvas.drawCircle(center, radius, Paint()..color = accent);
      final text =
          (ui.ParagraphBuilder(
                  ui.ParagraphStyle(
                    textAlign: TextAlign.center,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                )
                ..pushStyle(ui.TextStyle(color: PsitoPalette.dark.shadow))
                ..addText('$count'))
              .build()
            ..layout(const ui.ParagraphConstraints(width: radius * 2));
      canvas.drawParagraph(text, center - Offset(radius, text.height / 2));
      image = await recorder.endRecording().toImage(item.width, item.height);
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (!identical(image, item)) image.dispose();
    item.dispose();
    return data?.buffer.asUint8List();
  } on Object catch (e) {
    // Fica o ícone padrão do arrastar
    debugPrint('🦜 mesa: sem a imagem do arrastar ($e)');
    return null;
  }
}

class _Item extends StatelessWidget {
  final DeskIcon icon;
  final double iconSize;
  final bool selected;
  final bool expanded;

  /// A mesa tem o teclado; sem ele, a seleção fica apagada.
  final bool active;

  /// Está sendo arrastado.
  final bool ghost;
  final GlobalKey boundary;
  final ValueChanged<Offset> onPress;
  final VoidCallback onRelease;
  final VoidCallback onOpen;
  final ValueChanged<Offset>? onMenu;

  const _Item({
    required this.icon,
    required this.iconSize,
    required this.selected,
    required this.expanded,
    required this.active,
    required this.ghost,
    required this.boundary,
    required this.onPress,
    required this.onRelease,
    required this.onOpen,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final accent = active
        ? Theme.of(context).colorScheme.primary
        : context.palette.neutral;
    final editor = icon.editor;
    // Seleciona já no apertar: um onTapDown esperaria o tempo do duplo clique.
    // Com o campo aberto, os cliques são dele
    return Listener(
      onPointerDown: editor != null
          ? null
          : (event) {
              if (event.buttons & kPrimaryButton != 0) onPress(event.position);
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
          child: RepaintBoundary(
            key: boundary,
            child: _ItemBody(
              icon: icon,
              iconSize: iconSize,
              accent: accent,
              selected: selected,
              expanded: expanded,
              ghost: ghost,
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemBody extends StatelessWidget {
  final DeskIcon icon;
  final double iconSize;
  final Color accent;
  final bool selected;
  final bool expanded;
  final bool ghost;

  const _ItemBody({
    required this.icon,
    required this.iconSize,
    required this.accent,
    this.selected = false,
    this.expanded = false,
    this.ghost = false,
  });

  List<Shadow> _shadow(BuildContext context) => [
    Shadow(
      color: context.palette.shadow,
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  @override
  Widget build(BuildContext context) => Padding(
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
            opacity: icon.dimmed || ghost ? 0.45 : 1,
            child: icon.icon(iconSize),
          ),
        ),
        const SizedBox(height: 3),
        icon.editor ??
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
                  color: context.palette.text,
                  shadows: selected ? null : _shadow(context),
                ),
              ),
            ),
      ],
    ),
  );
}
