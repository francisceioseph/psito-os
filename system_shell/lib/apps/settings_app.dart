// system_shell/lib/apps/settings_app.dart
//
// Lê e altera as configurações do sistema só pelo PsitoAppContext.
import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

enum _Section {
  appearance('Aparência', Icons.palette_outlined),
  dateTime('Data e hora', Icons.schedule),
  notifications('Notificações', Icons.notifications_none),
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

  void _update(PsitoSettings settings) =>
      widget.appContext.updateSettings(settings);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNav(),
        const VerticalDivider(width: 1, color: Colors.white12),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: widget.appContext.settings,
            builder: (context, settings, _) => ListView(
              padding: const EdgeInsets.all(24),
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
                  _Section.notifications => _notifications(settings),
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

  Widget _buildNav() {
    final accent = Theme.of(context).colorScheme.primary;
    // Material (e não Container com cor): os ListTile pintam o realce nele
    return Material(
      color: Colors.black.withValues(alpha: 0.15),
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            for (final section in _Section.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
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
    const _Note(
      'Ajustar a data e a hora do sistema chega na fase 2, junto com os '
      'serviços via D-Bus.',
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
      'por isso cada ação tem uma combinação alternativa. Os atalhos passam '
      'a funcionar na etapa 6 da fase 1.',
    ),
  ];

  List<Widget> _about() => const [
    _Cell('Psito OS v0.0.1'),
    _Cell(
      'Shell em Flutter desenhado direto no DRM/KMS pelo flutter-pi, '
      'sem X11 nem Wayland.',
    ),
    SizedBox(height: 12),
    _Note('Configurações salvas em ~/.config/psito/settings.json'),
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
