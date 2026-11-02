// shell/lib/surfaces.dart
//
// As superfícies layer-shell que o runner cria (linux/runner/my_application.cc),
// uma view do Flutter em cada.
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:psito_sdk/psito_sdk.dart';

/// As que o runner cria; com `PSITO_SURFACES`, só as pedidas (medições).
enum Surface { background, topbar, dock, overlay, toasts, osd }

/// Teclado da sobreposição: o launcher pega o teclado todo; os painéis só
/// quando clicados. Passiva, ela só desenha (o ícone arrastado da dock), sem
/// teclado nem cliques. Com o ponteiro, ela recebe os cliques e o teclado fica
/// onde estava (o menu da mesa).
enum OverlayKeyboard { exclusive, onDemand, passive, pointer }

/// O fundo e a top bar de um monitor além do principal.
class SecondaryViews {
  final int id;
  final int background;
  final int topbar;

  const SecondaryViews({
    required this.id,
    required this.background,
    required this.topbar,
  });

  factory SecondaryViews.fromMap(Map<Object?, Object?> map) => SecondaryViews(
    id: map['id']! as int,
    background: map['background']! as int,
    topbar: map['topbar']! as int,
  );
}

/// Um monitor ligado. O [id] dura enquanto ele está ligado: voltar dá outro.
@immutable
class Monitor {
  final int id;
  final Rect rect;
  final int scale;
  final String model;
  final bool primary;

  const Monitor({
    required this.id,
    required this.rect,
    this.scale = 1,
    this.model = '',
    this.primary = false,
  });

  factory Monitor.fromMap(Map<Object?, Object?> map) => Monitor(
    id: map['id']! as int,
    rect: Rect.fromLTWH(
      (map['x']! as int).toDouble(),
      (map['y']! as int).toDouble(),
      (map['width']! as int).toDouble(),
      (map['height']! as int).toDouble(),
    ),
    scale: map['scale'] as int? ?? 1,
    model: map['model'] as String? ?? '',
    primary: map['primary'] as bool? ?? false,
  );
}

class Surfaces {
  Surfaces([this._channel = const MethodChannel('psito/surfaces')]);

  final MethodChannel _channel;
  ValueChanged<bool>? _backgroundFocus;

  /// As views dos monitores além do principal. O runner cria quando um monitor
  /// liga, e guarda, escondidas, quando ele sai.
  final secondaries = ValueNotifier<List<SecondaryViews>>(const []);

  /// Os monitores ligados, da esquerda para a direita, como estão no layout.
  final monitors = ValueNotifier<List<Monitor>>(const []);

  static List<Monitor> _parseMonitors(Object? list) => [
    for (final map in (list as List<Object?>?) ?? const [])
      Monitor.fromMap(map! as Map<Object?, Object?>),
  ]..sort(_byPosition);

  static int _byPosition(Monitor a, Monitor b) {
    final x = a.rect.left.compareTo(b.rect.left);
    return x != 0 ? x : a.rect.top.compareTo(b.rect.top);
  }

  /// O número de um monitor para quem usa, contado no layout, a partir de 1.
  /// Null se ele não estiver ligado.
  int? screenNumber(int id) {
    final index = monitors.value.indexWhere((m) => m.id == id);
    return index < 0 ? null : index + 1;
  }

  /// Leva a dock, a mesa e as sobreposições para o monitor [id]. O principal
  /// de agora fica com o fundo e a top bar. False se ele não estiver ligado.
  Future<bool> setPrimary(int id) async =>
      await _channel.invokeMethod<bool>('setPrimary', id) ?? false;

  static List<SecondaryViews> _parse(Object? list) => [
    for (final map in (list as List<Object?>?) ?? const [])
      SecondaryViews.fromMap(map! as Map<Object?, Object?>),
  ];

  /// Passa a ouvir o runner e pega os monitores de agora.
  Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'backgroundFocus':
          _backgroundFocus?.call(call.arguments as bool);
        case 'secondaries':
          secondaries.value = _parse(call.arguments);
        case 'monitors':
          monitors.value = _parseMonitors(call.arguments);
      }
    });
    secondaries.value = _parse(await _channel.invokeMethod('secondaries'));
    monitors.value = _parseMonitors(await _channel.invokeMethod('monitors'));
  }

  /// O fundo ganhou ou perdeu o teclado.
  void onBackgroundFocus(ValueChanged<bool> listener) {
    _backgroundFocus = listener;
  }

  /// O id da view de cada superfície.
  Future<Map<Surface, int>> viewIds() async {
    final ids = await _channel.invokeMapMethod<String, int>('surfaces') ?? {};
    return {for (final surface in Surface.values) surface: ?ids[surface.name]};
  }

  Future<void> showOverlay(OverlayKeyboard keyboard) =>
      _channel.invokeMethod('showOverlay', switch (keyboard) {
        OverlayKeyboard.exclusive => 'exclusive',
        OverlayKeyboard.onDemand => 'on_demand',
        OverlayKeyboard.passive => 'passive',
        OverlayKeyboard.pointer => 'pointer',
      });

  Future<void> hideOverlay() => _channel.invokeMethod('hideOverlay');

  /// A borda em que a dock fica e quanto ela reserva da tela (a zona
  /// exclusiva; 0 com o ocultar sozinha).
  Future<void> dock(PsitoDockPosition edge, int exclusive) => _channel
      .invokeMethod('dock', {'edge': edge.name, 'exclusive': exclusive});

  /// Os toasts e o OSD, que só existem enquanto têm algo na tela.
  Future<void> show(Surface surface) =>
      _channel.invokeMethod('show', surface.name);

  Future<void> hide(Surface surface) =>
      _channel.invokeMethod('hide', surface.name);

  /// O tamanho da superfície, para as que têm o tamanho do conteúdo (dock,
  /// toasts e OSD), em pixels lógicos. [input] é a borda que fica fora da
  /// região de input (o espaço da sombra).
  Future<void> resize(
    Surface surface,
    Size size, {
    EdgeInsets input = EdgeInsets.zero,
  }) => _channel.invokeMethod('resize', {
    'surface': surface.name,
    'width': size.width.ceil(),
    'height': size.height.ceil(),
    'input': [
      input.left.floor(),
      input.top.floor(),
      input.right.floor(),
      input.bottom.floor(),
    ],
  });
}
