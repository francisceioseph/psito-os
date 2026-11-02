// examples/player/lib/src/ui/atoms/cover_art.dart
//
// A capa de um álbum: a miniatura do disco ou, sem ela, a arte genérica.
import 'dart:io';

import 'package:flutter/material.dart';

import 'generic_art.dart';

class CoverArt extends StatelessWidget {
  final String? path;

  /// O que decide a arte genérica.
  final String seed;

  /// O lado, ou null para ocupar o que houver.
  final double? size;
  final double radius;

  const CoverArt({
    super.key,
    required this.path,
    required this.seed,
    this.size,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final generic = GenericArt(seed: seed);
    final path = this.path;
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: path == null
              ? generic
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => generic,
                ),
        ),
      ),
    );
  }
}
