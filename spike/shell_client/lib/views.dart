// spike/shell_client/lib/views.dart
//
// Uma view do Flutter por superfície layer-shell, todas no mesmo isolate e
// com o mesmo [ShellState]. Os widgets são os do system_shell.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psito_sdk/psito_sdk.dart';
import 'package:system_shell/app.dart';
import 'package:system_shell/widgets/battery_panel.dart';
import 'package:system_shell/widgets/desktop_background.dart';
import 'package:system_shell/widgets/launcher.dart';
import 'package:system_shell/widgets/network_panel.dart';
import 'package:system_shell/widgets/notification_panel.dart';
import 'package:system_shell/widgets/notification_toasts.dart';
import 'package:system_shell/widgets/power_confirm_dialog.dart';
import 'package:system_shell/widgets/power_panel.dart';
import 'package:system_shell/widgets/psito_dock.dart';
import 'package:system_shell/widgets/top_bar.dart';
import 'package:system_shell/widgets/volume_osd.dart';
import 'package:system_shell/widgets/volume_panel.dart';
import 'package:system_shell/widgets/window_switcher_overlay.dart';

import 'app_icon.dart';
import 'shell_state.dart';
import 'size_reporter.dart';
import 'surfaces.dart';

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
                Surface.toasts => _ToastsView(state),
                Surface.osd => _OsdView(state),
              },
            ),
      ],
    );
  }
}

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
      color: Colors.transparent,
      home: Builder(builder: builder),
    ),
  );
}

class _BackgroundView extends StatelessWidget {
  final ShellState state;
  const _BackgroundView(this.state);

  // O DesktopBackground tem InkWell: precisa de um Material em volta
  @override
  Widget build(BuildContext context) => _Themed(
    state,
    builder: (context) => Material(
      type: MaterialType.transparency,
      child: DesktopBackground(wallpaper: state.settings.value.wallpaper),
    ),
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
            services.network.state,
            services.audio.state,
            services.battery.state,
          ]),
          builder: (context, _) {
            final settings = state.settings.value;
            // A view tem espaço embaixo da barra para os tooltips
            return Align(
              alignment: Alignment.topCenter,
              child: TopBar(
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
                  if (s.available) audio.setVolume(s.volume + direction * 0.05);
                },
                battery: services.battery.state.value,
                showBatteryPercentage: settings.showBatteryPercentage,
                onBatteryTap: () => state.toggle(ShellOverlay.battery),
                onPowerTap: () => state.toggle(ShellOverlay.power),
                now: services.time.now,
                unreadCount: state.notifications.unreadCount,
                use24h: settings.use24h,
                showSeconds: settings.showSeconds,
                doNotDisturb: settings.doNotDisturb,
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
  final Widget Function(BuildContext context, PsitoSettings settings) builder;

  const _Sized(
    this.state,
    this.surface, {
    required this.alignment,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: state.settings,
    builder: (context, settings, _) => Theme(
      data: psitoTheme(settings.accent),
      child: Directionality(
        textDirection: TextDirection.ltr,
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
                onSize: (size) => state.surfaces.resize(surface, size),
                child: Builder(
                  builder: (context) => builder(context, settings),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DockView extends StatelessWidget {
  final ShellState state;
  const _DockView(this.state);

  @override
  Widget build(BuildContext context) => _Sized(
    state,
    Surface.dock,
    alignment: Alignment.bottomCenter,
    builder: (context, settings) => ListenableBuilder(
      listenable: Listenable.merge([state.toplevels, state.apps]),
      builder: (context, _) {
        final slots = state.dockSlots;
        return PsitoDock(
          apps: [
            for (final slot in slots)
              appEntry(slot.id, slot.name, slot.entry, settings.accent),
          ],
          runningAppIds: {
            for (final slot in slots)
              if (slot.running) slot.id,
          },
          onAppTap: (app) =>
              state.tapDock(slots.firstWhere((slot) => slot.id == app.id)),
        );
      },
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
    return _Themed(
      state,
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            state.overlay,
            state.confirm,
            state.switcher,
          ]),
          builder: (context, _) {
            final accent = Theme.of(context).colorScheme.primary;
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
                child: WindowSwitcherOverlay(
                  switcher: state.switcher,
                  onPick: state.pickSwitcher,
                ),
              );
            }
            if (state.confirm.value case final action?) {
              final powerOff = action == PowerAction.powerOff;
              return PowerConfirmDialog(
                key: ValueKey(action),
                action: powerOff ? 'Desligar' : 'Reiniciar',
                progressive: powerOff ? 'Desligando' : 'Reiniciando',
                onConfirm: () => state.runPower(action),
                onCancel: () => state.confirm.value = null,
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
              ),
              ShellOverlay.notifications => NotificationPanel(
                center: state.notifications,
                onClose: state.closeOverlay,
                onTap: state.openNotification,
              ),
              ShellOverlay.network => NetworkPanel(
                state: services.network.state,
                onSetEnabled: services.network.setEnabled,
                onClose: state.closeOverlay,
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
              ShellOverlay.power => PowerPanel(
                capabilities: services.session.capabilities,
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
        ),
      ),
    );
  }
}

/// Os toasts, no canto de cima à direita; a superfície só existe com algum
/// na tela.
class _ToastsView extends StatelessWidget {
  final ShellState state;
  const _ToastsView(this.state);

  @override
  Widget build(BuildContext context) => _Sized(
    state,
    Surface.toasts,
    alignment: Alignment.topRight,
    builder: (context, _) => NotificationToasts(
      center: state.notifications,
      onTap: state.openNotification,
    ),
  );
}

/// O aviso de volume, acima da dock; não recebe cliques.
class _OsdView extends StatelessWidget {
  final ShellState state;
  const _OsdView(this.state);

  @override
  Widget build(BuildContext context) => _Sized(
    state,
    Surface.osd,
    alignment: Alignment.bottomCenter,
    builder: (context, _) => ListenableBuilder(
      listenable: Listenable.merge([state.osd, state.services.audio.state]),
      builder: (context, _) => state.osd.value
          ? VolumeOsd(state: state.services.audio.state.value)
          : const SizedBox.shrink(),
    ),
  );
}
