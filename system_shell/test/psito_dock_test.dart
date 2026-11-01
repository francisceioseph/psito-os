import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/shell/app_entry.dart';
import 'package:system_shell/widgets/psito_dock.dart';

DockTile _tile(String id) => DockTile(
  key: id,
  entry: AppEntry(
    id: id,
    name: id,
    color: Colors.blue,
    icon: (size) => SizedBox.square(dimension: size),
  ),
);

void main() {
  test('os centros dos ícones, com a fila centrada e os separadores', () {
    // 3 ícones de 52 (64 com as margens) e um separador de 13 antes do 2
    expect(
      PsitoDock.centers(count: 3, separators: {2}, iconSize: 52, centerX: 500),
      [500 - 102.5 + 32, 500 - 102.5 + 96, 500 - 102.5 + 13 + 160],
    );
  });

  testWidgets('os centros batem com o desenho', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PsitoDock(
            tiles: [_tile('a'), _tile('b'), _tile('c')],
            separators: const {1},
            onTap: (_, _) {},
          ),
        ),
      ),
    );
    final centers = PsitoDock.centers(
      count: 3,
      separators: {1},
      iconSize: 52,
      centerX: 400,
    );
    for (final (i, id) in ['a', 'b', 'c'].indexed) {
      expect(
        tester.getCenter(find.byKey(ValueKey('dock-$id'))).dx,
        closeTo(centers[i], 0.5),
      );
    }
  });

  testWidgets('o espaço aberto e o clique direito com o retângulo', (
    tester,
  ) async {
    String? menu;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PsitoDock(
            tiles: [_tile('a'), _tile('b')],
            gap: 1,
            onTap: (_, _) {},
            onMenu: (key, rect) => menu = '$key ${rect.width}',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final a = tester.getCenter(find.byKey(const ValueKey('dock-a'))).dx;
    final b = tester.getCenter(find.byKey(const ValueKey('dock-b'))).dx;
    expect(b - a, 128);
    await tester.tap(
      find.byKey(const ValueKey('dock-b')),
      buttons: kSecondaryButton,
    );
    expect(menu, 'b 64.0');
  });

  testWidgets('o wrapTile envolve o quadrado, e o clique tem o retângulo', (
    tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PsitoDock(
            tiles: [_tile('a')],
            onTap: (key, rect) => tapped = '$key ${rect.width}',
            wrapTile: (tile, child) =>
                KeyedSubtree(key: ValueKey('wrap-${tile.key}'), child: child),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('wrap-a'))).width, 52);
    await tester.tap(find.byKey(const ValueKey('dock-a')));
    expect(tapped, 'a 64.0');
  });

  testWidgets('os pontos das janelas, a bolinha e o pulo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PsitoDock(
            tiles: [
              DockTile(key: 'a', entry: _tile('a').entry, windows: 1),
              DockTile(
                key: 'b',
                entry: _tile('b').entry,
                windows: 3,
                badge: 120,
              ),
              DockTile(key: 'c', entry: _tile('c').entry, bouncing: true),
            ],
            onTap: (_, _) {},
          ),
        ),
      ),
    );
    Finder dots(String key) => find.descendant(
      of: find.byKey(ValueKey('running-$key')),
      matching: find.byType(Container),
    );
    expect(dots('a'), findsOneWidget);
    expect(dots('b'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('running-c')), findsNothing);
    expect(find.text('99+'), findsOneWidget);
    expect(find.byKey(const ValueKey('badge-a')), findsNothing);

    // O que abre sobe e desce
    final ground = tester.getCenter(find.byKey(const ValueKey('dock-c'))).dy;
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester.getCenter(find.byKey(const ValueKey('dock-c'))).dy,
      lessThan(ground - 5),
    );
    expect(tester.getCenter(find.byKey(const ValueKey('dock-a'))).dy, ground);
  });

  testWidgets('na vertical, os centros batem no eixo y', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PsitoDock(
            tiles: [_tile('a'), _tile('b'), _tile('c')],
            separators: const {2},
            onTap: (_, _) {},
            position: PsitoDockPosition.left,
          ),
        ),
      ),
    );
    final centers = PsitoDock.centers(
      count: 3,
      separators: {2},
      iconSize: 52,
      centerX: 300,
    );
    for (final (i, id) in ['a', 'b', 'c'].indexed) {
      final center = tester.getCenter(find.byKey(ValueKey('dock-$id')));
      expect(center.dy, closeTo(centers[i], 0.5));
      expect(center.dx, 400);
    }
  });

  testWidgets('a ampliação não muda o tamanho da dock', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PsitoDock(tiles: [_tile('a'), _tile('b')], onTap: (_, _) {}),
        ),
      ),
    );
    final before = tester.getSize(find.byType(PsitoDock));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('dock-a'))),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PsitoDock)), before);
    expect(
      tester.getRect(find.byKey(const ValueKey('dock-a'))).height,
      closeTo(52 * PsitoDock.magnifiedScale, 0.5),
    );
    await gesture.removePointer();
  });
}
