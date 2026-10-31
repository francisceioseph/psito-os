// system_shell/lib/apps/settings_app.dart
//
// Lê e altera as configurações do sistema só pelo PsitoAppContext.
import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

enum _Section {
  appearance('Aparência', Icons.palette_outlined),
  dateTime('Data e hora', Icons.schedule),
  network('Rede', Icons.lan_outlined),
  notifications('Notificações', Icons.notifications_none),
  power('Energia', Icons.battery_std_outlined),
  shortcuts('Atalhos', Icons.keyboard_outlined),
  about('Sobre', Icons.info_outline);

  final String label;
  final IconData icon;

  const _Section(this.label, this.icon);
}

class SettingsView extends StatefulWidget {
  final PsitoAppContext appContext;

  const SettingsView({super.key, required this.appContext});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  _Section _section = _Section.appearance;

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

  Widget _buildBody({required bool compact}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNav(compact: compact),
        const VerticalDivider(width: 1, color: Colors.white12),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: widget.appContext.settings,
            builder: (context, settings, _) => ListView(
              padding: EdgeInsets.all(compact ? 12 : 24),
              children: [
                Text(
                  _section.label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...switch (_section) {
                  _Section.appearance => _appearance(settings),
                  _Section.dateTime => _dateTime(settings),
                  _Section.network => _network(),
                  _Section.notifications => _notifications(settings),
                  _Section.power => _power(settings),
                  _Section.shortcuts => _shortcuts(),
                  _Section.about => _about(),
                },
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNav({required bool compact}) {
    final accent = Theme.of(context).colorScheme.primary;
    // Material (e não Container com cor): os ListTile pintam o realce nele
    return Material(
      color: Colors.black.withValues(alpha: 0.15),
      child: SizedBox(
        width: compact ? 56 : 180,
        child: ListView(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 4 : 12,
            horizontal: compact ? 4 : 8,
          ),
          children: [
            for (final section in _Section.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: compact
                    ? IconButton(
                        tooltip: section.label,
                        isSelected: section == _section,
                        color: section == _section ? accent : null,
                        icon: Icon(section.icon, size: 18),
                        onPressed: () => setState(() => _section = section),
                      )
                    : ListTile(
                        dense: true,
                        selected: section == _section,
                        selectedColor: accent,
                        selectedTileColor: accent.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        leading: Icon(section.icon, size: 18),
                        title: Text(section.label),
                        onTap: () => setState(() => _section = section),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _appearance(PsitoSettings s) => [
    const _Label('Cor de destaque'),
    Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final color in psitoAccentColors)
          GestureDetector(
            key: ValueKey('accent-${color.toARGB32()}'),
            onTap: () => _update(s.copyWith(accent: color)),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: s.accent == color ? Colors.white : Colors.transparent,
                  width: 3,
                ),
              ),
              child: s.accent == color
                  ? const Icon(Icons.check, size: 18, color: Colors.black87)
                  : null,
            ),
          ),
      ],
    ),
    const SizedBox(height: 24),
    const _Label('Papel de parede'),
    Wrap(
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
  ];

  List<Widget> _dateTime(PsitoSettings s) => [
    SwitchListTile(
      title: const Text('Formato 24 horas'),
      subtitle: Text(s.use24h ? '16:41' : '4:41 PM'),
      value: s.use24h,
      onChanged: (v) => _update(s.copyWith(use24h: v)),
    ),
    SwitchListTile(
      title: const Text('Mostrar segundos'),
      value: s.showSeconds,
      onChanged: (v) => _update(s.copyWith(showSeconds: v)),
    ),
    const SizedBox(height: 8),
    ValueListenableBuilder(
      valueListenable: widget.appContext.time,
      builder: (context, time, _) {
        if (!time.available) {
          return const _Note(
            'Data e hora do sistema indisponíveis (timedated)',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: const Text('Ajustar automaticamente'),
              subtitle: Text(
                !time.ntp
                    ? 'Desligado'
                    : time.ntpSynchronized
                    ? 'Sincronizado com a internet'
                    : 'Aguardando sincronização',
              ),
              value: time.ntp,
              onChanged: time.canNtp ? widget.appContext.setNtp : null,
            ),
            if (_pickingTimezone)
              _timezonePicker(time.timezone)
            else
              ListTile(
                title: const Text('Fuso horário'),
                subtitle: Text(timezoneLabel(time.timezone)),
                trailing: TextButton(
                  onPressed: () => setState(() => _pickingTimezone = true),
                  child: const Text('Alterar'),
                ),
              ),
            const _Note('Com o ajuste automático ligado, a hora vem da rede.'),
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
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Buscar fuso (ex.: sao paulo)',
                  isDense: true,
                ),
                onChanged: (q) => setState(() => _timezoneQuery = q),
              ),
            ),
            IconButton(
              tooltip: 'Cancelar',
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
          return const _Note('NetworkManager indisponível');
        }
        if (network.devices.isEmpty) {
          return const _Note('Nenhum dispositivo de rede');
        }
        return Column(
          children: [for (final device in network.devices) _DeviceTile(device)],
        );
      },
    ),
    const _Note(
      'Para ligar ou desligar a rede, use o ícone de rede na barra superior.',
    ),
  ];

  List<Widget> _notifications(PsitoSettings s) => [
    SwitchListTile(
      title: const Text('Não perturbe'),
      subtitle: const Text(
        'As notificações vão para o painel, sem aparecer na tela.',
      ),
      value: s.doNotDisturb,
      onChanged: (v) => _update(s.copyWith(doNotDisturb: v)),
    ),
  ];

  List<Widget> _power(PsitoSettings s) => [
    SwitchListTile(
      title: const Text('Mostrar porcentagem da bateria'),
      subtitle: const Text(
        'O ícone de bateria só aparece em computadores com bateria.',
      ),
      value: s.showBatteryPercentage,
      onChanged: (v) => _update(s.copyWith(showBatteryPercentage: v)),
    ),
  ];

  List<Widget> _shortcuts() => [
    Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(3),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        const TableRow(
          children: [_Label('Ação'), _Label('Nativo'), _Label('VM')],
        ),
        for (final sc in psitoShortcuts)
          TableRow(
            children: [
              _Cell(sc.action),
              _Cell(sc.native, keys: true),
              _Cell(sc.vm, keys: true),
            ],
          ),
      ],
    ),
    const SizedBox(height: 12),
    const _Note(
      'Super e Alt+Tab ficam com o sistema do computador e não chegam à VM; '
      'por isso cada ação tem uma combinação alternativa. As duas valem ao '
      'mesmo tempo. Em Alternar janelas, segure o modificador e aperte Tab '
      'para escolher; Shift volta.',
    ),
  ];

  List<Widget> _about() => [
    const _Cell('Psito OS v0.0.1'),
    const _Cell(
      'Shell em Flutter como cliente Wayland do labwc, '
      'com cada app no seu processo.',
    ),
    const SizedBox(height: 16),
    ValueListenableBuilder(
      valueListenable: widget.appContext.systemInfo,
      builder: (context, info, _) {
        if (!info.available) {
          return const _Note(
            'Informações do sistema indisponíveis (hostnamed)',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoRow('Nome do computador', info.hostname),
            _InfoRow('Sistema', info.osName),
            _InfoRow('Kernel', info.kernel),
            if (info.hardware case final hardware?)
              _InfoRow('Hardware', hardware),
          ],
        );
      },
    ),
    const SizedBox(height: 12),
    const _Note('Configurações salvas em ~/.config/psito/settings.json'),
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
    return GestureDetector(
      key: ValueKey('wallpaper-card-${wallpaper.id}'),
      onTap: onTap,
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
                color: selected ? accent : Colors.white24,
                width: selected ? 2.5 : 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(wallpaper.name, style: const TextStyle(fontSize: 12)),
        ],
      ),
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
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.white70,
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
        color: keys ? Colors.white : Colors.white70,
      ),
    ),
  );
}

