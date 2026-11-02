// shell/lib/displays.dart
//
// A configuração dos monitores. O runner fala com o compositor pelo
// wlr-output-management (linux/runner/outputs.cc, canal psito/outputs), e aqui
// fica o que guardar e o que aplicar: um monitor conhecido volta como estava em
// ~/.config/psito/monitors.json, e um novo vai à direita dos outros.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'surfaces.dart';

File defaultMonitorsFile([Map<String, String>? env]) {
  env ??= Platform.environment;
  final configHome = env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? '.'}/.config';
  return File('$configHome/psito/monitors.json');
}

@immutable
class OutputMode {
  final int width;
  final int height;

  /// Em milésimos de hertz, como no protocolo.
  final int refresh;
  final bool preferred;

  const OutputMode(
    this.width,
    this.height, {
    this.refresh = 60000,
    this.preferred = false,
  });

  factory OutputMode.fromMap(Map<Object?, Object?> map) => OutputMode(
    map['width']! as int,
    map['height']! as int,
    refresh: map['refresh'] as int? ?? 0,
    preferred: map['preferred'] as bool? ?? false,
  );

  bool sameAs(OutputMode other) =>
      width == other.width &&
      height == other.height &&
      refresh == other.refresh;
}

/// Um monitor conectado, ligado ou não. O nome é o do conector (`HDMI-A-1`).
@immutable
class OutputHead {
  final String name;
  final String make;
  final String model;
  final String serial;
  final bool enabled;
  final int x;
  final int y;
  final int transform;
  final double scale;
  final List<OutputMode> modes;
  final OutputMode? current;

  const OutputHead({
    required this.name,
    this.make = '',
    this.model = '',
    this.serial = '',
    this.enabled = true,
    this.x = 0,
    this.y = 0,
    this.transform = 0,
    this.scale = 1,
    this.modes = const [],
    this.current,
  });

  factory OutputHead.fromMap(Map<Object?, Object?> map) {
    final modes = [
      for (final mode in map['modes']! as List<Object?>)
        OutputMode.fromMap(mode! as Map<Object?, Object?>),
    ];
    final current = map['current'] as int? ?? -1;
    return OutputHead(
      name: map['name']! as String,
      make: map['make'] as String? ?? '',
      model: map['model'] as String? ?? '',
      serial: map['serial'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? false,
      x: map['x'] as int? ?? 0,
      y: map['y'] as int? ?? 0,
      transform: map['transform'] as int? ?? 0,
      scale: map['scale'] as double? ?? 1,
      modes: modes,
      current: current >= 0 && current < modes.length ? modes[current] : null,
    );
  }

  /// Quem é este monitor, em qualquer conector. Sem a série, dois iguais só se
  /// distinguem pelo conector.
  String get key => '$make|$model|${serial.isEmpty ? name : serial}';
}

/// A melhor forma de ligar um monitor novo: o tamanho que ele prefere, na maior
/// frequência. Sem preferência, o maior.
OutputMode? bestMode(List<OutputMode> modes) {
  if (modes.isEmpty) return null;
  final size =
      modes.where((m) => m.preferred).firstOrNull ??
      modes.reduce((a, b) => b.width * b.height > a.width * a.height ? b : a);
  return modes
      .where((m) => m.width == size.width && m.height == size.height)
      .reduce((a, b) => b.refresh > a.refresh ? b : a);
}

/// O que um monitor deve ser. É também o que fica guardado.
@immutable
class OutputConfig {
  final bool enabled;
  final OutputMode? mode;
  final int x;
  final int y;
  final int transform;
  final double scale;

  const OutputConfig({
    this.enabled = true,
    this.mode,
    this.x = 0,
    this.y = 0,
    this.transform = 0,
    this.scale = 1,
  });

  OutputConfig at(int x, int y) => OutputConfig(
    enabled: enabled,
    mode: mode,
    x: x,
    y: y,
    transform: transform,
    scale: scale,
  );

  /// O retângulo no layout, em pixels lógicos: a rotação troca os lados.
  Rect get rect {
    final mode = this.mode;
    if (mode == null) return Rect.fromLTWH(x.toDouble(), y.toDouble(), 0, 0);
    final sideways = transform.isOdd;
    return Rect.fromLTWH(
      x.toDouble(),
      y.toDouble(),
      (sideways ? mode.height : mode.width) / scale,
      (sideways ? mode.width : mode.height) / scale,
    );
  }

  bool matches(OutputHead head) {
    if (enabled != head.enabled) return false;
    if (!enabled) return true;
    final mode = this.mode;
    final current = head.current;
    // Sem modo nenhum para pedir, fica como está
    if (mode == null) return true;
    return current != null &&
        mode.sameAs(current) &&
        x == head.x &&
        y == head.y &&
        transform == head.transform &&
        scale == head.scale;
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    if (mode case final mode?) ...{
      'width': mode.width,
      'height': mode.height,
      'refresh': mode.refresh,
    },
    'x': x,
    'y': y,
    'transform': transform,
    'scale': scale,
  };

