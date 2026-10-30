// Contrato entre o shell e os apps do Psito OS.
//
// Os apps só conhecem o que está aqui: nada de screens/, widgets/ ou shell/.
// Na fase 4 este contrato vira o protocolo entre processos, então tudo que um
// app pede ao shell precisa passar pelo PsitoAppContext.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Descrição de um app: o que aparece na dock/launcher e como construí-lo.
abstract class PsitoApp {
  const PsitoApp();

  String get id;
  String get name;
  IconData get icon;
  Color get color;

  /// Tamanho da janela ao abrir.
  Size get defaultSize => const Size(480, 360);

  /// Se true, abrir de novo foca a janela existente em vez de criar outra.
  bool get singleInstance => false;

  /// Se true, o app pode alterar as configurações do sistema
  /// ([PsitoAppContext.updateSettings]). Só o app Configurações.
  bool get canChangeSettings => false;

  Widget build(PsitoAppContext context);

  void onOpen(PsitoAppContext context) {}

  void onClose(PsitoAppContext context) {}
}

/// Tudo o que um app pode pedir ao shell, por janela.
abstract class PsitoAppContext {
  /// Id da janela no shell.
  String get windowId;

  void setTitle(String title);

  void close();

  void notify(PsitoNotification notification);

  /// Configurações do sistema; qualquer app pode ler e acompanhar.
  ValueListenable<PsitoSettings> get settings;

  /// Ignorado se o app não tiver [PsitoApp.canChangeSettings].
  void updateSettings(PsitoSettings settings);
}

class PsitoNotification {
  final String title;
  final String? body;

  const PsitoNotification({required this.title, this.body});
}

/// Papel de parede predefinido: uma cor é sólido, duas ou mais é degradê.
class PsitoWallpaper {
  final String id;
  final String name;
  final List<Color> colors;

  const PsitoWallpaper(this.id, this.name, this.colors);
}

const psitoWallpapers = [
  PsitoWallpaper('noite', 'Noite', [Color(0xFF12181B)]),
  PsitoWallpaper('calopsita', 'Calopsita', [
    Color(0xFF12181B),
    Color(0xFF3A2E12),
  ]),
  PsitoWallpaper('por-do-sol', 'Pôr do sol', [
    Color(0xFF2B1220),
    Color(0xFF5C2A12),
  ]),
  PsitoWallpaper('floresta', 'Floresta', [
    Color(0xFF0E1F17),
    Color(0xFF1F3A26),
  ]),
  PsitoWallpaper('oceano', 'Oceano', [Color(0xFF0B1A2B), Color(0xFF12405C)]),
];

PsitoWallpaper wallpaperById(String id) => psitoWallpapers.firstWhere(
  (w) => w.id == id,
  orElse: () => psitoWallpapers.first,
);

const psitoAccentColors = [
  Color(0xFFFFC107), // amarelo calopsita
  Color(0xFFFF5722), // laranja bochecha
  Color(0xFF4CAF50),
  Color(0xFF2196F3),
  Color(0xFF9C27B0),
  Color(0xFFE91E63),
];

/// Atalho global, só para exibir. A etapa 6 da fase 1 liga as teclas.
class PsitoShortcut {
  final String action;

  /// Combinação de um SO de verdade (Super, Alt+Tab).
  final String native;

  /// Combinação que passa pelo host e pelo QEMU na VM de desenvolvimento.
  final String vm;

  const PsitoShortcut(this.action, this.native, this.vm);
}

const psitoShortcuts = [
  PsitoShortcut('Abrir e fechar o launcher', 'Super', 'Ctrl+Espaço'),
  PsitoShortcut('Alternar janelas', 'Alt+Tab', 'Alt+` ou Ctrl+Tab'),
  PsitoShortcut('Fechar a janela', 'Alt+F4 / Super+Q', 'Ctrl+Alt+W'),
  PsitoShortcut(
    'Maximizar ou snap',
    'Super+↑ / ← / →',
    'Ctrl+Alt+Shift+↑ / ← / →',
  ),
  PsitoShortcut('Minimizar', 'Super+↓', 'Ctrl+Alt+Shift+↓'),
  PsitoShortcut('Fechar launcher ou painel', 'Esc', 'Esc'),
];

/// Preferências do sistema. O JSON de [toJson] é o formato do arquivo de
/// configurações e, na fase 4, do protocolo.
@immutable
class PsitoSettings {
  final Color accent;
  final String wallpaperId;
  final bool use24h;
  final bool showSeconds;
  final bool doNotDisturb;

  const PsitoSettings({
    this.accent = const Color(0xFFFFC107),
    this.wallpaperId = 'noite',
    this.use24h = true,
    this.showSeconds = false,
    this.doNotDisturb = false,
  });

  static const defaults = PsitoSettings();

  PsitoWallpaper get wallpaper => wallpaperById(wallpaperId);

  PsitoSettings copyWith({
    Color? accent,
    String? wallpaperId,
    bool? use24h,
    bool? showSeconds,
    bool? doNotDisturb,
  }) => PsitoSettings(
    accent: accent ?? this.accent,
    wallpaperId: wallpaperId ?? this.wallpaperId,
    use24h: use24h ?? this.use24h,
    showSeconds: showSeconds ?? this.showSeconds,
    doNotDisturb: doNotDisturb ?? this.doNotDisturb,
  );

  Map<String, Object?> toJson() => {
    'accent': accent.toARGB32(),
    'wallpaper': wallpaperId,
    'use24h': use24h,
    'showSeconds': showSeconds,
    'doNotDisturb': doNotDisturb,
  };

  /// Campos ausentes ou de tipo errado ficam com o padrão.
  factory PsitoSettings.fromJson(Map<String, Object?> json) {
    T pick<T>(String key, T fallback) {
      final value = json[key];
      return value is T ? value : fallback;
    }

    return PsitoSettings(
      accent: Color(pick<int>('accent', defaults.accent.toARGB32())),
      wallpaperId: pick('wallpaper', defaults.wallpaperId),
      use24h: pick('use24h', defaults.use24h),
      showSeconds: pick('showSeconds', defaults.showSeconds),
      doNotDisturb: pick('doNotDisturb', defaults.doNotDisturb),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PsitoSettings &&
      other.accent == accent &&
      other.wallpaperId == wallpaperId &&
      other.use24h == use24h &&
      other.showSeconds == showSeconds &&
      other.doNotDisturb == doNotDisturb;

  @override
  int get hashCode =>
      Object.hash(accent, wallpaperId, use24h, showSeconds, doNotDisturb);
}
