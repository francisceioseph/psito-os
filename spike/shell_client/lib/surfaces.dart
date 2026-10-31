// spike/shell_client/lib/surfaces.dart
//
// As superfícies layer-shell que o runner cria (linux/runner/my_application.cc),
// uma view do Flutter em cada.
import 'package:flutter/services.dart';

enum Surface { background, topbar, dock, overlay }

/// Teclado da sobreposição: o launcher pega o teclado todo; os painéis só
/// quando clicados.
enum OverlayKeyboard { exclusive, onDemand }

class Surfaces {
  const Surfaces([this._channel = const MethodChannel('psito/surfaces')]);

  final MethodChannel _channel;

  /// O id da view de cada superfície.
  Future<Map<Surface, int>> viewIds() async {
    final ids = await _channel.invokeMapMethod<String, int>('surfaces') ?? {};
    return {for (final surface in Surface.values) surface: ?ids[surface.name]};
  }

  Future<void> showOverlay(OverlayKeyboard keyboard) => _channel.invokeMethod(
    'showOverlay',
    keyboard == OverlayKeyboard.exclusive ? 'exclusive' : 'on_demand',
  );

  Future<void> hideOverlay() => _channel.invokeMethod('hideOverlay');
}