  /// [mode] fica sem frequência quando o arquivo não diz: vale a maior.
  factory OutputConfig.fromJson(Map<String, Object?> json) => OutputConfig(
    enabled: json['enabled'] as bool? ?? true,
    mode: switch (json) {
      {'width': final int width, 'height': final int height} => OutputMode(
        width,
        height,
        refresh: json['refresh'] as int? ?? 0,
      ),
      _ => null,
    },
    x: json['x'] as int? ?? 0,
    y: json['y'] as int? ?? 0,
    transform: json['transform'] as int? ?? 0,
    scale: (json['scale'] as num?)?.toDouble() ?? 1,
  );
}

/// O que `monitors.json` guarda: cada monitor pela [OutputHead.key], e qual é o
/// principal.
class MonitorStore {
  /// Null: só em memória (testes).
  final File? file;
  final Map<String, OutputConfig> _monitors;
  String? _primary;

  MonitorStore._(this._monitors, this._primary, this.file);

  MonitorStore.memory({
    Map<String, OutputConfig> monitors = const {},
    String? primary,
  }) : this._({...monitors}, primary, null);

  static Future<MonitorStore> load(File file) async {
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is Map<String, Object?>) {
        final monitors = json['monitors'];
        return MonitorStore._(
          {
            if (monitors is Map<String, Object?>)
              for (final MapEntry(:key, :value) in monitors.entries)
                if (value is Map<String, Object?>)
                  key: OutputConfig.fromJson(value),
          },
          json['primary'] as String?,
          file,
        );
      }
      debugPrint('🦜 ${file.path} não é um objeto; vale o padrão');
    } on PathNotFoundException {
      // A primeira vez
    } catch (e) {
      debugPrint('🦜 Erro lendo ${file.path}: $e; vale o padrão');
    }
    return MonitorStore._({}, null, file);
  }

  String? get primary => _primary;

  OutputConfig? operator [](String key) => _monitors[key];

  Future<void> setPrimary(String key) {
    _primary = key;
    return _save();
  }

  Future<void> put(Map<String, OutputConfig> monitors) {
    _monitors.addAll(monitors);
    return _save();
  }

  Future<void> _saving = Future.value();

  // Uma gravação de cada vez, num .tmp que depois é renomeado
  Future<void> _save() => _saving = _saving.then((_) => _write());

  Future<void> _write() async {
    final file = this.file;
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'primary': ?_primary,
          'monitors': {
            for (final MapEntry(:key, :value) in _monitors.entries)
              key: value.toJson(),
          },
        }),
      );
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('🦜 Erro gravando ${file.path}: $e');
    }
  }
}

/// O modo guardado, se o monitor ainda tiver: a mesma frequência, ou a maior
/// naquele tamanho.
OutputMode? _savedMode(OutputHead head, OutputMode? saved) {
  if (saved == null) return bestMode(head.modes);
  final sameSize = head.modes.where(
    (m) => m.width == saved.width && m.height == saved.height,
  );
  if (sameSize.isEmpty) return bestMode(head.modes);
  return sameSize.where((m) => m.refresh == saved.refresh).firstOrNull ??
      sameSize.reduce((a, b) => b.refresh > a.refresh ? b : a);
}

/// O que cada monitor conectado deve ser, pelo nome do conector.
///
/// Quem está guardado volta como estava. Quem não está fica como o compositor
/// deixou (um desligado continua desligado), na melhor forma, à direita dos
/// outros. Sempre sobra um ligado, e o layout começa em 0,0.
Map<String, OutputConfig> planOutputs(
  List<OutputHead> heads,
  MonitorStore store,
) {
  final plan = <String, OutputConfig>{};
  double right() => plan.values
      .where((c) => c.enabled)
      .fold(0, (edge, c) => c.rect.right > edge ? c.rect.right : edge);
  bool overlaps(OutputConfig config) => plan.values.any(
    // Dois no mesmo retângulo estão espelhados, de propósito
    (c) => c.enabled && c.rect != config.rect && c.rect.overlaps(config.rect),
  );

  for (final head in heads) {
    final saved = store[head.key];
    if (saved == null) continue;
    final config = OutputConfig(
      enabled: saved.enabled,
      mode: _savedMode(head, saved.mode),
      x: saved.x,
      y: saved.y,
      transform: saved.transform,
      scale: saved.scale,
    );
    plan[head.name] = saved.enabled && overlaps(config)
        ? config.at(right().ceil(), 0)
        : config;
  }
  for (final head in heads) {
    if (store[head.key] != null) continue;
    plan[head.name] = OutputConfig(
      enabled: head.enabled,
      mode: head.enabled ? bestMode(head.modes) : head.current,
      x: right().ceil(),
      transform: head.transform,
      scale: head.scale,
    );
  }

  if (heads.isNotEmpty && !plan.values.any((c) => c.enabled)) {
    final head = heads.firstWhere(
      (h) => h.modes.isNotEmpty,
      orElse: () => heads.first,
    );
    plan[head.name] = OutputConfig(mode: bestMode(head.modes));
  }

  final enabled = plan.values.where((c) => c.enabled);
  if (enabled.isEmpty) return plan;
  final left = enabled.map((c) => c.x).reduce((a, b) => a < b ? a : b);
  final top = enabled.map((c) => c.y).reduce((a, b) => a < b ? a : b);
  return {
    for (final MapEntry(:key, :value) in plan.entries)
      key: value.enabled ? value.at(value.x - left, value.y - top) : value,
  };
}

