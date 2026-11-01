// shell/lib/idle.dart
//
// A inatividade do ext-idle-notify (`linux/runner/idle.cc`, canal psito/idle).
// É o compositor que conta, e ele respeita quem pede para a tela não apagar.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IdleWatcher {
  static const _channel = MethodChannel('psito/idle');

  VoidCallback? onIdle;
  int _minutes = 0;

  /// Avisa depois de [minutes] sem uso; 0 para de vigiar.
  Future<void> setMinutes(int minutes) async {
    if (minutes == _minutes) return;
    _minutes = minutes;
    _channel.setMethodCallHandler(handle);
    try {
      await _channel.invokeMethod<void>('watch', minutes * 60);
    } on MissingPluginException {
      debugPrint('🦜 sem o canal psito/idle');
    }
  }

  @visibleForTesting
  Future<void> handle(MethodCall call) async {
    if (call.method == 'idled') onIdle?.call();
  }
}
