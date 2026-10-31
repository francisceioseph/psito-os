// shell/lib/surfaces.dart
//
// As superfícies layer-shell que o runner cria (linux/runner/my_application.cc),
// uma view do Flutter em cada.
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// As que o runner cria; com `PSITO_SURFACES`, só as pedidas (medições).
enum Surface { background, topbar, dock, overlay, toasts, osd }

/// Teclado da sobreposição: o launcher pega o teclado todo; os painéis só
/// quando clicados. Passiva, ela só desenha (o ícone arrastado da dock), sem
/// teclado nem cliques.
enum OverlayKeyboard { exclusive, onDemand, passive }

class Surfaces {
  const Surfaces([this._channel = const MethodChannel('psito/surfaces')]);

  final MethodChannel _channel;

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
      });

  Future<void> hideOverlay() => _channel.invokeMethod('hideOverlay');

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
