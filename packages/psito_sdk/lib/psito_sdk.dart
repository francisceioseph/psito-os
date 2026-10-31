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

  /// Nome do computador e versões do sistema; só leitura.
  ValueListenable<PsitoSystemInfo> get systemInfo;

  /// Estado da rede; só leitura (ligar e desligar fica com o shell).
  ValueListenable<PsitoNetworkState> get network;
}

/// O que o sistema diz de si (hostnamed no Linux).
@immutable
class PsitoSystemInfo {
  /// False enquanto carrega ou se o serviço não existe.
  final bool available;
  final String hostname;
  final String osName;
  final String kernel;

  /// Fabricante e modelo, quando o sistema informa.
  final String? hardware;

  const PsitoSystemInfo({
    required this.available,
    this.hostname = '',
    this.osName = '',
    this.kernel = '',
    this.hardware,
  });

  static const unavailable = PsitoSystemInfo(available: false);

  @override
  bool operator ==(Object other) =>
      other is PsitoSystemInfo &&
      other.available == available &&
      other.hostname == hostname &&
      other.osName == osName &&
      other.kernel == kernel &&
      other.hardware == hardware;

  @override
  int get hashCode =>
      Object.hash(available, hostname, osName, kernel, hardware);
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
  PsitoShortcut('Alternar janelas', 'Alt+Tab', 'Ctrl+Tab'),
  PsitoShortcut('Fechar a janela', 'Alt+F4 / Super+Q', 'Ctrl+Alt+W'),
  PsitoShortcut('Maximizar', 'Super+↑', 'Alt+Shift+↑'),
  PsitoShortcut('Snap à esquerda / direita', 'Super+← / →', 'Alt+Shift+← / →'),
  PsitoShortcut('Minimizar', 'Super+↓', 'Alt+Shift+↓'),
  PsitoShortcut(
    'Subir / baixar o volume',
    'Teclas de volume',
    'Alt+Shift+PageUp / PageDown',
  ),
  PsitoShortcut('Silenciar', 'Tecla de mudo', 'Alt+Shift+M'),
  PsitoShortcut('Fechar launcher, painel ou seletor', 'Esc', 'Esc'),
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

enum PsitoConnectivity { unknown, none, portal, limited, full }

enum PsitoNetworkKind { ethernet, wifi, other }

enum PsitoDeviceState {
  /// Sem cabo ou sem rádio.
  unavailable,
  disconnected,
  connecting,
  connected,
  other,
}

@immutable
class PsitoNetworkDevice {
  final String interface;
  final PsitoNetworkKind kind;
  final PsitoDeviceState state;

  /// Nome da conexão ativa no dispositivo.
  final String? connection;

  /// Ex.: 10.0.2.15/24.
  final String? ipv4;

  /// 0–100, só em Wi-Fi.
  final int? wifiStrength;

  const PsitoNetworkDevice({
    required this.interface,
    required this.kind,
    required this.state,
    this.connection,
    this.ipv4,
    this.wifiStrength,
  });

  @override
  bool operator ==(Object other) =>
      other is PsitoNetworkDevice &&
      other.interface == interface &&
      other.kind == kind &&
      other.state == state &&
      other.connection == connection &&
      other.ipv4 == ipv4 &&
      other.wifiStrength == wifiStrength;

  @override
  int get hashCode =>
      Object.hash(interface, kind, state, connection, ipv4, wifiStrength);
}

/// O que a rede está fazendo (NetworkManager no Linux).
@immutable
class PsitoNetworkState {
  /// False enquanto carrega ou se não há gerenciador de rede.
  final bool available;
  final bool enabled;
  final PsitoConnectivity connectivity;
  final bool connecting;

  /// Dispositivo da conexão principal, com o nome e o IP dela.
  final PsitoNetworkDevice? primary;
  final List<PsitoNetworkDevice> devices;

  const PsitoNetworkState({
    required this.available,
    this.enabled = true,
    this.connectivity = PsitoConnectivity.unknown,
    this.connecting = false,
    this.primary,
    this.devices = const [],
  });

  static const unavailable = PsitoNetworkState(available: false);

  @override
  bool operator ==(Object other) =>
      other is PsitoNetworkState &&
      other.available == available &&
      other.enabled == enabled &&
      other.connectivity == connectivity &&
      other.connecting == connecting &&
      other.primary == primary &&
      listEquals(other.devices, devices);

  @override
  int get hashCode => Object.hash(
    available,
    enabled,
    connectivity,
    connecting,
    primary,
    Object.hashAll(devices),
  );
}
