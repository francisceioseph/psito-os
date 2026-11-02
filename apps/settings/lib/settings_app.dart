// apps/settings/lib/settings_app.dart
//
// Lê e altera as configurações do sistema só pelo PsitoAppContext.
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'l10n/l10n.dart';
import 'format_disk_view.dart';
import 'network_section.dart';
import 'settings_ui.dart';
import 'storage_section.dart';
import 'users_section.dart';

enum _Section {
  appearance(Icons.palette_outlined),
  dock(Icons.call_to_action_outlined),
  desktop(Icons.desktop_windows_outlined),
  notifications(Icons.notifications_none),
  language(Icons.language),
  network(Icons.lan_outlined),
  storage(Icons.storage_outlined),
  power(Icons.battery_std_outlined),
  dateTime(Icons.schedule),
  users(Icons.people_outline),
  privacy(Icons.lock_outline),
  shortcuts(Icons.keyboard_outlined),
  about(Icons.info_outline);

  final IconData icon;

  const _Section(this.icon);

  String label(SettingsLocalizations l) => switch (this) {
    appearance => l.sectionAppearance,
    users => l.sectionUsers,
    privacy => l.sectionPrivacy,
    language => l.sectionLanguage,
    dock => l.sectionDock,
    desktop => l.sectionDesktop,
    dateTime => l.sectionDateTime,
    network => l.sectionNetwork,
    storage => l.sectionStorage,
    notifications => l.sectionNotifications,
    power => l.sectionPower,
    shortcuts => l.sectionShortcuts,
    about => l.sectionAbout,
  };
}

class SettingsView extends StatefulWidget {
  final PsitoAppContext appContext;

  const SettingsView({super.key, required this.appContext});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // A seção pedida nos argumentos, ou a primeira
  late _Section _section = _Section.values.firstWhere(
    (section) => widget.appContext.openedPaths.contains(
      '$psitoSettingsSectionPrefix${section.name}',
    ),
    orElse: () => _Section.appearance,
  );

  /// Escolha de fuso aberta na seção Data e hora.
  bool _pickingTimezone = false;
  String _timezoneQuery = '';
  late final Future<List<String>> _timezones = widget.appContext.timezones();

  /// "America/Sao_Paulo" vira "America · Sao Paulo".
  static String timezoneLabel(String name) =>
      name.replaceAll('_', ' ').split('/').join(' · ');

  static String _fold(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[_/·\s]+'), ' ').trim();

  void _update(PsitoSettings settings) =>
      widget.appContext.updateSettings(settings);

  @override
  Widget build(BuildContext context) {
    // Janela estreita: o menu lateral fica só com os ícones
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildBody(compact: constraints.maxWidth < 480),
    );
  }

  /// A coluna do conteúdo não cresce com a janela: linhas muito longas afastam
  /// o nome do controle.
  static const _contentWidth = 640.0;

  /// A lista lateral, em grupos.
  List<(String, List<_Section>)> _navGroups(SettingsLocalizations l) => [
    (
      l.sectionGroupPersonal,
      const [
        _Section.appearance,
        _Section.dock,
        _Section.desktop,
        _Section.notifications,
        _Section.language,
      ],
    ),
    (
      l.sectionGroupSystem,
      const [
        _Section.network,
        _Section.storage,
        _Section.power,
        _Section.dateTime,
        _Section.users,
        _Section.privacy,
      ],
    ),
    (l.sectionGroupMore, const [_Section.shortcuts, _Section.about]),
  ];

