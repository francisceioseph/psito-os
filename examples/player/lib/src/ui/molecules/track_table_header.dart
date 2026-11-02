// examples/player/lib/src/ui/molecules/track_table_header.dart
//
// O cabeçalho das colunas da lista de músicas. Clicar ordena, e clicar de novo
// inverte. As larguras são as do TrackRow em colunas.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/models.dart';
import 'track_row.dart';

class TrackTableHeader extends StatelessWidget {
  final TrackQuery query;
  final void Function(TrackSort sort, bool ascending) onSort;

  const TrackTableHeader({
    super.key,
    required this.query,
    required this.onSort,
  });

  Widget _column(BuildContext context, TrackSort sort, String label) {
    final current = query.sort == sort;
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 36),
        alignment: Alignment.centerLeft,
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () => onSort(sort, current ? !query.ascending : true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (current)
            Icon(
              query.ascending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 14,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Row(
            children: [
              const SizedBox(width: TrackRow.leadingWidth),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _column(context, TrackSort.title, l.columnTitle),
                ),
              ),
              if (width >= TrackRow.albumMinWidth)
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _column(context, TrackSort.album, l.columnAlbum),
                  ),
                ),
              if (width >= TrackRow.detailsMinWidth) ...[
                SizedBox(
                  width: TrackRow.durationWidth,
                  child: _column(context, TrackSort.duration, l.columnDuration),
                ),
                SizedBox(
                  width: TrackRow.formatWidth,
                  child: _column(context, TrackSort.format, l.columnFormat),
                ),
              ],
              const SizedBox(width: TrackRow.actionsWidth),
            ],
          );
        },
      ),
    );
  }
}
