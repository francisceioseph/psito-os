import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_runtime/psito_runtime.dart';

const _channel = MethodChannel('psito/dnd');

/// O que o lado C manda (linux/psito_dnd.cc), e a resposta do Dart.
Future<Object?> _fromC(
  WidgetTester tester,
  String method,
  Map<String, Object?> args,
) async {
  Object? reply;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _channel.name,
    _channel.codec.encodeMethodCall(MethodCall(method, args)),
    (data) => reply = _channel.codec.decodeEnvelope(data!),
  );
  await tester.pump();
  return reply;
}

Map<String, Object?> _at(
  WidgetTester tester,
  double x,
  double y, [
  List<String> uris = const ['file:///home/u/a%20b.txt'],
]) => {
  'view': tester.view.viewId,
  'x': x.round(),
  'y': y.round(),
  'uris': uris,
};

void main() {
  test('só os file:// viram caminhos', () {
    expect(
      filePaths(['file:///home/u/a%20b.txt\r', 'https://psito.org/', 'x']),
      ['/home/u/a b.txt'],
    );
  });

  group('soltar o que vem de outro app', () {
    late List<String> log;

    Widget target(String name, {DropAction? action = DropAction.copy}) =>
        PsitoDropTarget(
          onWillAccept: (paths) => action,
          onAccept: (paths, action) {
            log.add('$name ${action.name} $paths');
            return true;
          },
          builder: (context, hovering) => Text(
            '$name${hovering ? ' *' : ''}',
            textDirection: TextDirection.ltr,
          ),
        );

    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: 400,
              height: 400,
              child: PsitoDropTarget(
                onWillAccept: (_) => DropAction.move,
                onAccept: (paths, action) {
                  log.add('fora ${action.name} $paths');
                  return true;
                },
                builder: (context, hovering) => Stack(
                  children: [
                    Text('fora${hovering ? ' *' : ''}'),
                    Positioned(
                      left: 100,
                      top: 100,
                      width: 50,
                      height: 50,
                      child: target('dentro'),
                    ),
                    Positioned(
                      left: 200,
                      top: 100,
                      width: 50,
                      height: 50,
                      child: target('recusa', action: null),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    setUp(() => log = []);

    testWidgets('o alvo mais de dentro decide e se destaca', (tester) async {
      await pump(tester);
      expect(await _fromC(tester, 'over', _at(tester, 120, 120)), 'copy');
      expect(find.text('dentro *'), findsOneWidget);
      expect(find.text('fora'), findsOneWidget);

      expect(await _fromC(tester, 'over', _at(tester, 10, 10)), 'move');
      expect(find.text('dentro'), findsOneWidget);
      expect(find.text('fora *'), findsOneWidget);

      expect(await _fromC(tester, 'over', _at(tester, 220, 120)), isNull);
      expect(find.text('recusa'), findsOneWidget);

      await _fromC(tester, 'leave', {'view': tester.view.viewId});
      expect(find.text('fora'), findsOneWidget);
    });

    testWidgets('o soltar entrega os caminhos com a ação', (tester) async {
      await pump(tester);
      final drop = {..._at(tester, 120, 120), 'action': 'copy'};
      expect(await _fromC(tester, 'drop', drop), isTrue);
      expect(log, ['dentro copy [/home/u/a b.txt]']);
      expect(find.text('dentro'), findsOneWidget);
    });

    testWidgets('sem arquivos ou fora dos alvos, recusa', (tester) async {
      await pump(tester);
      final web = _at(tester, 120, 120, ['https://psito.org/']);
      expect(await _fromC(tester, 'over', web), isNull);
      expect(await _fromC(tester, 'drop', {...web, 'action': 'copy'}), false);
      final refused = {..._at(tester, 220, 120), 'action': 'copy'};
      expect(await _fromC(tester, 'drop', refused), false);
      expect(log, isEmpty);
    });
  });

  testWidgets('levar para fora manda os caminhos como file://', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );
    await PsitoDnd.instance.startDrag(7, ['/home/u/a b.txt']);
    expect(calls.single.method, 'startDrag');
    expect(calls.single.arguments, {
      'view': 7,
      'uris': ['file:///home/u/a%20b.txt'],
    });
  });
}
