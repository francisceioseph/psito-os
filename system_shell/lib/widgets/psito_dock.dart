// system_shell/lib/widgets/psito_dock.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shell/app_entry.dart';

/// Um ícone da dock: um app, uma pasta ou um arquivo. [key] identifica o
/// ícone nos callbacks.
class DockTile {
  final String key;
  final AppEntry entry;

  /// Quantas janelas abertas: um ponto embaixo do ícone, dois a partir de
  /// duas.
  final int windows;

  /// As notificações não lidas do app, numa bolinha no canto.
  final int badge;

  /// O app está abrindo: o ícone pula até a janela aparecer.
  final bool bouncing;

  const DockTile({
    required this.key,
    required this.entry,
    this.windows = 0,
    this.badge = 0,
    this.bouncing = false,
  });

  bool get running => windows > 0;
}

class PsitoDock extends StatefulWidget {
  final List<DockTile> tiles;

  /// Os índices dos ícones que têm um separador antes.
  final Set<int> separators;

  /// Onde um ícone arrastado vai cair: abre um espaço antes do ícone nesse
  /// índice (no fim, com o tamanho da lista).
  final int? gap;

  /// Algo de fora em cima da dock: a borda se destaca.
  final bool highlighted;

  /// O clique, com o retângulo do ícone (para a pilha de uma pasta).
  final void Function(String key, Rect rect) onTap;

  /// O clique direito, com o retângulo do ícone (para o menu).
  final void Function(String key, Rect rect)? onMenu;

  /// O começo do arrastar de um ícone, nas coordenadas da view. Quem chama
  /// segue o ponteiro dali em diante (o ícone pode sair da fileira).
  final void Function(String key, Offset position)? onDragStart;

  /// O lado de cada ícone (o `dockIconSize` das configurações).
  final double iconSize;

  /// O ícone sob o mouse cresce.
  final bool magnification;

  /// Põe algo em volta do quadrado de um ícone (sem a margem): o shell põe
  /// o alvo de soltar arquivos de cada app e da lixeira.
  final Widget Function(DockTile tile, Widget child)? wrapTile;

  const PsitoDock({
    super.key,
    required this.tiles,
    this.separators = const {},
    this.gap,
    this.highlighted = false,
    required this.onTap,
    this.onMenu,
    this.onDragStart,
    this.iconSize = 52,
    this.magnification = true,
    this.wrapTile,
  });

  /// A margem de cada lado de um ícone.
  static const tileMargin = 6.0;
  static const separatorWidth = 13.0;

  /// A largura que um ícone ocupa na fila.
  static double span(double iconSize) => iconSize + 2 * tileMargin;

  /// O centro de cada um de [count] ícones, sem espaço aberto nem ampliação,
  /// com a fila centrada em [centerX].
  static List<double> centers({
    required int count,
    Set<int> separators = const {},
    required double iconSize,
    required double centerX,
  }) {
    final step = span(iconSize);
    final seps = separators.where((i) => i > 0 && i < count).length;
    var left = centerX - (count * step + seps * separatorWidth) / 2;
    final result = <double>[];
    for (var i = 0; i < count; i++) {
      if (i > 0 && separators.contains(i)) left += separatorWidth;
      result.add(left + step / 2);
      left += step;
    }
    return result;
  }

  @override
  State<PsitoDock> createState() => _PsitoDockState();
}

class _PsitoDockState extends State<PsitoDock> {
  // O ícone com o mouse em cima
  String? _hovered;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final step = PsitoDock.span(widget.iconSize);
    Widget gap(int index) => AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: widget.gap == index ? step : 0,
      height: widget.iconSize,
    );
    final count = widget.tiles.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.highlighted
              ? accent
              : Colors.white.withValues(alpha: 0.1),
          width: widget.highlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0 && widget.separators.contains(i)) const _Separator(),
            gap(i),
            _tile(widget.tiles[i]),
          ],
          gap(count),
        ],
      ),
    );
  }

  Widget _tile(DockTile tile) {
    final isHovered = _hovered == tile.key;
    // Efeito de zoom estilo macOS (aumenta o ícone se o mouse estiver em cima)
    final containerSize = isHovered && widget.magnification
        ? widget.iconSize * 1.25
        : widget.iconSize;
    final drag = widget.onDragStart != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = tile.key),
      onExit: (_) => setState(() => _hovered = null),
      child: Builder(
        builder: (context) {
          Rect rect() {
            final box = context.findRenderObject()! as RenderBox;
            return box.localToGlobal(Offset.zero) & box.size;
          }

          return GestureDetector(
            onTap: () => widget.onTap(tile.key, rect()),
            onSecondaryTap: widget.onMenu == null
                ? null
                : () => widget.onMenu!(tile.key, rect()),
            onPanStart: drag
                ? (details) {
                    setState(() => _hovered = null);
                    widget.onDragStart!(tile.key, details.globalPosition);
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PsitoDock.tileMargin,
              ),
              child: (widget.wrapTile ?? _plain)(
                tile,
                _square(tile, containerSize, isHovered),
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _plain(DockTile tile, Widget child) => child;

  Widget _square(DockTile tile, double containerSize, bool isHovered) {
    final app = tile.entry;
    final square = AnimatedContainer(
      key: ValueKey('dock-${tile.key}'),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: app.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(containerSize * 0.3),
        border: Border.all(
          color: isHovered ? app.color : Colors.white24,
          width: isHovered ? 2.0 : 1.0,
        ),
        boxShadow: isHovered
            ? [
                BoxShadow(
                  color: app.color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          app.icon(containerSize * 0.55),
          if (tile.running)
            Positioned(
              bottom: containerSize * 0.06,
              child: Row(
                key: ValueKey('running-${tile.key}'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < tile.windows.clamp(1, 2); i++)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: app.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
    return _Bounce(
      active: tile.bouncing,
      // Cabe na margem de cima da superfície da dock
      height: widget.iconSize * 0.25,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          square,
          if (tile.badge > 0)
            Positioned(
              top: -5,
              right: -5,
              child: _Badge(key: ValueKey('badge-${tile.key}'), tile.badge),
            ),
        ],
      ),
    );
  }
}

/// O contador de não lidas, em vermelho, como no macOS.
class _Badge extends StatelessWidget {
  final int count;

  const _Badge(this.count, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
    padding: const EdgeInsets.symmetric(horizontal: 5),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFE53935),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.black26),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );
}

/// O pulo de um app abrindo: sobe e desce enquanto [active].
class _Bounce extends StatefulWidget {
  final bool active;
  final double height;
  final Widget child;

  const _Bounce({
    required this.active,
    required this.height,
    required this.child,
  });

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(_Bounce old) {
    super.didUpdateWidget(old);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      // Termina o pulo de agora, para não parar no ar
      _land();
    }
  }

  void _land() {
    _controller.animateTo(1).whenComplete(() {
      if (mounted && !widget.active) _controller.value = 0;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      // Meio seno: sobe e cai, com uma pausa curta no chão
      final t = (_controller.value / 0.8).clamp(0.0, 1.0);
      final lift = math.sin(t * math.pi) * widget.height;
      return Transform.translate(offset: Offset(0, -lift), child: child);
    },
    child: widget.child,
  );
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 32,
    margin: const EdgeInsets.symmetric(
      horizontal: (PsitoDock.separatorWidth - 1) / 2,
      vertical: 4,
    ),
    color: Colors.white24,
  );
}
