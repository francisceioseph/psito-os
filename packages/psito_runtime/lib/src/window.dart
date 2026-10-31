// packages/psito_runtime/lib/src/window.dart
//
// A janela GTK do app, pelo runner (canal psito/window): título, tamanho e
// fechar. O lado C é o plugin (linux/psito_runtime_plugin.cc).
import 'package:flutter/services.dart';

/// O menor tamanho de janela em que todo app do Psito cabe.
const minWindowSize = Size(240, 160);

class AppWindow {
  final MethodChannel _channel;

  const AppWindow([this._channel = const MethodChannel('psito/window')]);

  Future<void> setTitle(String title) =>
      _channel.invokeMethod('setTitle', title);

  /// Tamanho inicial, nunca menor que [minWindowSize].
  Future<void> setSize(Size size) => _channel.invokeMethod('setSize', [
    size.width.clamp(minWindowSize.width, double.infinity).round(),
    size.height.clamp(minWindowSize.height, double.infinity).round(),
  ]);

  Future<void> close() => _channel.invokeMethod('close');
}
