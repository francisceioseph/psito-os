// examples/player/lib/src/ui/atoms/mosaic_cover.dart
//
// A capa de uma playlist: as de até quatro álbuns dela. Falta capa, entra a arte
// genérica, a partir do nome.
import 'package:flutter/material.dart';

import 'cover_art.dart';

class MosaicCover extends StatelessWidget {
  final List<({String? path, String seed})> covers;
  final String seed;
  final double? size;

  const MosaicCover({
    super.key,
    required this.covers,
    required this.seed,
    this.size,
  });

  Widget _cell(int i) => Expanded(
    child: CoverArt(
      path: i < covers.length ? covers[i].path : null,
      seed: i < covers.length ? covers[i].seed : '$seed|$i',
      radius: 0,
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Expanded(child: Row(children: [_cell(0), _cell(1)])),
          Expanded(child: Row(children: [_cell(2), _cell(3)])),
        ],
      ),
    ),
  );
}
