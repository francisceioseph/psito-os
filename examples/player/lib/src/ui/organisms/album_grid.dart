// examples/player/lib/src/ui/organisms/album_grid.dart
//
// A grade de álbuns, virtualizada, e os lugares dos que ainda vão aparecer.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../library/models.dart';
import '../atoms/skeleton_box.dart';
import '../molecules/album_card.dart';
import '../molecules/album_row.dart';

/// Uma grade em que a capa fica quadrada: a altura é a largura mais os textos, o
/// que uma proporção fixa não dá.
class CardGridDelegate extends SliverGridDelegate {
  static const _maxWidth = 180.0;
  static const _spacing = 16.0;

  /// O que os textos ocupam abaixo da arte.
  final double textHeight;

  const CardGridDelegate(this.textHeight);

  static int columns(double available) =>
      ((available + _spacing) / (_maxWidth + _spacing)).ceil();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final available = constraints.crossAxisExtent;
    final count = columns(available);
    final width = (available - _spacing * (count - 1)) / count;
    return SliverGridRegularTileLayout(
      crossAxisCount: count,
      mainAxisStride: width + textHeight + _spacing,
      crossAxisStride: width + _spacing,
      childMainAxisExtent: width + textHeight,
      childCrossAxisExtent: width,
      reverseCrossAxis: false,
    );
  }

  @override
  bool shouldRelayout(CardGridDelegate oldDelegate) =>
      oldDelegate.textHeight != textHeight;
}

const _gridDelegate = CardGridDelegate(AlbumCard.textHeight);

class AlbumGrid extends StatelessWidget {
  final List<Album> albums;
  final ValueChanged<Album> onOpen;
  final ValueChanged<Album> onPlay;

  /// Mostra só uma fileira, com os que couberem.
  final bool singleRow;

  const AlbumGrid({
    super.key,
    required this.albums,
    required this.onOpen,
    required this.onPlay,
    this.singleRow = false,
  });

  Widget _grid(int count) => SliverGrid.builder(
    gridDelegate: _gridDelegate,
    itemCount: count,
    itemBuilder: (context, i) => AlbumCard(
      key: ValueKey(albums[i].id),
      album: albums[i],
      onOpen: () => onOpen(albums[i]),
      onPlay: () => onPlay(albums[i]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!singleRow) return _grid(albums.length);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = CardGridDelegate.columns(constraints.crossAxisExtent);
        return _grid(columns < albums.length ? columns : albums.length);
      },
    );
  }
}

/// Os álbuns na vista em lista.
class AlbumList extends StatelessWidget {
  final List<Album> albums;
  final ValueChanged<Album> onOpen;
  final ValueChanged<Album> onPlay;

  const AlbumList({
    super.key,
    required this.albums,
    required this.onOpen,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) => SliverFixedExtentList.builder(
    itemExtent: AlbumRow.height,
    itemCount: albums.length,
    itemBuilder: (context, i) => AlbumRow(
      key: ValueKey(albums[i].id),
      album: albums[i],
      onOpen: () => onOpen(albums[i]),
      onPlay: () => onPlay(albums[i]),
    ),
  );
}

/// Os cartões vazios durante a leitura.
class AlbumGridSkeleton extends StatelessWidget {
  final int count;

  const AlbumGridSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate: _gridDelegate,
    itemCount: count,
    itemBuilder: (context, _) => const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: SkeletonBox()),
        SizedBox(height: 8),
        SkeletonBox(height: 12, width: 100, radius: 4),
        SizedBox(height: 6),
        SkeletonBox(height: 10, width: 60, radius: 4),
      ],
    ),
  );
}
