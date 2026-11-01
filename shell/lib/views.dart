// shell/lib/views.dart
//
// Uma view do Flutter por superfície layer-shell, todas no mesmo isolate e
// com o mesmo [ShellState]. Os widgets são os do system_shell.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_desktop/psito_desktop.dart';
import 'package:psito_dock/psito_dock.dart';
import 'package:psito_files_ui/psito_files_ui.dart';
import 'package:psito_runtime/psito_runtime.dart';
import 'package:psito_services/system_services.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/l10n/system_localizations.dart';
import 'package:system_shell/shell/app_entry.dart';
import 'package:system_shell/shell/clipboard_history.dart';
import 'package:system_shell/widgets/battery_panel.dart';
import 'package:system_shell/widgets/clipboard_panel.dart';
import 'package:system_shell/widgets/desktop_background.dart';
import 'package:system_shell/widgets/dock_menu.dart';
import 'package:system_shell/widgets/hot_corner.dart';
import 'package:system_shell/widgets/dock_stack.dart';
import 'package:system_shell/widgets/launcher.dart';
import 'package:system_shell/widgets/network_panel.dart';
import 'package:system_shell/widgets/notification_panel.dart';
import 'package:system_shell/widgets/notification_toasts.dart';
import 'package:system_shell/widgets/power_confirm_dialog.dart';
import 'package:system_shell/widgets/power_panel.dart';
import 'package:system_shell/widgets/psito_desktop_icons.dart';
import 'package:system_shell/widgets/psito_dock.dart';
import 'package:system_shell/widgets/top_bar.dart';
import 'package:system_shell/widgets/volume_osd.dart';
import 'package:system_shell/widgets/volume_panel.dart';
import 'package:system_shell/widgets/window_switcher_overlay.dart';

import 'app_icon.dart';
import 'desk.dart';
import 'dock.dart';
import 'polkit_dialog.dart';
import 'shell_state.dart';
import 'size_reporter.dart';
import 'surfaces.dart';
import 'l10n/shell_localizations.dart';

/// A raiz: põe cada superfície na sua view, assim que o engine anuncia a
/// view (as do runner chegam depois da implícita).
class ShellViews extends StatefulWidget {
  final ShellState state;
  final Map<Surface, int> viewIds;

  const ShellViews({super.key, required this.state, required this.viewIds});

  @override
  State<ShellViews> createState() => _ShellViewsState();
}

class _ShellViewsState extends State<ShellViews> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Views novas chegam como mudança de métricas
  @override
  void didChangeMetrics() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final views = {
      for (final view in WidgetsBinding.instance.platformDispatcher.views)
        view.viewId: view,
    };
    final state = widget.state;
    return ViewCollection(
      views: [
        for (final MapEntry(key: surface, value: id) in widget.viewIds.entries)
          if (views[id] case final view?)
            View(
              key: ValueKey(surface),
              view: view,
              child: switch (surface) {
                Surface.background => _BackgroundView(state),
                Surface.topbar => _TopBarView(state),
                Surface.dock => _DockView(state),
                Surface.overlay => _OverlayView(state),
                Surface.toasts => ToastsView(state),
                Surface.osd => OsdView(state),
              },
            ),
      ],
    );
  }
}

final _shellDelegates = psitoLocalizationsDelegates(const [
  ShellLocalizations.delegate,
  SystemLocalizations.delegate,
  FilesUiLocalizations.delegate,
]);

/// Tema do Psito acompanhando a cor de destaque das Configurações.
class _Themed extends StatelessWidget {
  final ShellState state;
  final Widget Function(BuildContext context) builder;

  const _Themed(this.state, {required this.builder});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: state.settings,
    builder: (context, settings, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: psitoTheme(settings.accent),
      locale: resolvePsitoLocale(settings.language),
      localizationsDelegates: _shellDelegates,
      supportedLocales: psitoLocales,
      color: Colors.transparent,
      home: Builder(builder: builder),
    ),
  );
}

class _BackgroundView extends StatelessWidget {
  final ShellState state;
  const _BackgroundView(this.state);