  Widget _buildBody({required bool compact}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNav(compact: compact),
        VerticalDivider(width: 1, color: context.palette.lineSoft),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = compact
                  ? 12.0
                  : max(24.0, (constraints.maxWidth - _contentWidth) / 2);
              return ValueListenableBuilder(
                valueListenable: widget.appContext.settings,
                builder: (context, settings, _) => ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: side,
                    vertical: compact ? 12 : 24,
                  ),
                  children: [
                    Text(
                      _section.label(context.l10n),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...switch (_section) {
                      _Section.appearance => _appearance(settings),
                      _Section.users => [
                        UsersSection(accounts: widget.appContext.accounts),
                      ],
                      _Section.privacy => _privacy(settings),
                      _Section.language => _language(settings),
                      _Section.dock => _dock(settings),
                      _Section.desktop => _desktop(settings),
                      _Section.dateTime => _dateTime(settings),
                      _Section.network => _network(),
                      _Section.storage => [
                        StorageSection(storage: widget.appContext.storage),
                      ],
                      _Section.notifications => _notifications(settings),
                      _Section.power => _power(settings),
                      _Section.shortcuts => _shortcuts(),
                      _Section.about => _about(),
                    },
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNav({required bool compact}) {
    final accent = Theme.of(context).colorScheme.primary;
    final palette = context.palette;
    final l = context.l10n;
    Widget item(_Section section) => compact
        ? IconButton(
            tooltip: section.label(l),
            isSelected: section == _section,
            color: section == _section ? accent : null,
            icon: Icon(section.icon, size: 18),
            onPressed: () => setState(() => _section = section),
          )
        : ListTile(
            dense: true,
            minTileHeight: 34,
            minVerticalPadding: 0,
            selected: section == _section,
            selectedColor: accent,
            selectedTileColor: accent.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            leading: Icon(section.icon, size: 18),
            horizontalTitleGap: 10,
            minLeadingWidth: 18,
            title: Text(section.label(l)),
            onTap: () => setState(() => _section = section),
          );
    // Material (e não Container com cor): os ListTile pintam o realce nele
    return Material(
      color: palette.shadow.withValues(alpha: 0.15),
      child: SizedBox(
        width: compact ? 56 : 212,
        child: ListView(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 4 : 12,
            horizontal: compact ? 4 : 10,
          ),
          children: [
            for (final (i, (title, sections)) in _navGroups(l).indexed) ...[
              if (compact && i > 0) Divider(color: palette.lineSoft),
              if (!compact)
                Padding(
                  padding: EdgeInsets.fromLTRB(10, i == 0 ? 4 : 16, 10, 6),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.textTertiary,
                    ),
                  ),
                ),
              for (final section in sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: item(section),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Na ordem do [psitoAccentColors]: quem não vê a cor ouve o nome dela.
  static List<String> _accentNames(SettingsLocalizations l) => [
    l.accentYellow,
    l.accentOrange,
    l.accentGreen,
    l.accentBlue,
    l.accentPurple,
    l.accentPink,
  ];

  List<Widget> _appearance(PsitoSettings s) => [
    SettingsGroup(
      title: context.l10n.accentColor,
      children: [
        SettingsPad(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (i, color) in psitoAccentColors.indexed)
                Semantics(
                  button: true,
                  selected: s.accent == color,
                  label: _accentNames(context.l10n)[i],
                  child: GestureDetector(
                    key: ValueKey('accent-${color.toARGB32()}'),
                    onTap: () => _update(s.copyWith(accent: color)),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: s.accent == color
                              ? context.palette.text
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: s.accent == color
                          ? Icon(
                              Icons.check,
                              size: 18,
                              color: context.palette.onAccent,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
    SettingsGroup(
      title: context.l10n.wallpaper,
      children: [
        SettingsPad(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final w in psitoWallpapers)
                _WallpaperCard(
                  wallpaper: w,
                  selected: s.wallpaperId == w.id,
                  onTap: () => _update(s.copyWith(wallpaperId: w.id)),
                ),
            ],
          ),
        ),
      ],
    ),
  ];

  List<Widget> _dock(PsitoSettings s) => [
    SettingsGroup(
      children: [
        SettingsRow(
          title: context.l10n.iconSize,
          control: _DockSizeSlider(
            value: s.dockIconSize,
            onChanged: (v) => _update(s.copyWith(dockIconSize: v)),
          ),
        ),
        SwitchListTile(
          title: Text(context.l10n.magnification),
          subtitle: Text(context.l10n.magnificationHint),
          value: s.dockMagnification,
          onChanged: (v) => _update(s.copyWith(dockMagnification: v)),
        ),
      ],
    ),
    SettingsGroup(
      children: [
        SettingsRow(
          title: context.l10n.screenPosition,
          control: SegmentedButton<PsitoDockPosition>(
            segments: [
              for (final position in PsitoDockPosition.values)
                ButtonSegment(
                  value: position,
                  label: Text(position.label(SdkLocalizations.of(context))),
                ),
            ],
            selected: {s.dockPosition},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                _update(s.copyWith(dockPosition: value.single)),
          ),
        ),
        SwitchListTile(
          title: Text(context.l10n.autoHide),
          subtitle: Text(context.l10n.autoHideHint),
          value: s.dockAutoHide,
          onChanged: (v) => _update(s.copyWith(dockAutoHide: v)),
        ),
      ],
    ),
  ];

  List<Widget> _desktop(PsitoSettings s) => [
    SettingsGroup(
      children: [
        SwitchListTile(
          title: Text(context.l10n.desktopShowIcons),
          subtitle: Text(context.l10n.desktopShowIconsHint),
          value: s.desktopShowIcons,
          onChanged: (v) => _update(s.copyWith(desktopShowIcons: v)),
        ),
        if (s.desktopShowIcons)
          SettingsRow(
            title: context.l10n.iconSize,
            control: _DockSizeSlider(
              value: s.desktopIconSize,
              onChanged: (v) => _update(s.copyWith(desktopIconSize: v)),
            ),
          ),
      ],
    ),
    if (s.desktopShowIcons) ...[
      SettingsGroup(
        children: [
          SwitchListTile(
            title: Text(context.l10n.desktopHome),
            value: s.desktopShowHome,
            onChanged: (v) => _update(s.copyWith(desktopShowHome: v)),
          ),
          SwitchListTile(
            title: Text(context.l10n.desktopTrash),
            value: s.desktopShowTrash,
            onChanged: (v) => _update(s.copyWith(desktopShowTrash: v)),
          ),
          SwitchListTile(
            key: const ValueKey('desktop-volumes'),
            title: Text(context.l10n.desktopVolumes),
            value: s.desktopShowVolumes,
            onChanged: (v) => _update(s.copyWith(desktopShowVolumes: v)),
          ),
        ],
      ),
      SettingsGroup(
        children: [
          SwitchListTile(
            title: Text(context.l10n.desktopAutoArrange),
            subtitle: Text(context.l10n.desktopAutoArrangeHint),
            value: s.desktopAutoArrange,
            onChanged: (v) => _update(s.copyWith(desktopAutoArrange: v)),
          ),
          SwitchListTile(
            title: Text(context.l10n.desktopHotCorner),
            subtitle: Text(context.l10n.desktopHotCornerHint),
            value: s.desktopHotCorner,
            onChanged: (v) => _update(s.copyWith(desktopHotCorner: v)),
          ),
        ],
      ),
    ],
  ];

  List<Widget> _dateTime(PsitoSettings s) => [
    SettingsGroup(
      children: [
        SwitchListTile(
          title: Text(context.l10n.use24h),
          subtitle: Text(s.use24h ? '16:41' : '4:41 PM'),
          value: s.use24h,
          onChanged: (v) => _update(s.copyWith(use24h: v)),
        ),
        SwitchListTile(
          title: Text(context.l10n.showSeconds),
          value: s.showSeconds,
          onChanged: (v) => _update(s.copyWith(showSeconds: v)),
        ),
      ],
    ),
    ValueListenableBuilder(
      valueListenable: widget.appContext.time,
      builder: (context, time, _) {
        if (!time.available) {
          return SettingsNote(context.l10n.timeUnavailable);
        }
        return SettingsGroup(
          footer: context.l10n.ntpHint,
          children: [
            SwitchListTile(
              title: Text(context.l10n.ntp),
              subtitle: Text(
                !time.ntp
                    ? context.l10n.ntpOff
                    : time.ntpSynchronized
                    ? context.l10n.ntpSynced
                    : context.l10n.ntpWaiting,
              ),
              value: time.ntp,
              onChanged: time.canNtp ? widget.appContext.setNtp : null,
            ),
            if (_pickingTimezone)
              SettingsPad(child: _timezonePicker(time.timezone))
            else
              ListTile(
                title: Text(context.l10n.timezone),
                subtitle: Text(timezoneLabel(time.timezone)),
                trailing: TextButton(
                  onPressed: () => setState(() => _pickingTimezone = true),
                  child: Text(context.l10n.change),
                ),
              ),
          ],
        );
      },
    ),
  ];

  Widget _timezonePicker(String current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: context.l10n.timezoneSearch,
                  isDense: true,
                ),
                onChanged: (q) => setState(() => _timezoneQuery = q),
              ),
            ),
            IconButton(
              tooltip: context.l10n.cancel,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() {
                _pickingTimezone = false;
                _timezoneQuery = '';
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder(
          future: _timezones,
          builder: (context, snapshot) {
            final query = _fold(_timezoneQuery);
            final matches = (snapshot.data ?? const <String>[])
                .where((name) => _fold(name).contains(query))
                .take(50)
                .toList();
            return SizedBox(
              height: 220,
              child: ListView(
                children: [
                  for (final name in matches)
                    ListTile(
                      dense: true,
                      selected: name == current,
                      title: Text(timezoneLabel(name)),
                      onTap: () {
                        widget.appContext.setTimezone(name);
                        setState(() {
                          _pickingTimezone = false;
                          _timezoneQuery = '';
                        });
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _network() => [
    ValueListenableBuilder(
      valueListenable: widget.appContext.network,
      builder: (context, network, _) {
        if (!network.available) {
          return SettingsNote(context.l10n.networkManagerUnavailable);
        }
        if (network.devices.isEmpty) {
          return SettingsNote(context.l10n.noNetworkDevice);
        }
        return NetworkSection(
          network: network,
          connections: widget.appContext.networkConnections,
          pickFile: widget.appContext.pickFile,
        );
      },
    ),
    SettingsNote(context.l10n.networkHint),
  ];

  List<Widget> _notifications(PsitoSettings s) => [
    SettingsGroup(
      children: [
        SwitchListTile(
          title: Text(context.l10n.doNotDisturb),
          subtitle: Text(context.l10n.doNotDisturbHint),
          value: s.doNotDisturb,
          onChanged: (v) => _update(s.copyWith(doNotDisturb: v)),
        ),
      ],
    ),
  ];

  List<Widget> _power(PsitoSettings s) => [
    SettingsGroup(
      children: [
        SwitchListTile(
          title: Text(context.l10n.showBatteryPercentage),
          subtitle: Text(context.l10n.batteryHint),
          value: s.showBatteryPercentage,
          onChanged: (v) => _update(s.copyWith(showBatteryPercentage: v)),
        ),
      ],
    ),
  ];

  List<Widget> _shortcuts() => [
    SettingsGroup(
      footer: context.l10n.shortcutsNote,
      children: [
        SettingsPad(
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(3),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  _Label(context.l10n.shortcutAction),
                  _Label(context.l10n.shortcutNative),
                  _Label('VM'),
                ],
              ),
              for (final sc in psitoShortcuts(SdkLocalizations.of(context)))
                TableRow(
                  children: [
                    _Cell(sc.action),
                    _Cell(sc.native, keys: true),
                    _Cell(sc.vm, keys: true),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
  ];

  List<Widget> _privacy(PsitoSettings s) => [
    SettingsGroup(
      title: context.l10n.lockAfter,
      footer: context.l10n.lockNote,
      children: [
        SettingsPad(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in const [1, 5, 15, 0])
                ChoiceChip(
                  label: Text(
                    minutes == 0
                        ? context.l10n.lockNever
                        : context.l10n.lockMinutes(minutes),
                  ),
                  selected: s.lockAfterMinutes == minutes,
                  onSelected: (_) =>
                      _update(s.copyWith(lockAfterMinutes: minutes)),
                ),
            ],
          ),
        ),
      ],
    ),
  ];

  List<Widget> _language(PsitoSettings s) => [
    SettingsGroup(
      footer: context.l10n.languageNote,
      children: [
        for (final (code, label) in [
          ('', context.l10n.languageSystem),
          // Cada idioma com o nome dele, para quem não lê o que está na tela
          ('en', 'English'),
          ('pt', 'Português'),
        ])
          ListTile(
            title: Text(label),
            selected: s.language == code,
            trailing: s.language == code
                ? const Icon(Icons.check, size: 18)
                : null,
            onTap: () => _update(s.copyWith(language: code)),
          ),
      ],
    ),
  ];

  List<Widget> _about() => [
    SettingsGroup(
      footer: context.l10n.settingsPath,
      children: [
        SettingsPad(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Cell('Psito OS v0.0.1'),
              _Cell(context.l10n.aboutDescription),
              const SizedBox(height: 8),
              ValueListenableBuilder(
                valueListenable: widget.appContext.systemInfo,
                builder: (context, info, _) {
                  if (!info.available) {
                    return SettingsNote(context.l10n.systemInfoUnavailable);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InfoRow(context.l10n.computerName, info.hostname),
                      _InfoRow(context.l10n.system, info.osName),
                      _InfoRow('Kernel', info.kernel),
                      if (info.hardware case final hardware?)
                        _InfoRow(context.l10n.hardware, hardware),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    ),
  ];
}

class _WallpaperCard extends StatelessWidget {
  final PsitoWallpaper wallpaper;
  final bool selected;
  final VoidCallback onTap;

  const _WallpaperCard({
    required this.wallpaper,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final colors = wallpaper.colors;
    return Semantics(
      button: true,
      selected: selected,
      onTap: onTap,
      child: GestureDetector(
        key: ValueKey('wallpaper-card-${wallpaper.id}'),
        onTap: onTap,
        excludeFromSemantics: true,
        child: Column(
          children: [
            Container(
              width: 112,
              height: 68,
              decoration: BoxDecoration(
                color: colors.first,
                gradient: colors.length > 1
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      )
                    : null,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? accent : context.palette.line,
                  width: selected ? 2.5 : 1,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              wallpaper.name(SdkLocalizations.of(context)),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grava só ao soltar, e não a cada passo do arrastar: cada gravação vai
/// pelo D-Bus e faz a dock mudar de tamanho.
class _DockSizeSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _DockSizeSlider({required this.value, required this.onChanged});

  @override
  State<_DockSizeSlider> createState() => _DockSizeSliderState();
}

class _DockSizeSliderState extends State<_DockSizeSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    const sizes = PsitoSettings.dockSizes;
    final value = _dragging ?? widget.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          child: Slider(
            min: sizes.min,
            max: sizes.max,
            divisions: ((sizes.max - sizes.min) / 4).round(),
            value: value,
            label: '${value.round()} px',
            onChanged: (v) => setState(() => _dragging = v),
            onChangeEnd: (v) {
              setState(() => _dragging = null);
              widget.onChanged(v);
            },
          ),
        ),
        SizedBox(width: 56, child: Text('${value.round()} px')),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: context.palette.textSecondary,
      ),
    ),
  );
}

class _Cell extends StatelessWidget {
  final String text;

  /// Combinação de teclas: fonte monoespaçada.
  final bool keys;

  const _Cell(this.text, {this.keys = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontFamily: keys ? 'monospace' : null,
        color: keys ? context.palette.text : context.palette.textSecondary,
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 168,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: context.palette.textQuiet),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: context.palette.text),
          ),
        ),
      ],
    ),
  );
}

class SettingsApp extends PsitoApp {
  const SettingsApp();

  @override
  String get id => 'settings';

  @override
  String get name => 'Settings';

  @override
  String localizedName(Locale locale) =>
      lookupSettingsLocalizations(locale).appName;

  @override
  List<LocalizationsDelegate<dynamic>> get localizationsDelegates => const [
    SettingsLocalizations.delegate,
  ];

  @override
  IconData get icon => Icons.settings_rounded;

  @override
  Color get color => const Color(0xFF607D8B);

  @override
  Size get defaultSize => const Size(880, 600);

  @override
  Size sizeFor(PsitoAppContext context) =>
      formatDiskArgument(context.openedPaths) == null
      ? defaultSize
      : const Size(420, 400);

  @override
  bool get singleInstance => true;

  @override
  bool get canChangeSettings => true;

  @override
  Widget build(PsitoAppContext context) =>
      switch (formatDiskArgument(context.openedPaths)) {
        final id? => FormatDiskView(appContext: context, id: id),
        null => SettingsView(appContext: context),
      };
}
