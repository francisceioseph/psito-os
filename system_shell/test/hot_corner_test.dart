import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_shell/widgets/hot_corner.dart';

void main() {
  late int triggered;
  late int tapped;

  Future<TestGesture> pump(WidgetTester tester) async {
    triggered = 0;
    tapped = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => tapped++,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: HotCorner(onTrigger: () => triggered++),
            ),
          ],
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(100, 100));
    return mouse;
  }

  Offset corner(WidgetTester tester) =>
      tester.getTopRight(find.byType(HotCorner)) + const Offset(-1, 1);

  testWidgets('parado no canto, dispara uma vez', (tester) async {
    final mouse = await pump(tester);
    await mouse.moveTo(corner(tester));
    await tester.pump(HotCorner.dwell);
    expect(triggered, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(triggered, 1);
    await mouse.moveTo(const Offset(100, 100));
    await mouse.moveTo(corner(tester));
    await tester.pump(HotCorner.dwell);
    expect(triggered, 2);
  });

  testWidgets('só de passagem, não dispara', (tester) async {
    final mouse = await pump(tester);
    await mouse.moveTo(corner(tester));
    await tester.pump(const Duration(milliseconds: 50));
    await mouse.moveTo(const Offset(100, 100));
    await tester.pump(const Duration(seconds: 1));
    expect(triggered, 0);
  });

  testWidgets('o clique passa para o que está embaixo', (tester) async {
    await pump(tester);
    await tester.tapAt(corner(tester));
    expect(tapped, 1);
  });
}
