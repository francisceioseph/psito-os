import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
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

  test('o tamanho lógico corta a fração, como o compositor', () {
    const config = OutputConfig(mode: OutputMode(1400, 1050), scale: 1.5);
    expect(config.rect.size, const Size(933, 700));
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

    Displays displays(MonitorStore store) => Displays(
      surfaces: surfaces,
      store: store,
      // A contagem inteira, em poucos milissegundos
      confirmTick: const Duration(milliseconds: 1),
      channel: _channel,
    );

    Monitor monitor(int id, double x, {bool primary = false}) => Monitor(
      id: id,
      rect: Rect.fromLTWH(x, 0, 1920, 1080),
      connector: x == 0 ? 'a' : 'b',
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

      // Um novo, em cima do outro: vai para a direita, com o que fica fixado antes
      await d.handle(MethodCall('changed', [_headMap('a'), _headMap('b')]));
      await pumpEventQueue();
      expect(applied, hasLength(2));

      // Uma mudança de fora, com os mesmos monitores, fica como está
      await d.handle(
        MethodCall('changed', [_headMap('a'), _headMap('b', x: 3000)]),
      );
      await pumpEventQueue();
      expect(applied, hasLength(2));
    });

    test('quem fica no lugar é fixado antes de mover o vizinho', () async {
      final d = displays(MonitorStore.memory());
      await d.start();
      await pumpEventQueue();
      await d.handle(
        MethodCall('changed', [_headMap('a'), _headMap('b', x: 1920)]),
      );
      await pumpEventQueue();
      applied.clear();
      final [a, b] = d.displays.value;

      await d.apply([a, b.copyWith(x: 0, y: 1080)]);
      Object? xOf(Map<Object?, Object?> call, int i) =>
          ((call['heads']! as List<Object?>)[i]! as Map<Object?, Object?>)['x'];
      expect(applied.map((c) => c['test']), [true, false, false]);
      // O primeiro tira todos do lugar, e o segundo é o de verdade
      expect(xOf(applied[1], 0), 1);
      expect(xOf(applied[2], 0), 0);
      d.confirm.value!.keep();
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
      await d.setPrimary('b');
      expect(primaries, [2]);
      expect(store.primary, OutputHead.fromMap(_headMap('b')).key);

      // Um conector que não existe não muda nada
      await d.setPrimary('z');
      expect(primaries, [2]);
      expect(store.primary, OutputHead.fromMap(_headMap('b')).key);
    });

    test('dois espelhados são dois monitores: vale o conector', () async {
      final store = MonitorStore.memory(
        primary: OutputHead.fromMap(_headMap('b')).key,
      );
      current = [_headMap('a'), _headMap('b')];
      surfaces.monitors.value = const [
        Monitor(
          id: 1,
          rect: Rect.fromLTWH(0, 0, 1920, 1080),
          connector: 'a',
          primary: true,
        ),
        Monitor(id: 2, rect: Rect.fromLTWH(0, 0, 1920, 1080), connector: 'b'),
      ];
      final d = displays(store);
      await d.start();
      await pumpEventQueue();
      expect(primaries, [2]);
      expect(d.displays.value.first.primary, isTrue);
    });

    group('aplicar', () {
      const smaller = PsitoDisplayMode(1280, 720, refresh: 60000);
      late MonitorStore store;
      late Displays d;
      late String key;

      setUp(() async {
        store = MonitorStore.memory();
        d = displays(store);
        await d.start();
        await pumpEventQueue();
        key = d.heads.value.single.key;
      });

      List<PsitoDisplay> smallerPlan() => [
        d.displays.value.single.copyWith(mode: smaller),
      ];

      Map<Object?, Object?> onlyHead(Map<Object?, Object?> call) =>
          (call['heads']! as List<Object?>).single! as Map<Object?, Object?>;

      test('testa, aplica e pergunta, sem guardar ainda', () async {
        expect(await d.apply(smallerPlan()), PsitoDisplaysResult.ok);
        expect(applied.map((a) => a['test']), [true, false]);
        expect(onlyHead(applied.last)['width'], 1280);
        expect(d.confirm.value, isNotNull);
        expect(store[key], isNull);
        d.confirm.value!.revert();
      });

      test('manter guarda, e a contagem para', () async {
        await d.apply(smallerPlan());
        d.confirm.value!.keep();
        expect(d.confirm.value, isNull);
        await pumpEventQueue();
        expect(store[key]!.mode!.width, 1280);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(applied, hasLength(2));
      });

      test('voltar reaplica o de antes e não guarda', () async {
        await d.apply(smallerPlan());
        d.confirm.value!.revert();
        await pumpEventQueue();
        expect(d.confirm.value, isNull);
        expect(applied, hasLength(3));
        expect(onlyHead(applied.last)['width'], 1920);
        expect(store[key], isNull);
      });

      test('sem resposta, volta sozinha', () async {
        await d.apply(smallerPlan());
        final request = d.confirm.value!;
        expect(request.secondsLeft, Displays.confirmSeconds);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(request.secondsLeft, 0);
        expect(d.confirm.value, isNull);
        expect(onlyHead(applied.last)['width'], 1920);
        expect(store[key], isNull);
      });

      test('uma pergunta de cada vez', () async {
        await d.apply(smallerPlan());
        expect(await d.apply(smallerPlan()), PsitoDisplaysResult.busy);
        expect(applied, hasLength(2));
        d.confirm.value!.revert();
      });

      test('o que o compositor recusa no teste nem é aplicado', () async {
        answer = 'failed';
        expect(await d.apply(smallerPlan()), PsitoDisplaysResult.failed);
        expect(applied.single['test'], isTrue);
        expect(d.confirm.value, isNull);
      });

      test('sem nenhum ligado, nem pergunta ao compositor', () async {
        final off = d.displays.value.single.copyWith(enabled: false);
        expect(await d.apply([off]), PsitoDisplaysResult.failed);
        expect(applied, isEmpty);
      });

      test('nada mudou: nada a confirmar', () async {
        expect(await d.apply(d.displays.value), PsitoDisplaysResult.ok);
        expect(applied, isEmpty);
        expect(d.confirm.value, isNull);
      });

      test('o layout aplicado começa em 0,0', () async {
        current = [_headMap('a'), _headMap('b', x: 1920)];
        await d.handle(MethodCall('changed', current));
        await pumpEventQueue();
        applied.clear();
        final [a, b] = d.displays.value;
        await d.apply([a.copyWith(x: 100), b.copyWith(x: 2020, y: 50)]);
        final heads = applied.last['heads']! as List<Object?>;
        final first = heads.first! as Map<Object?, Object?>;
        final second = heads.last! as Map<Object?, Object?>;
        expect((first['x'], first['y']), (0, 0));
        expect((second['x'], second['y']), (1920, 50));
        d.confirm.value!.keep();
      });

      test('um monitor que entra acaba com a pergunta', () async {
        await d.apply(smallerPlan());
        await d.handle(MethodCall('changed', [_headMap('a'), _headMap('b')]));
        expect(d.confirm.value, isNull);
      });
    });
  });
}
