import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
            onTap: (_) {},
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
            onTap: (_) {},
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
}