class _DeviceTile extends StatelessWidget {
  final PsitoNetworkDevice device;

  const _DeviceTile(this.device);

  static String stateLabel(PsitoDeviceState state) => switch (state) {
    PsitoDeviceState.connected => 'Conectado',
    PsitoDeviceState.connecting => 'Conectando…',
    PsitoDeviceState.disconnected => 'Desconectado',
    PsitoDeviceState.unavailable => 'Sem cabo ou sinal',
    PsitoDeviceState.other => 'Não gerenciado',
  };

  @override
  Widget build(BuildContext context) {
    final details = [
      stateLabel(device.state),
      ?device.connection,
      ?device.ipv4,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(switch (device.kind) {
        PsitoNetworkKind.ethernet => Icons.lan,
        PsitoNetworkKind.wifi => Icons.wifi,
        PsitoNetworkKind.other => Icons.settings_ethernet,
      }),
      title: Text(device.interface),
      subtitle: Text(
        details,
        style: const TextStyle(fontSize: 12, color: Colors.white60),
      ),
    );
  }
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
          width: 150,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white54),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  final String text;

  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
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
  String get name => 'Configurações';

  @override
  IconData get icon => Icons.settings_rounded;

  @override
  Color get color => const Color(0xFF607D8B);

  @override
  Size get defaultSize => const Size(720, 480);

  @override
  bool get singleInstance => true;

  @override
  bool get canChangeSettings => true;

  @override
  Widget build(PsitoAppContext context) => SettingsView(appContext: context);
}
