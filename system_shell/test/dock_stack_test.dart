import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/shell/app_entry.dart';
import 'package:system_shell/widgets/dock_stack.dart';

DockStackEntry _entry(String name) => DockStackEntry(
  '/p/$name',
  AppEntry(
    id: name,
    name: name,
    color: Colors.grey,
    icon: (size) => SizedBox.square(dimension: size),
  ),
);

void main() {
  Future<List<String>> pump(WidgetTester tester, int count) async {
    final log = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DockStack(
          anchor: const Rect.fromLTWH(380, 540, 52, 52),
          title: 'Downloads',
          entries: [for (var i = 0; i < count; i++) _entry('f$i')],
          onOpen: (key) => log.add('open $key'),
          onOpenFolder: () => log.add('folder'),
          onClose: () => log.add('close'),
        ),
      ),
    );
    return log;
  }

  testWidgets('com poucos itens é um leque, o mais novo embaixo', (
    tester,
  ) async {
    final log = await pump(tester, 3);
    expect(find.byType(GridView), findsNothing);
    final newest = tester.getCenter(find.byKey(const ValueKey('stack-/p/f0')));
    final oldest = tester.getCenter(find.byKey(const ValueKey('stack-/p/f2')));
    expect(newest.dy, greaterThan(oldest.dy));
    expect(newest.dy, lessThan(540));
    await tester.tap(find.text('f1'));
    expect(log, ['close', 'open /p/f1']);
  });

  testWidgets('com muitos itens é uma grade, com o Abrir no Files', (
    tester,
  ) async {
    final log = await pump(tester, DockStack.fanLimit + 1);
    expect(find.byType(GridView), findsOneWidget);
    await tester.tap(find.text('Abrir no Files'));
    expect(log, ['close', 'folder']);
  });

  testWidgets('a pasta vazia diz que está vazia', (tester) async {
    await pump(tester, 0);
    expect(find.text('A pasta está vazia.'), findsOneWidget);
  });
}
