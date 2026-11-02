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
import 'package:psito_sdk/psito_sdk.dart';

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

  PsitoDisplayMode toDisplay() =>
      PsitoDisplayMode(width, height, refresh: refresh, preferred: preferred);

  bool sameAs(OutputMode other) =>
      width == other.width &&
      height == other.height &&
      refresh == other.refresh;
}

extension on PsitoDisplayMode {
  OutputMode toOutput() => OutputMode(width, height, refresh: refresh);
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

  /// Para mostrar. Sem fabricante nem modelo, o conector.
  String get label {
    final label = [make, model].where((s) => s.isNotEmpty).join(' ');
    return label.isEmpty ? name : label;
  }

  /// Como está agora.
  OutputConfig get config => OutputConfig(
    enabled: enabled,
    mode: current,
    x: x,
    y: y,
    transform: transform,
    scale: scale,
  );

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
      // O compositor corta a fração
      ((sideways ? mode.height : mode.width) / scale).floorToDouble(),
      ((sideways ? mode.width : mode.height) / scale).floorToDouble(),
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

  return _fromOrigin(plan);
}

/// O layout começa em 0,0.
Map<String, OutputConfig> _fromOrigin(Map<String, OutputConfig> plan) {
  final enabled = plan.values.where((c) => c.enabled);
  if (enabled.isEmpty) return plan;
  final left = enabled.map((c) => c.x).reduce((a, b) => a < b ? a : b);
  final top = enabled.map((c) => c.y).reduce((a, b) => a < b ? a : b);
  return {
    for (final MapEntry(:key, :value) in plan.entries)
      key: value.enabled ? value.at(value.x - left, value.y - top) : value,
  };
}

/// A configuração nova, esperando quem diga se fica. Sem resposta, volta sozinha.
class DisplaysConfirm extends ChangeNotifier {
  final VoidCallback keep;
  final VoidCallback revert;
  int secondsLeft;

  DisplaysConfirm({
    required this.keep,
    required this.revert,
    this.secondsLeft = Displays.confirmSeconds,
  });

  void tick() {
    secondsLeft--;
    notifyListeners();
  }
}

/// Os monitores do compositor, e quem manda neles: um conjunto novo de monitores
/// conectados é arrumado uma vez, e uma mudança de fora (o `wlr-randr`) fica até
/// o próximo.
class Displays implements PsitoDisplays {
  static const confirmSeconds = 15;

  Displays({
    required this.surfaces,
    required this.store,
    ValueNotifier<DisplaysConfirm?>? confirm,
    this.confirmTick = const Duration(seconds: 1),
    this._channel = const MethodChannel('psito/outputs'),
  }) : confirm = confirm ?? ValueNotifier(null);

  final Surfaces surfaces;
  final MonitorStore store;
  final MethodChannel _channel;

  /// O que o shell desenha, na sobreposição.
  final ValueNotifier<DisplaysConfirm?> confirm;

  /// Um segundo da contagem.
  final Duration confirmTick;

  final heads = ValueNotifier<List<OutputHead>>(const []);
  final _displays = ValueNotifier<List<PsitoDisplay>>(const []);

  @override
  ValueListenable<List<PsitoDisplay>> get displays => _displays;

  String? _connected;
  bool _arranging = false;
  bool _arrangeAgain = false;
  bool _applying = false;
  Timer? _confirmTimer;

  Future<void> start() async {
    surfaces.monitors.addListener(_monitorsChanged);
    _channel.setMethodCallHandler(handle);
    _update(await _channel.invokeMethod('list'));
  }

  /// Eventos do runner: `changed`, com a lista inteira a cada `done`.
  @visibleForTesting
  Future<void> handle(MethodCall call) async {
    if (call.method == 'changed') _update(call.arguments);
  }

  void _monitorsChanged() {
    _publish();
    _syncPrimary();
  }

  void _publish() {
    _displays.value = [
      for (final head in heads.value)
        PsitoDisplay(
          name: head.name,
          label: head.label,
          enabled: head.enabled,
          primary: _monitorOf(head)?.primary ?? false,
          x: head.x,
          y: head.y,
          transform: head.transform,
          scale: head.scale,
          mode: head.current?.toDisplay(),
          modes: [for (final mode in head.modes) mode.toDisplay()],
        ),
    ];
  }

