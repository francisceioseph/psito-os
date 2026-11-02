import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_shell/displays.dart';
import 'package:psito_shell/surfaces.dart';

const _channel = MethodChannel('test/outputs');
const _surfaces = MethodChannel('test/outputs-surfaces');

const _full = OutputMode(1920, 1080, preferred: true);
const _small = OutputMode(1280, 720);

OutputHead _head(
  String name, {
  bool enabled = true,
  int x = 0,
  OutputMode? current = _full,
}) => OutputHead(
  name: name,
  make: 'Acme',
  model: name,
  serial: 's-$name',
  enabled: enabled,
  x: x,
  modes: const [_small, _full, OutputMode(1920, 1080, refresh: 144000)],
  current: current,
);

Map<String, Object?> _headMap(
  String name, {
  int x = 0,
  int width = 1920,
  bool enabled = true,
}) => {
  'name': name,
  'make': 'Acme',
  'model': name,
  'serial': '',
  'enabled': enabled,
  'x': x,
  'y': 0,
  'transform': 0,
  'scale': 1.0,
  'modes': [
    {'width': width, 'height': 1080, 'refresh': 60000, 'preferred': true},
  ],
  'current': 0,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bestMode', () {
    test('o tamanho preferido, na maior frequência', () {
      expect(_head('a').modes.length, 3);
      final best = bestMode(_head('a').modes)!;
      expect((best.width, best.refresh), (1920, 144000));
    });

    test('sem preferência, o maior', () {
      expect(bestMode(const [_small, OutputMode(1920, 1080)])!.width, 1920);
      expect(bestMode(const []), isNull);
    });
  });

  group('planOutputs', () {
    test('um novo vai à direita, na melhor forma', () {
      final plan = planOutputs([_head('a'), _head('b')], MonitorStore.memory());
      expect(plan['a']!.x, 0);
      expect(plan['b']!.x, 1920);
      expect(plan['b']!.mode!.refresh, 144000);
    });

    test('um conhecido volta como estava', () {
      final plan = planOutputs(
        [_head('a')],
        MonitorStore.memory(
          monitors: {
            _head('a').key: const OutputConfig(
              mode: _small,
              transform: 1,
              scale: 2,
            ),
          },
        ),
      );
      expect(plan['a']!.mode!.width, 1280);
      expect(plan['a']!.transform, 1);
      expect(plan['a']!.scale, 2);
    });

    test('um modo que não existe mais cai no melhor', () {
      final plan = planOutputs(
        [_head('a')],
        MonitorStore.memory(
          monitors: {
            _head('a').key: const OutputConfig(mode: OutputMode(800, 600)),
          },
        ),
      );
      expect(plan['a']!.mode!.width, 1920);
    });

    test('sem a frequência guardada, vale a maior daquele tamanho', () {
      final plan = planOutputs(
        [_head('a')],
        MonitorStore.memory(
          monitors: {
            _head('a').key: const OutputConfig(
              mode: OutputMode(1920, 1080, refresh: 0),
            ),
          },
        ),
      );
      expect(plan['a']!.mode!.refresh, 144000);
    });

    test('o novo fica à direita de quem está guardado', () {
      final plan = planOutputs(
        [_head('novo'), _head('b')],
        MonitorStore.memory(
          monitors: {_head('b').key: const OutputConfig(mode: _full)},
        ),
      );
      expect(plan['b']!.x, 0);
      expect(plan['novo']!.x, 1920);
    });

    test('dois guardados que se sobrepõem são afastados', () {
      final plan = planOutputs(
        [_head('a'), _head('b')],
        MonitorStore.memory(
          monitors: {
            _head('a').key: const OutputConfig(mode: _full),
            _head('b').key: const OutputConfig(mode: _small, x: 100),
          },
        ),
      );
      expect(plan['a']!.x, 0);
      expect(plan['b']!.x, 1920);
    });

    test('espelhados continuam no mesmo lugar', () {
      final plan = planOutputs(
        [_head('a'), _head('b')],
        MonitorStore.memory(
          monitors: {
            _head('a').key: const OutputConfig(mode: _full),
            _head('b').key: const OutputConfig(mode: _full),
          },
        ),
      );
      expect(plan['b']!.x, 0);
    });

    test('a rotação conta na largura', () {
      final plan = planOutputs(
        [_head('a'), _head('b')],
        MonitorStore.memory(
          monitors: {
            _head('a').key: const OutputConfig(mode: _full, transform: 1),
          },
        ),
      );
      expect(plan['b']!.x, 1080);
    });

    test('a escala conta na largura', () {
      final plan = planOutputs(
        [_head('a'), _head('b')],
        MonitorStore.memory(
          monitors: {_head('a').key: const OutputConfig(mode: _full, scale: 2)},
        ),
      );
      expect(plan['b']!.x, 960);
    });

    test('o layout começa em 0,0, sem o monitor que saiu', () {
      final plan = planOutputs(
        [_head('b')],
        MonitorStore.memory(
          monitors: {_head('b').key: const OutputConfig(mode: _full, x: 1920)},
        ),
      );
      expect(plan['b']!.x, 0);
    });

    test('um desconhecido desligado continua desligado', () {
      final plan = planOutputs([
        _head('a'),
        _head('b', enabled: false),
      ], MonitorStore.memory());
      expect(plan['b']!.enabled, isFalse);
    });

    test('um monitor sem nenhum modo fica como está', () {
      const head = OutputHead(name: 'a');
      final plan = planOutputs([head], MonitorStore.memory());
      expect(plan['a']!.matches(head), isTrue);
    });

    test('sempre sobra um ligado', () {
      final plan = planOutputs(
        [_head('a')],
        MonitorStore.memory(
          monitors: {
            _head('a').key: const OutputConfig(enabled: false, mode: _full),
          },
        ),
      );
      expect(plan['a']!.enabled, isTrue);
    });
  });

  group('OutputHead', () {
    test('sem a série, a chave leva o conector', () {
      expect(
        const OutputHead(name: 'HDMI-1', make: 'A', model: 'B').key,
        'A|B|HDMI-1',
      );
      expect(_head('a').key, 'Acme|a|s-a');
    });

    test('lê o que o runner manda', () {
      final head = OutputHead.fromMap(_headMap('a', x: 10));
      expect(head.x, 10);
      expect(head.current!.width, 1920);
      expect(head.current!.preferred, isTrue);
    });
  });

  group('MonitorStore', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('psito_monitors_');
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    test('grava e lê de volta', () async {
      final file = File('${tmp.path}/psito/monitors.json');
      final store = await MonitorStore.load(file);
      await store.put({
        'k': const OutputConfig(mode: _small, x: 5, transform: 3, scale: 1.5),
      });
      await store.setPrimary('k');

      final back = await MonitorStore.load(file);
      expect(back.primary, 'k');
      expect(back['k']!.mode!.width, 1280);
      expect(back['k']!.x, 5);
      expect(back['k']!.transform, 3);
      expect(back['k']!.scale, 1.5);
    });

    test('um arquivo estragado vale como vazio', () async {
      final file = File('${tmp.path}/monitors.json');
      await file.writeAsString('{nada');
      final store = await MonitorStore.load(file);
      expect(store.primary, isNull);
    });

    test('um monitor só com o tamanho (o do provision.sh)', () async {
      final file = File('${tmp.path}/monitors.json');
      await file.writeAsString(
        '{"monitors": {"k": {"width": 1440, "height": 900}}}',
      );
      final store = await MonitorStore.load(file);
      expect(store['k']!.enabled, isTrue);
      expect(store['k']!.mode!.width, 1440);
    });
  });

  group('Displays', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<Map<Object?, Object?>> applied;
    late List<Object?> primaries;
    late List<Map<String, Object?>> current;
    late String answer;
    late Surfaces surfaces;

    Displays displays(MonitorStore store) =>
        Displays(surfaces: surfaces, store: store, channel: _channel);

    Monitor monitor(int id, double x, {bool primary = false}) => Monitor(
      id: id,
      rect: Rect.fromLTWH(x, 0, 1920, 1080),
      primary: primary,
    );

    setUp(() {
      applied = [];
      primaries = [];
      current = [_headMap('a')];
      answer = 'ok';
      surfaces = Surfaces(_surfaces);
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'list') return current;
        applied.add(call.arguments as Map<Object?, Object?>);
        return answer;
      });
      messenger.setMockMethodCallHandler(_surfaces, (call) async {
        if (call.method == 'setPrimary') primaries.add(call.arguments);
        return true;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(_channel, null);
      messenger.setMockMethodCallHandler(_surfaces, null);
    });

    test('o que já está certo não é aplicado de novo', () async {
      await displays(MonitorStore.memory()).start();
      await pumpEventQueue();
      expect(applied, isEmpty);
    });

    test('aplica o guardado ao subir', () async {
      final store = MonitorStore.memory(
        monitors: {
          OutputHead.fromMap(_headMap('a')).key: const OutputConfig(
            mode: OutputMode(1920, 1080),
            x: 0,
            scale: 2,
          ),
        },
      );
      await displays(store).start();
      await pumpEventQueue();
      final heads = applied.single['heads']! as List<Object?>;
      final head = heads.single! as Map<Object?, Object?>;
      expect(head['name'], 'a');
      expect(head['scale'], 2.0);
    });

    test('só arruma quando o conjunto de monitores muda', () async {
      final d = displays(MonitorStore.memory());
      await d.start();
      await pumpEventQueue();

      // Um novo, em cima do outro: vai para a direita
      await d.handle(MethodCall('changed', [_headMap('a'), _headMap('b')]));
      await pumpEventQueue();
      expect(applied, hasLength(1));

      // Uma mudança de fora, com os mesmos monitores, fica como está
      await d.handle(
        MethodCall('changed', [_headMap('a'), _headMap('b', x: 3000)]),
      );
      await pumpEventQueue();
      expect(applied, hasLength(1));
    });

    test('uma recusa não vira um laço', () async {
      answer = 'failed';
      final d = displays(MonitorStore.memory());
      await d.start();
      await d.handle(MethodCall('changed', [_headMap('a'), _headMap('b')]));
      await pumpEventQueue();
      expect(applied, hasLength(1));
    });

    test('um cancelamento tenta de novo, mas não para sempre', () async {
      answer = 'cancelled';
      final d = displays(MonitorStore.memory());
      await d.start();
      await d.handle(MethodCall('changed', [_headMap('a'), _headMap('b')]));
      await pumpEventQueue();
      expect(applied, hasLength(3));
    });

    test('sem principal guardado, guarda o de agora', () async {
      final store = MonitorStore.memory();
      surfaces.monitors.value = [monitor(1, 0, primary: true)];
      await displays(store).start();
      await pumpEventQueue();
      expect(store.primary, OutputHead.fromMap(_headMap('a')).key);
      expect(primaries, isEmpty);
    });

    test('o principal guardado volta quando religa', () async {
      final key = OutputHead.fromMap(_headMap('a')).key;
      final store = MonitorStore.memory(
        primary: key,
        monitors: {
          key: const OutputConfig(mode: OutputMode(1920, 1080, refresh: 60000)),
          OutputHead.fromMap(_headMap('b')).key: const OutputConfig(
            mode: OutputMode(1920, 1080, refresh: 60000),
            x: 1920,
          ),
        },
      );
      current = [_headMap('a'), _headMap('b', x: 1920)];
      surfaces.monitors.value = [monitor(2, 1920, primary: true)];
      await displays(store).start();
      await pumpEventQueue();
      expect(primaries, isEmpty);

      surfaces.monitors.value = [
        monitor(3, 0),
        monitor(2, 1920, primary: true),
      ];
      await pumpEventQueue();
      expect(primaries, [3]);
      expect(applied, isEmpty);
    });

    test('escolher o principal guarda', () async {
      final store = MonitorStore.memory();
      current = [_headMap('a'), _headMap('b', x: 1920)];
      surfaces.monitors.value = [
        monitor(1, 0, primary: true),
        monitor(2, 1920),
      ];
      final d = displays(store);
      await d.start();
      await pumpEventQueue();
      expect(await d.setPrimaryMonitor(2), isTrue);
      expect(store.primary, OutputHead.fromMap(_headMap('b')).key);
      expect(await d.setPrimaryMonitor(9), isFalse);
    });

    test('configurar guarda só o que valeu', () async {
      final store = MonitorStore.memory();
      final d = displays(store);
      await d.start();
      final key = d.heads.value.single.key;
      const plan = {'a': OutputConfig(mode: _small)};

      expect(await d.configure(plan, test: true), 'ok');
      expect(applied.last['test'], isTrue);
      expect(store[key], isNull);

      answer = 'failed';
      expect(await d.configure(plan), 'failed');
      expect(store[key], isNull);

      answer = 'ok';
      expect(await d.configure(plan), 'ok');
      expect(applied.last['test'], isFalse);
      expect(store[key]!.mode!.width, 1280);
    });
  });
}
