// shell/lib/dock_model.dart
//
// O que a dock mostra (os fixados e os apps abertos) e o que um clique faz.
import 'desktop_entries.dart';
import 'toplevels.dart';

class DockSlot {
  /// O `app_id` das janelas, que é também o id do `.desktop`.
  final String id;

  /// Null quando o app abriu uma janela mas não tem `.desktop`.
  final DesktopEntry? entry;

  /// Na ordem do foco: a mais recente no fim.
  final List<Toplevel> windows;

  const DockSlot({required this.id, this.entry, this.windows = const []});

  String get name => entry?.name ?? (windows.isEmpty ? id : windows.last.title);
  bool get running => windows.isNotEmpty;
}

/// Os fixados, na ordem, e depois os apps abertos que não são fixados, na
/// ordem em que abriram.
List<DockSlot> dockSlotsFor({
  required List<String> pinned,
  required Map<String, DesktopEntry> entries,
  required List<Toplevel> windows,
}) {
  final byApp = <String, List<Toplevel>>{};
  for (final window in windows) {
    byApp.putIfAbsent(window.appId, () => []).add(window);
  }
  return [
    for (final id in pinned)
      DockSlot(id: id, entry: entries[id], windows: byApp[id] ?? const []),
    for (final MapEntry(key: id, value: list) in byApp.entries)
      if (!pinned.contains(id))
        DockSlot(id: id, entry: entries[id], windows: list),
  ];
}

sealed class DockAction {
  const DockAction();
}

class LaunchApp extends DockAction {
  final DesktopEntry entry;
  const LaunchApp(this.entry);
}

class ActivateWindow extends DockAction {
  final int id;
  const ActivateWindow(this.id);
}

class MinimizeWindow extends DockAction {
  final int id;
  const MinimizeWindow(this.id);
}

/// Sem janela, abre o app; com a janela em foco, minimiza; senão, ativa a
/// mais recente (e traz de volta se estiver minimizada).
DockAction? tapAction(DockSlot slot) {
  if (!slot.running) {
    final entry = slot.entry;
    return entry == null ? null : LaunchApp(entry);
  }
  for (final window in slot.windows) {
    if (window.activated && !window.minimized) {
      return MinimizeWindow(window.id);
    }
  }
  return ActivateWindow(slot.windows.last.id);
}
