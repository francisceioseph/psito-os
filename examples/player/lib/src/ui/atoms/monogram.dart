// examples/player/lib/src/ui/atoms/monogram.dart
//
// As iniciais de um artista num círculo. Sem foto nenhuma: as cores nascem do
// nome, como na arte genérica.
import 'package:flutter/material.dart';

import 'generic_art.dart';

/// Até duas iniciais, das primeiras palavras.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words
      .take(2)
      .map((w) => String.fromCharCode(w.runes.first))
      .join()
      .toUpperCase();
}

class Monogram extends StatelessWidget {
  final String name;
  final double? size;

  const Monogram({super.key, required this.name, this.size});

  @override
  Widget build(BuildContext context) {
    final hue = (stableHash(name) % 360).toDouble();
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: LayoutBuilder(
          builder: (context, constraints) => DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HSLColor.fromAHSL(1, hue, 0.45, 0.38).toColor(),
            ),
            child: Center(
              child: Text(
                initialsOf(name),
                style: TextStyle(
                  fontSize: constraints.biggest.shortestSide * 0.3,
                  fontWeight: FontWeight.w500,
                  color: HSLColor.fromAHSL(
                    1,
                    (hue + 40) % 360,
                    0.75,
                    0.85,
                  ).toColor(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