  void _update(Object? list) {
    heads.value = [
      for (final map in (list as List<Object?>?) ?? const [])
        OutputHead.fromMap(map! as Map<Object?, Object?>),
    ];
    _publish();
    final connected = (heads.value.map((h) => h.key).toList()..sort()).join(
      '\n',
    );
    if (connected != _connected) {
      _connected = connected;
      // Quem esperava a confirmação não vale mais: volta o guardado
      _closeConfirm();
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
      final result = await _applyPinned(plan);
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

  /// Aplica sem o compositor mexer em quem fica no lugar. O monitor que ele
  /// mesmo posicionou continua automático (`wlr_output_layout_add_auto`) enquanto
  /// não pedirem outra posição, e o labwc não pede a que ele já tem: ao mover o
  /// vizinho, ele iria para a direita de todos. Um pixel ao lado antes fixa todos.
  Future<String> _applyPinned(Map<String, OutputConfig> plan) async {
    bool same(OutputHead h) {
      final config = plan[h.name];
      return config != null && config.x == h.x && config.y == h.y;
    }

    final enabled = heads.value.where(
      (h) => h.enabled && (plan[h.name]?.enabled ?? false),
    );
    if (enabled.any(same) && !enabled.every(same)) {
      final result = await _apply({
        for (final MapEntry(:key, :value) in plan.entries)
          key: value.at(value.x + 1, value.y),
      });
      if (result != 'ok') return result;
    }
    return _apply(plan);
  }

  /// Testa e aplica. Só fica guardado com o [DisplaysConfirm.keep]: até lá, o
  /// tempo, o outro botão ou o shell reiniciado voltam para o de antes.
  @override
  Future<PsitoDisplaysResult> apply(List<PsitoDisplay> displays) async {
    if (confirm.value != null || _arranging || _applying) {
      return PsitoDisplaysResult.busy;
    }
    final names = {for (final head in heads.value) head.name};
    final plan = _fromOrigin({
      for (final display in displays)
        if (names.contains(display.name))
          display.name: OutputConfig(
            enabled: display.enabled,
            mode: display.mode?.toOutput(),
            x: display.x,
            y: display.y,
            transform: display.transform,
            scale: display.scale,
          ),
    });
    if (!plan.values.any((c) => c.enabled && c.mode != null)) {
      return PsitoDisplaysResult.failed;
    }
    if (heads.value.every((h) => plan[h.name]?.matches(h) ?? true)) {
      return PsitoDisplaysResult.ok;
    }
    final before = {for (final head in heads.value) head.name: head.config};
    _applying = true;
    try {
      if (await _apply(plan, test: true) != 'ok' ||
          await _applyPinned(plan) != 'ok') {
        return PsitoDisplaysResult.failed;
      }
    } finally {
      _applying = false;
    }
    _askConfirm(plan, before);
    return PsitoDisplaysResult.ok;
  }

  void _askConfirm(
    Map<String, OutputConfig> plan,
    Map<String, OutputConfig> before,
  ) {
    void revert() {
      _closeConfirm();
      unawaited(
        _applyPinned(before).then((result) {
          if (result != 'ok') {
            debugPrint('🦜 Sem voltar a configuração dos monitores ($result)');
          }
        }),
      );
    }

    final request = DisplaysConfirm(
      keep: () {
        _closeConfirm();
        unawaited(
          store.put({
            for (final head in heads.value) head.key: ?plan[head.name],
          }),
        );
      },
      revert: revert,
    );
    confirm.value = request;
    _confirmTimer = Timer.periodic(confirmTick, (_) {
      request.tick();
      if (request.secondsLeft <= 0) revert();
    });
  }

  void _closeConfirm() {
    _confirmTimer?.cancel();
    _confirmTimer = null;
    confirm.value = null;
  }

  Monitor? _monitorOf(OutputHead head) => surfaces.monitors.value
      .where((m) => m.connector == head.name)
      .firstOrNull;

  OutputHead? _headOf(Monitor monitor) => heads.value
      .where((h) => h.enabled && h.name == monitor.connector)
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

  /// Escolhe o principal e guarda. Um monitor desligado não pode.
  @override
  Future<void> setPrimary(String name) async {
    final head = heads.value.where((h) => h.name == name).firstOrNull;
    if (head == null) return;
    final monitor = _monitorOf(head);
    if (monitor == null) return;
    await store.setPrimary(head.key);
    await surfaces.setPrimary(monitor.id);
  }
}
