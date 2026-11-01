// packages/psito_runtime/lib/src/dnd.dart
//
// Arrastar e soltar arquivos entre processos, pelo canal psito/dnd (o lado C
// é o linux/psito_dnd.cc). O PsitoDropTarget recebe o que vem de fora da
// view, e o PsitoDnd.startDrag leva arquivos para fora dela.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum DropAction { copy, move, link }

/// Os caminhos dos `file://` de [uris]; o resto fica de fora.
List<String> filePaths(Iterable<String> uris) => [
  for (final uri in uris)
    if (Uri.tryParse(uri.trim()) case final parsed?
        when parsed.isScheme('file'))
      parsed.toFilePath(),
];

class PsitoDnd {
  PsitoDnd._(this._channel) {
    _channel.setMethodCallHandler(_handle);
  }

  static final instance = PsitoDnd._(const MethodChannel('psito/dnd'));

  final MethodChannel _channel;
  final _targets = <int, Set<_PsitoDropTargetState>>{};
  final _hovered = <int, _PsitoDropTargetState>{};

  /// As views em que um arrastar que começou nelas acabou de terminar.
  final _ended = StreamController<int>.broadcast();
  Stream<int> get dragEnded => _ended.stream;

  /// Avisa o shell do que vai ser arrastado: um app no sandbox que receber
  /// esses arquivos só consegue abrir com a oferta (o org.psito.Launcher).
  void Function(List<String> paths)? onOffer;

  /// Leva [paths] para fora da view [viewId]. Só funciona com o botão ainda
  /// apertado: o arrastar do Wayland começa pelo clique. [icon] é um PNG que
  /// o compositor desenha embaixo do ponteiro, pego em [hotspot] (sem ele, o
  /// ícone padrão do GTK).
  Future<void> startDrag(
    int viewId,
    List<String> paths, {
    Uint8List? icon,
    Offset hotspot = Offset.zero,
  }) async {
    onOffer?.call(paths);
    try {
      await _channel.invokeMethod('startDrag', {
        'view': viewId,
        'uris': [for (final path in paths) Uri.file(path).toString()],
        if (icon != null) ...{
          'icon': icon,
          'x': hotspot.dx.round(),
          'y': hotspot.dy.round(),
        },
      });
    } on MissingPluginException {
      // Sem o plugin (nos testes e no laboratório sem o runtime)
    }
  }

  void _add(int view, _PsitoDropTargetState target) =>
      _targets.putIfAbsent(view, () => {}).add(target);

  void _remove(int view, _PsitoDropTargetState target) {
    _targets[view]?.remove(target);
    if (_hovered[view] == target) _hovered.remove(view);
  }

  /// O alvo mais de dentro em [position], entre os montados na view.
  _PsitoDropTargetState? _hit(int view, Offset position) {
    _PsitoDropTargetState? best;
    double? bestArea;
    for (final target in _targets[view] ?? const <_PsitoDropTargetState>{}) {
      final box = target.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (!rect.contains(position)) continue;
      final area = rect.width * rect.height;
      if (bestArea == null || area < bestArea) {
        best = target;
        bestArea = area;
      }
    }
    return best;
  }

  void _hover(int view, _PsitoDropTargetState? target) {
    final old = _hovered[view];
    if (old == target) return;
    old?._setHovering(false);
    if (target == null) {
      _hovered.remove(view);
    } else {
      _hovered[view] = target;
    }
  }

  Future<Object?> _handle(MethodCall call) async {
    final args = call.arguments as Map;
    final view = args['view'] as int;
    switch (call.method) {
      case 'leave':
        _hover(view, null);
        return null;
      case 'dragEnd':
        _ended.add(view);
        return null;
    }
    final position = Offset(
      (args['x'] as int).toDouble(),
      (args['y'] as int).toDouble(),
    );
    final paths = filePaths((args['uris'] as List).cast<String>());
    final target = paths.isEmpty ? null : _hit(view, position);
    switch (call.method) {
      case 'over':
        _hover(view, target);
        final action = target?.widget.onWillAccept(paths);
        target?._setHovering(action != null);
        return action?.name;
      case 'drop':
        _hover(view, null);
        if (target == null || target.widget.onWillAccept(paths) == null) {
          return false;
        }
        final action = DropAction.values.byName(args['action'] as String);
        return await target.widget.onAccept(paths, action, position);
    }
    return null;
  }
}

/// Onde arquivos de fora da view podem ser soltos. [onWillAccept] diz com que
/// ação (null recusa); o mais de dentro, entre os alvos sobrepostos, decide.
/// O [onAccept] recebe o ponto do soltar, nas coordenadas da view.
class PsitoDropTarget extends StatefulWidget {
  final DropAction? Function(List<String> paths) onWillAccept;
  final FutureOr<bool> Function(
    List<String> paths,
    DropAction action,
    Offset position,
  )
  onAccept;
  final Widget Function(BuildContext context, bool hovering) builder;

  const PsitoDropTarget({
    super.key,
    required this.onWillAccept,
    required this.onAccept,
    required this.builder,
  });

  @override
  State<PsitoDropTarget> createState() => _PsitoDropTargetState();
}

class _PsitoDropTargetState extends State<PsitoDropTarget> {
  int? _view;
  bool _hovering = false;

  void _setHovering(bool value) {
    if (mounted && value != _hovering) setState(() => _hovering = value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final view = View.of(context).viewId;
    if (view == _view) return;
    if (_view case final old?) PsitoDnd.instance._remove(old, this);
    _view = view;
    PsitoDnd.instance._add(view, this);
  }

  @override
  void dispose() {
    if (_view case final view?) PsitoDnd.instance._remove(view, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _hovering);
}