  // O DesktopBackground tem InkWell: precisa de um Material em volta. O
  // fundo ocupa a tela toda: o tamanho dele é o da tela, para a dock (o
  // display das views do runner é nulo)
  @override
  Widget build(BuildContext context) => _Themed(
    state,
    builder: (context) {
      state.dockUi.screen = MediaQuery.sizeOf(context);
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: DesktopBackground(
                wallpaper: state.settings.value.wallpaper,
              ),
            ),
            Positioned.fill(
              child: ValueListenableBuilder(
                valueListenable: state.desk,
                builder: (context, desk, _) =>
                    desk == null ? const SizedBox.shrink() : _DeskView(desk),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _DeskView extends StatelessWidget {
  final DeskController desk;
  const _DeskView(this.desk);

  Widget _icon(BuildContext context, DeskItem item, double size) {
    final fallback = Icon(
      Icons.insert_drive_file_outlined,
      size: size,
      color: context.palette.textSecondary,
    );
    if (item.key == DeskItem.homeKey) {
      return PsitoIcon(const ['user-home', 'folder'], size: size);
    }
    if (item.key == DeskItem.trashKey) {
      return ValueListenableBuilder(
        valueListenable: desk.state.dockUi.trashFull,
        builder: (context, full, _) => PsitoIcon(
          [full ? 'user-trash-full' : 'user-trash'],
          size: size,
          fallback: fallback,
        ),
      );
    }
    if (item.broken) {
      return Icon(
        Icons.link_off_rounded,
        size: size,
        color: context.palette.textSecondary,
      );
    }
    if (item.shortcut case final shortcut?) {
      return AppIcon(shortcut.icon, size: size);
    }
    return FileIcon(entry: item.entry!, env: desk, size: size);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: desk,
    builder: (context, _) {
      final size = desk.state.settings.value.desktopIconSize;
      final insets = desk.insets;
      final grid = DeskGrid.fit(
        insets.deflateSize(MediaQuery.sizeOf(context)),
        deskCellSize(size),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => desk.setGrid(grid));
      final viewId = View.of(context).viewId;
      return PsitoDropTarget(
        onWillAccept: (paths) => desk.dropAction(null, paths),
        onAccept: (paths, action, at) => desk.drop(null, paths, action, at: at),
        builder: (context, _) => PsitoDesktopIcons(
          icons: [
            for (final item in desk.items)
              DeskIcon(
                key: item.key,
                name: item.name,
                icon: (size) => _icon(context, item, size),
                dimmed: desk.isCut(item),
                leavesDesk: item.entry != null,
                editor: desk.renaming == item.key
                    ? RenameField(
                        // O atalho mostra o Name=, sem extensão para poupar
                        name: item.shortcut?.name ?? item.entry!.name,
                        isDirectory:
                            item.shortcut != null || item.entry!.isDirectory,
                        textAlign: TextAlign.center,
                        onSubmit: (name) =>
                            unawaited(desk.rename(item.key, name)),
                        onCancel: desk.stopRename,
                      )
                    : null,
              ),
          ],
          cells: desk.cells,
          iconSize: size,
          insets: insets,
          selected: desk.selected,
          onPress: desk.press,
          onRelease: desk.release,
          onRect: desk.selectRect,
          onOpen: desk.open,
          keyboard: desk.keyboard,
          onKey: desk.handleKey,
          onMenu: (key, position) => unawaited(desk.openMenu(key, position)),
          popup: desk.menuOpen,
          onDragStart: desk.dragStarted,
          onDragOut: (keys, icon, hotspot) =>
              desk.dragOut(viewId, keys, icon, hotspot),
          onMove: desk.moveKeys,
          canDropOn: desk.canDropOn,
          onDropOn: desk.dropOn,
          wrapItem: (key, child) => !desk.acceptsDrops(key)
              ? child(false)
              : PsitoDropTarget(
                  onWillAccept: (paths) => desk.dropAction(key, paths),
                  onAccept: (paths, action, _) => desk.drop(key, paths, action),
                  builder: (context, hovering) => child(hovering),
                ),
        ),
      );
    },
  );
}

class _TopBarView extends StatelessWidget {
  final ShellState state;
  const _TopBarView(this.state);

  @override
  Widget build(BuildContext context) {
    final services = state.services;
    return _Themed(
      state,
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            state.notifications,
            state.settings,
            state.clipboard,
            state.deskTransfer,
            services.network.state,
            services.audio.state,
            services.battery.state,
          ]),
          builder: (context, _) {
            final settings = state.settings.value;
            // A view tem espaço embaixo da barra para os tooltips
            return Align(
              alignment: Alignment.topCenter,
              child: Stack(
                children: [
                  TopBar(
                    onMenuTap: () => state.toggle(ShellOverlay.launcher),
                    onNotificationsTap: () =>
                        state.toggle(ShellOverlay.notifications),
                    network: services.network.state.value,
                    onNetworkTap: () => state.toggle(ShellOverlay.network),
                    audio: services.audio.state.value,
                    onVolumeTap: () => state.toggle(ShellOverlay.volume),
                    onVolumeScroll: (direction) {
                      final audio = services.audio;
                      final s = audio.state.value;
                      if (s.available) {
                        audio.setVolume(s.volume + direction * 0.05);
                      }
                    },
                    battery: services.battery.state.value,
                    showBatteryPercentage: settings.showBatteryPercentage,
                    onBatteryTap: () => state.toggle(ShellOverlay.battery),
                    clipboardCount: state.clipboard.entries.length,
                    onClipboardTap: () => state.toggle(ShellOverlay.clipboard),
                    transfer: state.deskTransfer.value,
                    onCancelTransfer: () => state.desk.value?.cancelJobs(),
                    onPowerTap: () => state.toggle(ShellOverlay.power),
                    now: services.time.now,
                    unreadCount: state.notifications.unreadCount,
                    use24h: settings.use24h,
                    showSeconds: settings.showSeconds,
                    doNotDisturb: settings.doNotDisturb,
                  ),
                  if (settings.desktopHotCorner)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: HotCorner(onTrigger: state.toggleDesktop),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A dock, os toasts e o OSD têm o tamanho do conteúdo: o conteúdo é medido
/// sem limite (OverflowBox) e o runner ajusta a superfície a ele. As views
/// dimensionadas pelo conteúdo do embedder (fl_view_new_sized_to_content)
/// não servem: o embedder pede o tamanho novo à GtkWindow, mas a superfície
/// layer-shell continua com o tamanho do primeiro configure.
///
/// Sem MaterialApp, que ocuparia todo o espaço; sem o Overlay dele, os
/// tooltips ficam desligados.
class _Sized extends StatelessWidget {
  final ShellState state;
  final Surface surface;
  final Alignment alignment;

  /// Espaço transparente em volta, para a sombra não ser cortada pela borda
  /// da superfície; fica fora da região de input.
  final EdgeInsets padding;
  final Widget Function(BuildContext context, PsitoSettings settings) builder;

  /// O tamanho novo da superfície, depois de pedir ao runner.
  final ValueChanged<Size>? onSize;

  /// A borda fora da região de input, quando não é o [padding] (a dock
  /// muda a dela com o ponteiro).
  final EdgeInsets Function()? input;

  /// Envolve o conteúdo já com o [padding] (a dock sabe do ponteiro na
  /// superfície toda, margem incluída).
  final Widget Function(Widget child)? wrap;

  const _Sized(
    this.state,
    this.surface, {
    required this.alignment,
    this.padding = EdgeInsets.zero,
    required this.builder,
    this.onSize,
    this.input,
    this.wrap,
  });

  static Widget _plain(Widget child) => child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: state.settings,
    builder: (context, settings, _) => Theme(
      data: psitoTheme(settings.accent),
      // Sem o MaterialApp, os textos também precisam vir daqui
      child: Localizations(
        locale: state.locale,
        delegates: _shellDelegates,
        child: TooltipVisibility(
          visible: false,
          child: Material(
            type: MaterialType.transparency,
            child: OverflowBox(
              alignment: alignment,
              minWidth: 0,
              minHeight: 0,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: SizeReporter(
                onSize: (size) {
                  // Um erro de build vira um ErrorWidget do tamanho que couber,
                  // aqui infinito, e isso não pode derrubar o shell
                  if (!size.isFinite) return;
                  onSize?.call(size);
                  state.surfaces.resize(
                    surface,
                    size,
                    input: input?.call() ?? padding,
                  );
                },
                child: (wrap ?? _plain)(
                  Padding(
                    padding: padding,
                    child: Builder(
                      builder: (context) => builder(context, settings),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A dock, na borda das configurações. Com o ocultar sozinha, ela desliza
/// para fora da tela e a superfície vira uma faixa de 2 px na borda, que a
/// traz de volta.
class _DockView extends StatefulWidget {
  final ShellState state;
  const _DockView(this.state);

  @override
  State<_DockView> createState() => _DockViewState();
}

class _DockViewState extends State<_DockView>
    with SingleTickerProviderStateMixin {
  ShellState get state => widget.state;
  DockController get ui => widget.state.dockUi;

  // 0 na tela, 1 fora dela
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  // A dock saiu: só a faixa da borda
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    ui.revealed.addListener(_revealedChanged);
  }

  @override
  void dispose() {
    ui.revealed.removeListener(_revealedChanged);
    _slide.dispose();
    super.dispose();
  }

  void _revealedChanged() {
    if (ui.revealed.value) {
      setState(() => _collapsed = false);
      unawaited(_slide.reverse());
    } else {
      unawaited(
        _slide.forward().whenComplete(() {
          if (mounted && !ui.revealed.value) setState(() => _collapsed = true);
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: state.settings,
    builder: (context, settings, _) {
      final position = settings.dockPosition;
      final alignment = PsitoDock.edgeAlignment(position);
      if (_collapsed) {
        return _Sized(
          state,
          Surface.dock,
          alignment: alignment,
          onSize: (size) => ui.surface = size,
          builder: (context, _) => _DockStrip(ui),
        );
      }
      final away = switch (position) {
        PsitoDockPosition.bottom => const Offset(0, 1),
        PsitoDockPosition.left => const Offset(-1, 0),
        PsitoDockPosition.right => const Offset(1, 0),
      };
      return _Sized(
        state,
        Surface.dock,
        alignment: alignment,
        padding: ui.padding,
        input: () => ui.inputInsets,
        onSize: (size) => ui.surface = size,
        // O ponteiro em qualquer parte da superfície (a margem até a borda
        // também) segura a dock
        wrap: (child) => MouseRegion(
          onEnter: (_) => ui.hovered.value = true,
          onExit: (_) => ui.hovered.value = false,
          child: AnimatedBuilder(
            animation: _slide,
            builder: (context, child) => FractionalTranslation(
              translation: away * _slide.value,
              child: child,
            ),
            child: child,
          ),
        ),
        builder: (context, settings) => _content(settings),
      );
    },
  );

  Widget _content(PsitoSettings settings) => Listener(
    // O ícone arrastado sai da fileira (e o gesto dele junto): quem
    // segue o ponteiro é a raiz da view, que continua com ele fora da
    // superfície
    onPointerMove: (event) {
      if (ui.drag.value?.source == DockDragSource.dock) {
        ui.moveDrag(ui.origin + event.position);
      }
    },
    onPointerUp: (_) {
      if (ui.drag.value?.source == DockDragSource.dock) {
        unawaited(ui.endDrag());
      }
    },
    onPointerCancel: (_) {
      if (ui.drag.value?.source == DockDragSource.dock) ui.cancelDrag();
    },
    child: ListenableBuilder(
      listenable: Listenable.merge([
        state.toplevels,
        state.apps,
        state.dock,
        ui.drag,
        ui.trashFull,
        ui.launching,
        state.notifications,
      ]),
      builder: (context, _) {
        final row = ui.row;
        final byKey = {
          for (final item in row.items)
            DockController.keyOf(item.item): item.item,
        };
        final drag = ui.drag.value;
        return PsitoDropTarget(
          onWillAccept: (paths) {
            ui.reveal();
            return paths.isEmpty ? null : DropAction.link;
          },
          onAccept: (paths, _, _) => ui.dropPaths(paths),
          builder: (context, hovering) => PsitoDock(
            tiles: [
              for (final item in row.items)
                DockTile(
                  key: DockController.keyOf(item.item),
                  entry: ui.visual(item.item),
                  windows: item.slot?.windows.length ?? 0,
                  badge: switch (item.slot) {
                    final slot? => state.notifications.unreadFor(slot.id),
                    null => 0,
                  },
                  bouncing: ui.launching.value.contains(item.slot?.id),
                ),
            ],
            separators: row.separators,
            gap: drag == null ? null : ui.dropIndex(row, drag),
            highlighted: hovering,
            onTap: (key, rect) => ui.tap(byKey[key]!, rect),
            onMenu: (key, rect) => ui.openMenu(byKey[key]!, rect),
            onDragStart: (key, position) => ui.startDrag(
              byKey[key]!,
              DockDragSource.dock,
              ui.origin + position,
            ),
            iconSize: settings.dockIconSize,
            magnification: settings.dockMagnification && drag == null,
            wrapTile: (tile, child) => _TileDropTarget(
              ui: ui,
              item: byKey[tile.key]!,
              radius: settings.dockIconSize * 0.3,
              alignment: PsitoDock.edgeAlignment(settings.dockPosition),
              child: child,
            ),
            position: settings.dockPosition,
          ),
        );
      },
    ),
  );
}

/// A dock escondida: uma faixa transparente de 2 px ao longo da borda. O
/// ponteiro, ou um arquivo arrastado, chegando nela traz a dock de volta.
class _DockStrip extends StatelessWidget {
  final DockController ui;
  const _DockStrip(this.ui);

  @override
  Widget build(BuildContext context) {
    final screen = ui.screen;
    final size = ui.position.vertical
        ? Size(2, screen.height - TopBar.height)
        : Size(screen.width, 2);
    return MouseRegion(
      onEnter: (_) => ui.reveal(),
      child: PsitoDropTarget(
        onWillAccept: (_) {
          ui.reveal();
          return null;
        },
        onAccept: (_, _, _) => false,
        builder: (context, _) => SizedBox.fromSize(size: size),
      ),
    );
  }
}

/// Um app ou a lixeira recebe os arquivos soltos em cima dele (abre ou leva
/// para a lixeira) e cresce com a borda de destaque enquanto aceita. Nas
/// pastas, nos arquivos e no "Apps" o alvo é a dock toda, que fixa o que
/// vem.
class _TileDropTarget extends StatelessWidget {
  final DockController ui;
  final DockItem item;
  final double radius;

  /// De onde ele cresce (o lado da borda).
  final Alignment alignment;
  final Widget child;

  const _TileDropTarget({
    required this.ui,
    required this.item,
    required this.radius,
    required this.alignment,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (item is DockPath || item is DockLauncher) return child;
    final accent = Theme.of(context).colorScheme.primary;
    return PsitoDropTarget(
      onWillAccept: (paths) {
        ui.reveal();
        return ui.dropAction(item, paths);
      },
      onAccept: (paths, _, _) => ui.dropOn(item, paths),
      builder: (context, hovering) => AnimatedScale(
        scale: hovering ? 1.15 : 1,
        duration: const Duration(milliseconds: 150),
        alignment: alignment,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: hovering ? Border.all(color: accent, width: 2) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// O ícone que segue o ponteiro enquanto se arrasta para a dock ou para
/// fora dela.
class _DockGhost extends StatelessWidget {
  final AppEntry entry;
  final double size;

  const _DockGhost(this.entry, this.size);

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 0.85,
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: entry.color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: entry.color, width: 2),
      ),
      child: entry.icon(size * 0.55),
    ),
  );
}

/// Launcher, painéis da top bar e a confirmação de energia. A superfície só
/// existe enquanto um deles está aberto; a faixa da top bar fica fora da
/// região de input, para trocar de painel clicando nela.
class _OverlayView extends StatelessWidget {
  final ShellState state;
  const _OverlayView(this.state);

  @override
  Widget build(BuildContext context) {
    final services = state.services;
    final ui = state.dockUi;
    return _Themed(
      state,
      builder: (context) => Material(
        type: MaterialType.transparency,
        // O arrastar que começou no launcher continua aqui depois que ele
        // fecha: a raiz fica no caminho do ponteiro
        child: Listener(
          onPointerDown: (event) => ui.lastPointer = event.position,
          onPointerMove: (event) {
            ui.lastPointer = event.position;
            if (ui.drag.value?.source == DockDragSource.launcher) {
              ui.moveDrag(event.position);
            }
          },
          onPointerUp: (_) {
            if (ui.drag.value?.source == DockDragSource.launcher) {
              unawaited(ui.endDrag());
            }
          },
          onPointerCancel: (_) {
            if (ui.drag.value?.source == DockDragSource.launcher) {
              ui.cancelDrag();
            }
          },
          child: Stack(
            children: [
              Positioned.fill(child: _content(services)),
              ValueListenableBuilder(
                valueListenable: ui.drag,
                builder: (context, drag, _) {
                  if (drag == null) return const SizedBox.shrink();
                  final size = state.settings.value.dockIconSize;
                  return Positioned(
                    left: drag.position.dx - size / 2,
                    top: drag.position.dy - size / 2,
                    child: IgnorePointer(
                      child: _DockGhost(ui.visual(drag.item), size),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DockMenuItem> _launcherMenu(AppEntry entry) {
    final app = state.installed(entry.id);
    final item = DockApp(entry.id);
    final desk = state.desk.value;
    return [
      if (app != null) DockMenuItem(state.l10n.open, () => state.launch(app)),
      state.dock.contains(item)
          ? DockMenuItem(
              state.l10n.removeFromDock,
              () => state.dock.unpin(item),
            )
          : DockMenuItem(state.l10n.keepInDock, () => state.dock.pin(item)),
      if (app != null && desk != null && desk.canCreateShortcut)
        DockMenuItem(state.l10n.createDeskShortcut, () {
          state.closeOverlay();
          unawaited(desk.createShortcut(app));
        }),
    ];
  }

  Widget _content(SystemServices services) => ListenableBuilder(
    listenable: Listenable.merge([
      state.overlay,
      state.confirm,
      state.switcher,
      state.dockUi.menu,
      state.dockUi.stack,
      state.dockUi.askEmptyTrash,
      state.deskMenu,
      state.deskTrust,
      state.polkit.current,
    ]),
    builder: (context, _) {
      final accent = Theme.of(context).colorScheme.primary;
      if (state.polkit.current.value case final request?) {
        return PolkitDialog(
          key: ValueKey(request.cookie),
          request: request,
          l10n: state.l10n,
        );
      }
      if (state.switcher.isOpen) {
        return Focus(
          autofocus: true,
          onKeyEvent: (node, event) =>
              state.handleKey(
                event,
                shift: HardwareKeyboard.instance.isShiftPressed,
              )
              ? KeyEventResult.handled
              : KeyEventResult.ignored,
          // Clicar fora fecha (o seletor das janelas de um app, aberto
          // pela dock, não fecha soltando uma tecla)
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: state.switcher.cancel,
                  behavior: HitTestBehavior.opaque,
                ),
              ),
              WindowSwitcherOverlay(
                switcher: state.switcher,
                onPick: state.pickSwitcher,
              ),
            ],
          ),
        );
      }
      if (state.confirm.value == PowerAction.logout) {
        return DockConfirm(
          title: state.l10n.logoutQuestion,
          message: state.l10n.logoutBody,
          action: state.l10n.logoutAction,
          onConfirm: () => state.runPower(PowerAction.logout),
          onCancel: () => state.confirm.value = null,
        );
      }
      if (state.confirm.value case final action?) {
        final powerOff = action == PowerAction.powerOff;
        return PowerConfirmDialog(
          key: ValueKey(action),
          powerOff: powerOff,
          onConfirm: () => state.runPower(action),
          onCancel: () => state.confirm.value = null,
        );
      }
      final ui = state.dockUi;
      if (ui.askEmptyTrash.value) {
        return DockConfirm(
          title: state.l10n.emptyTrashQuestion,
          message: state.l10n.emptyTrashBody,
          action: state.l10n.emptyAction,
          onConfirm: () => unawaited(ui.emptyTrash()),
          onCancel: () => ui.askEmptyTrash.value = false,
        );
      }
      if (state.deskTrust.value case final trust?) {
        return DockConfirm(
          title: state.l10n.trustQuestion,
          message: state.l10n.trustBody(trust.name),
          action: state.l10n.trustAndOpen,
          onConfirm: trust.onTrust,
          onCancel: () => state.deskTrust.value = null,
        );
      }
      if (state.deskMenu.value case final menu?) {
        return DockMenu(
          key: ValueKey(menu.title),
          at: menu.at,
          title: menu.title,
          items: menu.items,
          onClose: () => state.deskMenu.value = null,
        );
      }
      if (ui.stack.value case final stack?) {
        return DockStack(
          position: state.settings.value.dockPosition,
          anchor: stack.anchor,
          title: stack.folder.name,
          entries: ui.stackEntries(stack),
          onOpen: ui.openFromStack,
          onOpenFolder: () => ui.openFromStack(stack.folder.path),
          onClose: ui.closeStack,
        );
      }
      if (state.dockUi.menu.value case final menu?) {
        return DockMenu(
          position: state.settings.value.dockPosition,
          anchor: menu.anchor,
          title: state.dockUi.title(menu.item),
          items: state.dockUi.menuItems(menu.item),
          onClose: state.dockUi.closeMenu,
        );
      }
      return switch (state.overlay.value) {
        null => const SizedBox.shrink(),
        ShellOverlay.launcher => Launcher(
          apps: [
            for (final app in state.apps.value)
              appEntry(app.id, app.name, app, accent),
          ],
          onLaunch: (entry) => state.launch(
            state.apps.value.firstWhere((app) => app.id == entry.id),
          ),
          onClose: state.closeOverlay,
          onDragStart: (entry) => state.dockUi.startDrag(
            DockApp(entry.id),
            DockDragSource.launcher,
            state.dockUi.lastPointer,
          ),
          menuFor: (entry) => _launcherMenu(entry),
        ),
        ShellOverlay.notifications => NotificationPanel(
          center: state.notifications,
          onClose: state.closeOverlay,
          onTap: state.openNotification,
        ),
        ShellOverlay.network => NetworkPanel(
          service: services.network,
          onClose: state.closeOverlay,
          onOpenSettings: state.openNetworkSettings,
          onOpenPortal: state.openPortalLogin,
        ),
        ShellOverlay.volume => VolumePanel(
          state: services.audio.state,
          onVolume: services.audio.setVolume,
          onMuted: services.audio.setMuted,
          onClose: state.closeOverlay,
        ),
        ShellOverlay.battery => BatteryPanel(
          state: services.battery.state,
          onClose: state.closeOverlay,
        ),
        ShellOverlay.clipboard => ClipboardPanel(
          history: state.clipboard,
          onPick: (index) {
            state.closeOverlay();
            state.recopy(index);
          },
          onClose: state.closeOverlay,
        ),
        ShellOverlay.power => PowerPanel(
          capabilities: services.session.capabilities,
          onLock: () => unawaited(state.lockSession()),
          onLogout: () => state.askPower(PowerAction.logout),
          onSuspend: () {
            state.closeOverlay();
            services.session.suspend();
          },
          onReboot: () => state.askPower(PowerAction.reboot),
          onPowerOff: () => state.askPower(PowerAction.powerOff),
          onClose: state.closeOverlay,
        ),
      };
    },
  );
}

/// Os toasts, no canto de cima à direita; a superfície só existe com algum
/// na tela.
class ToastsView extends StatelessWidget {
  final ShellState state;
  const ToastsView(this.state, {super.key});

  @override
  Widget build(BuildContext context) => _Sized(
    state,
    Surface.toasts,
    alignment: Alignment.topRight,
    // A sombra dos toasts (18 de blur); à direita, a margem até a borda
    padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
    builder: (context, _) => NotificationToasts(
      center: state.notifications,
      onTap: state.openNotification,
    ),
  );
}

/// O aviso de volume, acima da dock; não recebe cliques.
class OsdView extends StatelessWidget {
  final ShellState state;
  const OsdView(this.state, {super.key});

  @override
  Widget build(BuildContext context) => _Sized(
    state,
    Surface.osd,
    alignment: Alignment.bottomCenter,
    builder: (context, _) => ListenableBuilder(
      listenable: Listenable.merge([
        state.osd,
        state.osdClip,
        state.services.audio.state,
      ]),
      builder: (context, _) => switch ((state.osd.value, state.osdClip.value)) {
        (false, _) => const SizedBox.shrink(),
        (true, final ClipEntry entry) => ClipboardOsd(entry: entry),
        (true, null) => VolumeOsd(state: state.services.audio.state.value),
      },
    ),
  );
}
