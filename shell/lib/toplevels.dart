// shell/lib/toplevels.dart
//
// As janelas abertas no compositor, pelo wlr-foreign-toplevel-management.
// O protocolo fica no runner (linux/runner/toplevels.cc), que conversa com o
// Dart pelo canal psito/toplevels.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class Toplevel {
  final int id;
  final String title;
  final String appId;
  final bool activated;
  final bool minimized;
  final bool maximized;

  const Toplevel({
    required this.id,
    this.title = '',
    this.appId = '',
    this.activated = false,
    this.minimized = false,
    this.maximized = false,
  });

  factory Toplevel.fromMap(Map<Object?, Object?> map) => Toplevel(
    id: map['id']! as int,
    title: map['title'] as String? ?? '',
    appId: map['appId'] as String? ?? '',
    activated: map['activated'] as bool? ?? false,
    minimized: map['minimized'] as bool? ?? false,
    maximized: map['maximized'] as bool? ?? false,
  );
}

class ToplevelList extends ChangeNotifier {
  ToplevelList({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('psito/toplevels');

  final MethodChannel _channel;

  /// Na ordem do foco: a ativada mais recente fica no fim.
  final _byId = <int, Toplevel>{};

  List<Toplevel> get windows => List.unmodifiable(_byId.values);

  Toplevel? get activated {
    for (final window in _byId.values) {
      if (window.activated) return window;
    }
    return null;
  }

  /// Passa a ouvir o runner e pega a lista atual.
  Future<void> start() async {
    _channel.setMethodCallHandler(handle);
    final current = await _channel.invokeListMethod<Object?>('list') ?? [];
    for (final map in current) {
      _apply(Toplevel.fromMap(map! as Map<Object?, Object?>));
    }
    notifyListeners();
  }

  /// Eventos do runner: `changed` (o estado inteiro de uma janela, a cada
  /// `done` do protocolo) e `closed`.
  @visibleForTesting
  Future<void> handle(MethodCall call) async {
    switch (call.method) {
      case 'changed':
        _apply(Toplevel.fromMap(call.arguments as Map<Object?, Object?>));
      case 'closed':
        _byId.remove(call.arguments as int);
      default:
        return;
    }
    notifyListeners();
  }

  void _apply(Toplevel window) {
    final previous = _byId[window.id];
    // Ganhou o foco agora: vai para o fim, como a mais recente
    if (window.activated && !(previous?.activated ?? false)) {
      _byId.remove(window.id);
    }
    _byId[window.id] = window;
  }

  Future<void> activate(int id) => _channel.invokeMethod('activate', id);

  Future<void> minimize(int id) =>
      _channel.invokeMethod('minimize', {'id': id, 'minimized': true});

  Future<void> close(int id) => _channel.invokeMethod('close', id);
}
