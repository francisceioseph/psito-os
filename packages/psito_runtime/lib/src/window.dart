// packages/psito_runtime/lib/src/window.dart
//
// A janela GTK do app, pelo runner (canal psito/window): título, tamanho,
// fechar e o id da aplicação. O lado C é o plugin
// (linux/psito_runtime_plugin.cc).
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

  /// O `APPLICATION_ID` do runner, que é o id do `.desktop` do app. Null sem
  /// o plugin (nos testes).
  Future<String?> applicationId() async {
    try {
      return await _channel.invokeMethod<String>('applicationId');
    } on MissingPluginException {
      return null;
    }
  }
}