/// Os monitores do compositor, e quem manda neles: um conjunto novo de monitores
/// conectados é arrumado uma vez, e uma mudança de fora (o `wlr-randr`) fica até
/// o próximo.
class Displays {
  Displays({
    required this.surfaces,
    required this.store,
    this._channel = const MethodChannel('psito/outputs'),
  });

  final Surfaces surfaces;
  final MonitorStore store;
  final MethodChannel _channel;

  final heads = ValueNotifier<List<OutputHead>>(const []);

  String? _connected;
  bool _arranging = false;
  bool _arrangeAgain = false;

  Future<void> start() async {
    surfaces.monitors.addListener(_syncPrimary);
    _channel.setMethodCallHandler(handle);
    _update(await _channel.invokeMethod('list'));
  }

  /// Eventos do runner: `changed`, com a lista inteira a cada `done`.
  @visibleForTesting
  Future<void> handle(MethodCall call) async {
    if (call.method == 'changed') _update(call.arguments);
  }

  void _update(Object? list) {
    heads.value = [
      for (final map in (list as List<Object?>?) ?? const [])
        OutputHead.fromMap(map! as Map<Object?, Object?>),
    ];
    final connected = (heads.value.map((h) => h.key).toList()..sort()).join(
      '\n',
    );
    if (connected != _connected) {
      _connected = connected;
      unawaited(_arrange());
    } else {
      _syncPrimary();
    }
  }

  Future<void> _arrange() async {
    if (_arranging) {
      _arrangeAgain = true;
      return;
    }
    _arranging = true;
    var attempts = 0;
    do {
      _arrangeAgain = false;
      final plan = planOutputs(heads.value, store);
      if (heads.value.every((h) => plan[h.name]?.matches(h) ?? true)) break;
      final result = await _apply(plan);
      if (result == 'cancelled') {
        // O compositor mudou no meio: vale o que vier agora
        _arrangeAgain = true;
      } else if (result != 'ok') {
        debugPrint('🦜 O compositor recusou os monitores ($result)');
      }
      // O "cancelled" também é um modo que sumiu: não insiste para sempre
    } while (_arrangeAgain && ++attempts < 3);
    _arranging = false;
    _syncPrimary();
  }

  Future<String> _apply(
    Map<String, OutputConfig> plan, {
    bool test = false,
  }) async =>
      await _channel.invokeMethod<String>('apply', {
        'test': test,
        'heads': [
          for (final MapEntry(:key, :value) in plan.entries)
            if (!value.enabled || value.mode != null)
              {'name': key, ...value.toJson()},
        ],
      }) ??
      'failed';

  /// Pede ao compositor e, se valer, guarda. Com [test], só pergunta se ele
  /// aceitaria.
  Future<String> configure(
    Map<String, OutputConfig> plan, {
    bool test = false,
  }) async {
    final result = await _apply(plan, test: test);
    if (result == 'ok' && !test) {
      await store.put({
        for (final head in heads.value) head.key: ?plan[head.name],
      });
    }
    return result;
  }

  // O protocolo dos monitores e o GDK não têm um nome em comum: o que os liga é
  // o lugar no layout
  Monitor? _monitorOf(OutputHead head) => surfaces.monitors.value
      .where(
        (m) =>
            m.rect.left == head.x.toDouble() && m.rect.top == head.y.toDouble(),
      )
      .firstOrNull;

  OutputHead? _headOf(Monitor monitor) => heads.value
      .where(
        (h) =>
            h.enabled &&
            monitor.rect.left == h.x.toDouble() &&
            monitor.rect.top == h.y.toDouble(),
      )
      .firstOrNull;

  /// O principal guardado volta a ser o principal assim que estiver ligado. Sem
  /// nenhum guardado, vale o de agora.
  void _syncPrimary() {
    if (_arranging) return;
    final key = store.primary;
    if (key == null) {
      for (final monitor in surfaces.monitors.value) {
        if (!monitor.primary) continue;
        if (_headOf(monitor) case final head?) {
          unawaited(store.setPrimary(head.key));
        }
      }
      return;
    }
    for (final head in heads.value) {
      if (head.key != key || !head.enabled) continue;
      final monitor = _monitorOf(head);
      if (monitor != null && !monitor.primary) {
        unawaited(surfaces.setPrimary(monitor.id));
      }
    }
  }

  /// Escolhe o principal e guarda. False se o monitor não estiver ligado.
  Future<bool> setPrimaryMonitor(int id) async {
    final monitor = surfaces.monitors.value
        .where((m) => m.id == id)
        .firstOrNull;
    if (monitor == null) return false;
    if (_headOf(monitor) case final head?) await store.setPrimary(head.key);
    return surfaces.setPrimary(id);
  }
}
