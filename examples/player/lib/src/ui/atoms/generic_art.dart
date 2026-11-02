// examples/player/lib/src/ui/atoms/generic_art.dart
//
// A capa de quem não tem capa: um fundo com uma forma, sempre os mesmos para o
// mesmo álbum. As cores são conteúdo, como uma capa de verdade, e não saem do
// tema: nascem do nome, sem nenhuma escrita no código.
import 'dart:math';

import 'package:flutter/material.dart';

/// Um hash que não muda entre execuções, ao contrário do `hashCode`.
int stableHash(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash;
}

class GenericArt extends StatelessWidget {
  /// O que decide a arte, como `título|artista`.
  final String seed;

  const GenericArt({super.key, required this.seed});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ArtPainter(stableHash(seed)),
    child: const SizedBox.expand(),
  );
}

class _ArtPainter extends CustomPainter {
  final int hash;

  _ArtPainter(this.hash);

  @override
  void paint(Canvas canvas, Size size) {
    final hue = (hash % 360).toDouble();
    final background = HSLColor.fromAHSL(1, hue, 0.45, 0.38).toColor();
    final shape = HSLColor.fromAHSL(
      1,
      (hue + 120 + (hash >> 9) % 120) % 360,
      0.75,
      0.72,
    ).toColor();
    final s = size.shortestSide;
    final paint = Paint()..color = shape;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    switch ((hash >> 5) % 4) {
      case 0:
        canvas.drawCircle(Offset(s * 0.35, s * 0.6), s * 0.24, paint);
      case 1:
        canvas.drawCircle(Offset(s * 0.8, s * 0.2), s * 0.32, paint);
      case 2:
        canvas.drawRect(
          Rect.fromLTWH(0, s * 0.68, size.width, s * 0.32),
          paint,
        );
      default:
        canvas.save();
        canvas.translate(s * 0.5, s * 0.5);
        canvas.rotate(pi / 12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: s * 0.42,
              height: s * 0.42,
            ),
            Radius.circular(s * 0.05),
          ),
          paint,
        );
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.hash != hash;
}
