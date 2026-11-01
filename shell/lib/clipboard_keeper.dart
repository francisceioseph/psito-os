// shell/lib/clipboard_keeper.dart
//
// O canal do gerenciador da área de transferência (o lado C é o
// linux/runner/clipboard_keeper.cc).
import 'package:flutter/services.dart';
import 'package:system_shell/shell/clipboard_history.dart';

class ClipboardKeeper {
  const ClipboardKeeper([
    this._channel = const MethodChannel('psito/clipboard_keeper'),
  ]);

  final MethodChannel _channel;

  /// O que o sistema copia passa a chegar em [history].
  void listen(ClipboardHistory history) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'copied':
          history.copied({
            for (final MapEntry(:key, :value)
                in (call.arguments as Map).entries)
              key as String: value as Uint8List,
          });
        case 'skipped':
          history.skipped();
        case 'lost':
          history.lost();
      }
    });
  }

  Future<void> offer(Map<String, Uint8List> formats) async {
    try {
      await _channel.invokeMethod('offer', formats);
    } on MissingPluginException {
      // Sem o runner (nos testes)
    }
  }

  Future<void> clear() async {
    try {
      await _channel.invokeMethod('clear');
    } on MissingPluginException {
      // Sem o runner (nos testes)
    }
  }
}
