// packages/psito_dock/lib/src/layout.dart
//
// O que a dock mostra, em seções, e o que um clique num app faz. É genérico
// no app ([A]: o `.desktop` no shell, o PsitoApp no laboratório) e na janela
// ([W]: o foreign-toplevel no shell).
import 'item.dart';

/// O que a dock precisa saber de uma janela.
abstract interface class DockWindow {
  /// O `app_id` da janela, que é também o id do `.desktop`.
  String get appId;
  bool get focused;
  bool get minimized;
}

class DockAppSlot<A, W extends DockWindow> {
  final String id;

  /// Null quando o app abriu uma janela mas não está instalado (sem
  /// `.desktop`).
  final A? app;

  /// Na ordem do foco: a mais recente no fim.
  final List<W> windows;

  /// Fixado no dock.json, ou só aberto.
  final bool pinned;

  const DockAppSlot({
    required this.id,
    this.app,
    this.windows = const [],
    this.pinned = false,
  });

  DockApp get item => DockApp(id);
  bool get running => windows.isNotEmpty;
}

class DockLayout<A, W extends DockWindow> {
  /// Os apps fixados, na ordem do dock.json.
  final List<DockAppSlot<A, W>> pinned;

  /// Os apps abertos que não são fixados, na ordem em que abriram. Ficam
  /// depois de um separador.
  final List<DockAppSlot<A, W>> running;

  /// As pastas e os arquivos fixados, na ordem do dock.json. A lixeira vem
  /// depois deles, sempre.
  final List<DockPath> paths;

  const DockLayout({
    this.pinned = const [],
    this.running = const [],
    this.paths = const [],
  });

  List<DockAppSlot<A, W>> get apps => [...pinned, ...running];
}

bool _always(String path) => true;

/// As seções da dock. Um app fixado sem [apps] e sem janela fica escondido,
/// porque não teria ícone nem o que abrir; uma pasta ou um arquivo, quando
/// [exists] diz que sumiu.
DockLayout<A, W> dockLayout<A, W extends DockWindow>({
  required List<DockItem> items,
  required Map<String, A> apps,
  required Iterable<W> windows,
  bool Function(String path) exists = _always,
}) {
  final byApp = <String, List<W>>{};
  for (final window in windows) {
    byApp.putIfAbsent(window.appId, () => []).add(window);
  }
  final pinnedIds = {
    for (final item in items)
      if (item is DockApp) item.id,
  };
  return DockLayout(
    pinned: [
      for (final item in items)
        if (item case DockApp(:final id)
            when apps.containsKey(id) || byApp.containsKey(id))
          DockAppSlot(
            id: id,
            app: apps[id],
            windows: byApp[id] ?? const [],
            pinned: true,
          ),
    ],
    running: [
      for (final MapEntry(key: id, value: list) in byApp.entries)
        if (!pinnedIds.contains(id))
          DockAppSlot(id: id, app: apps[id], windows: list),
    ],
    paths: [
      for (final item in items)
        if (item case final DockPath path when exists(path.path)) path,
    ],
  );
}

sealed class DockAction<A, W> {
  const DockAction();
}

class LaunchApp<A, W> extends DockAction<A, W> {
  final A app;
  const LaunchApp(this.app);
}

class ActivateWindow<A, W> extends DockAction<A, W> {
  final W window;
  const ActivateWindow(this.window);
}

class MinimizeWindow<A, W> extends DockAction<A, W> {
  final W window;
  const MinimizeWindow(this.window);
}

/// As janelas do app para escolher (o seletor só com elas).
class ShowWindows<A, W> extends DockAction<A, W> {
  final List<W> windows;
  const ShowWindows(this.windows);
}

/// Sem janela, abre o app; com a janela em foco, minimiza, ou, se o app
/// tem outras, mostra as janelas dele; senão, ativa a mais recente (e traz
/// de volta se estiver minimizada).
DockAction<A, W>? tapAction<A, W extends DockWindow>(DockAppSlot<A, W> slot) {
  if (!slot.running) {
    final app = slot.app;
    return app == null ? null : LaunchApp(app);
  }
  for (final window in slot.windows) {
    if (window.focused && !window.minimized) {
      return slot.windows.length > 1
          ? ShowWindows(slot.windows)
          : MinimizeWindow(window);
    }
  }
  return ActivateWindow(slot.windows.last);
}
