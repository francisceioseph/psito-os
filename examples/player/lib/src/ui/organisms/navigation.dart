// examples/player/lib/src/ui/organisms/navigation.dart
//
// Os destinos do player: a barra lateral, e a fileira de ícones quando ela não
// cabe.
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

enum PlayerDestination { home, library, playlists, folders, search, settings }

extension on PlayerDestination {
  IconData get icon => switch (this) {
    PlayerDestination.home => Icons.home_rounded,
    PlayerDestination.library => Icons.library_music_rounded,
    PlayerDestination.playlists => Icons.playlist_play_rounded,
    PlayerDestination.folders => Icons.folder_rounded,
    PlayerDestination.search => Icons.search_rounded,
    PlayerDestination.settings => Icons.settings_rounded,
  };

  String label(BuildContext context) {
    final l = context.l10n;
    return switch (this) {
      PlayerDestination.home => l.home,
      PlayerDestination.library => l.library,
      PlayerDestination.playlists => l.playlists,
      PlayerDestination.folders => l.folders,
      PlayerDestination.search => l.search,
      PlayerDestination.settings => l.settings,
    };
  }
}

const _main = [
  PlayerDestination.home,
  PlayerDestination.library,
  PlayerDestination.playlists,
  PlayerDestination.folders,
  PlayerDestination.search,
];

class PlayerRail extends StatelessWidget {
  final PlayerDestination selected;
  final ValueChanged<PlayerDestination> onSelected;
  final VoidCallback onAddFolder;

  const PlayerRail({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onAddFolder,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final index = _main.indexOf(selected);
    return NavigationRail(
      selectedIndex: index < 0 ? null : index,
      labelType: NavigationRailLabelType.all,
      onDestinationSelected: (i) => onSelected(_main[i]),
      leading: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: IconButton.filled(
          tooltip: l.addFolder,
          style: IconButton.styleFrom(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            minimumSize: const Size(56, 56),
          ),
          icon: const Icon(Icons.create_new_folder_rounded),
          onPressed: onAddFolder,
        ),
      ),
      trailingAtBottom: true,
      trailing: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: IconButton(
          tooltip: l.settings,
          isSelected: selected == PlayerDestination.settings,
          icon: Icon(PlayerDestination.settings.icon),
          onPressed: () => onSelected(PlayerDestination.settings),
        ),
      ),
      destinations: [
        for (final destination in _main)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            label: Text(destination.label(context)),
          ),
      ],
    );
  }
}

class CompactNavigation extends StatelessWidget {
  final PlayerDestination selected;
  final ValueChanged<PlayerDestination> onSelected;
  final VoidCallback onAddFolder;

  const CompactNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onAddFolder,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        IconButton(
          tooltip: context.l10n.addFolder,
          icon: const Icon(Icons.create_new_folder_rounded),
          onPressed: onAddFolder,
        ),
        for (final destination in PlayerDestination.values)
          destination == selected
              ? IconButton.filledTonal(
                  tooltip: destination.label(context),
                  isSelected: true,
                  icon: Icon(destination.icon),
                  onPressed: () => onSelected(destination),
                )
              : IconButton(
                  tooltip: destination.label(context),
                  icon: Icon(destination.icon),
                  onPressed: () => onSelected(destination),
                ),
      ],
    ),
  );
}
