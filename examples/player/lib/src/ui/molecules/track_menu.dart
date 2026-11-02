// examples/player/lib/src/ui/molecules/track_menu.dart
//
// O que todo menu de faixa oferece, e os diálogos de playlist.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../library/library_controller.dart';
import '../../library/models.dart';
import '../../player/playback_controller.dart';
import '../format.dart';

List<PopupMenuEntry<VoidCallback>> trackMenu(
  BuildContext context,
  LibraryController library,
  PlaybackController playback,
  Track track,
) {
  final l = context.l10n;
  return [
    PopupMenuItem(
      value: () => unawaited(playback.playNext(track)),
      child: Text(l.playNext),
    ),
    PopupMenuItem(
      value: () => unawaited(playback.addToQueue(track)),
      child: Text(l.addToQueue),
    ),
    PopupMenuItem(
      value: () => unawaited(showAddToPlaylist(context, library, [track.path])),
      child: Text(l.addToPlaylist),
    ),
    if (track.id != 0)
      PopupMenuItem(
        value: () => unawaited(playback.setFavorite(track, !track.favorite)),
        child: Text(track.favorite ? l.removeFavorite : l.addFavorite),
      ),
  ];
}

/// O nome de uma playlist, ou null se cancelaram.
Future<String?> askPlaylistName(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _NameDialog(title: title, action: action, initial: initial),
  );
}

// O diálogo cuida do campo: ele ainda aparece enquanto a janela sai.
class _NameDialog extends StatefulWidget {
  final String title;
  final String action;
  final String initial;

  const _NameDialog({
    required this.title,
    required this.action,
    required this.initial,
  });

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l.playlistName),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}

/// Põe as faixas numa playlist, que pode ser nova.
Future<void> showAddToPlaylist(
  BuildContext context,
  LibraryController library,
  List<String> paths,
) async {
  final l = context.l10n;
  const create = -1;
  final chosen = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l.addToPlaylist),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(create),
          child: Row(
            children: [
              const Icon(Icons.add_rounded),
              const SizedBox(width: 12),
              Expanded(child: Text(l.newPlaylist)),
            ],
          ),
        ),
        for (final playlist in library.playlists)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(playlist.id),
            child: Text(
              playlistName(playlist, context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    ),
  );
  if (chosen == null || !context.mounted) return;
  if (chosen != create) return library.addToPlaylist(chosen, paths);
  final name = await askPlaylistName(
    context,
    title: l.newPlaylist,
    action: l.create,
  );
  if (name != null) await library.createPlaylist(name, paths);
}
