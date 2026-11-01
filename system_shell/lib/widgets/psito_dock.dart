// system_shell/lib/widgets/psito_dock.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

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

  /// A borda da tela: na de baixo a fileira é horizontal; nas dos lados,
  /// vertical. Os pontos ficam virados para a borda, e o ícone cresce e
  /// pula para longe dela.
  final PsitoDockPosition position;

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
    this.position = PsitoDockPosition.bottom,
  });

  /// O quanto o ícone sob o mouse cresce. Ele cresce por cima do resto, sem
  /// mexer no tamanho da dock: a superfície não muda a cada movimento.
  static const magnifiedScale = 1.25;

  /// O espaço a mais, para longe da borda, que o ícone ampliado e o pulo
  /// ocupam além da dock.
  static double overflow(double iconSize) => iconSize * 0.4;

  /// A espessura da dock (o lado perpendicular à borda), sem a sombra.
  static double thickness(double iconSize) => iconSize + 2 * 8 + 2;

  /// O canto de onde o ícone cresce e o sentido do pulo.
  static Alignment edgeAlignment(PsitoDockPosition position) =>
      switch (position) {
        PsitoDockPosition.bottom => Alignment.bottomCenter,
        PsitoDockPosition.left => Alignment.centerLeft,
        PsitoDockPosition.right => Alignment.centerRight,
      };

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
    final vertical = widget.position.vertical;
    Widget gap(int index) {
      final open = widget.gap == index ? step : 0.0;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        width: vertical ? widget.iconSize : open,
        height: vertical ? open : widget.iconSize,
      );
    }

    final count = widget.tiles.length;
    return Container(
      padding: vertical
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.palette.shadow.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.highlighted
              ? accent
              : context.palette.text.withValues(alpha: 0.1),
          width: widget.highlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
            offset: switch (widget.position) {
              PsitoDockPosition.bottom => const Offset(0, 10),
              PsitoDockPosition.left => const Offset(-10, 0),
              PsitoDockPosition.right => const Offset(10, 0),
            },
          ),
        ],
      ),
      child: Flex(
        direction: vertical ? Axis.vertical : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0 && widget.separators.contains(i))
              _Separator(vertical: vertical),
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

          return Semantics(
            button: true,
            label: tile.entry.name,
            value: tile.badge > 0 ? '${tile.badge}' : null,
            child: GestureDetector(
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
                padding: widget.position.vertical
                    ? const EdgeInsets.symmetric(vertical: PsitoDock.tileMargin)
                    : const EdgeInsets.symmetric(
                        horizontal: PsitoDock.tileMargin,
                      ),
                // Como no macOS: o ícone sob o mouse cresce, a partir da borda
                child: AnimatedScale(
                  scale: isHovered && widget.magnification
                      ? PsitoDock.magnifiedScale
                      : 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: PsitoDock.edgeAlignment(widget.position),
                  child: (widget.wrapTile ?? _plain)(
                    tile,
                    _square(tile, widget.iconSize, isHovered),
                  ),
                ),
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
          color: isHovered ? app.color : context.palette.line,
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
          if (tile.running) _dots(tile, containerSize),
        ],
      ),
    );
    return _Bounce(
      active: tile.bouncing,
      direction: switch (widget.position) {
        PsitoDockPosition.bottom => const Offset(0, -1),
        PsitoDockPosition.left => const Offset(1, 0),
        PsitoDockPosition.right => const Offset(-1, 0),
      },
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

extension on _PsitoDockState {
  /// Os pontos das janelas, no lado do ícone virado para a borda.
  Widget _dots(DockTile tile, double size) {
    final vertical = widget.position.vertical;
    final dots = Flex(
      key: ValueKey('running-${tile.key}'),
      direction: vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < tile.windows.clamp(1, 2); i++)
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: tile.entry.color,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
    final inset = size * 0.06;
    return switch (widget.position) {
      PsitoDockPosition.bottom => Positioned(bottom: inset, child: dots),
      PsitoDockPosition.left => Positioned(left: inset, child: dots),
      PsitoDockPosition.right => Positioned(right: inset, child: dots),
    };
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
      color: context.palette.danger,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: context.palette.shadowSoft),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: context.palette.text,
      ),
    ),
  );
}

/// O pulo de um app abrindo: sobe e desce enquanto [active].
class _Bounce extends StatefulWidget {
  final bool active;
  final double height;

  /// Para onde ele pula (para longe da borda).
  final Offset direction;
  final Widget child;

  const _Bounce({
    required this.active,
    required this.height,
    required this.direction,
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
      return Transform.translate(offset: widget.direction * lift, child: child);
    },
    child: widget.child,
  );
}

class _Separator extends StatelessWidget {
  final bool vertical;

  const _Separator({this.vertical = false});

  @override
  Widget build(BuildContext context) {
    const across = (PsitoDock.separatorWidth - 1) / 2;
    return Container(
      width: vertical ? 32 : 1,
      height: vertical ? 1 : 32,
      margin: vertical
          ? const EdgeInsets.symmetric(vertical: across, horizontal: 4)
          : const EdgeInsets.symmetric(horizontal: across, vertical: 4),
      color: context.palette.line,
    );
  }
}
