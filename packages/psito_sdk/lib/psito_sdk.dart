// Contrato entre o shell e os apps do Psito OS.
//
// Os apps só conhecem o que está aqui: nada de screens/, widgets/ ou shell/.
// Na fase 4 este contrato vira o protocolo entre processos, então tudo que um
// app pede ao shell precisa passar pelo PsitoAppContext.
import 'dart:convert';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show Brightness, ColorScheme, Theme, ThemeData, ThemeExtension;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:intl/intl.dart' show NumberFormat;

import 'l10n/sdk_localizations.dart';

export 'l10n/sdk_localizations.dart';

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

  /// O nome no idioma [locale]. O nome do `.desktop` traduzido (`Name[pt]`)
  /// deve bater com este.
  String localizedName(Locale locale) => name;

  /// As traduções do app, além das do SDK e das do Flutter.
  List<LocalizationsDelegate<dynamic>> get localizationsDelegates => const [];

  /// Os idiomas que o app tem.
  List<Locale> get supportedLocales => psitoLocales;

  Widget build(PsitoAppContext context);

  void onOpen(PsitoAppContext context) {}

  void onClose(PsitoAppContext context) {}
}

/// O idioma em uso, para o que não tem um [BuildContext].
extension PsitoAppContextLocale on PsitoAppContext {
  Locale get locale => resolvePsitoLocale(settings.value.language);
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

  /// Fuso e sincronização do relógio do sistema.
  ValueListenable<PsitoTimeState> get time;

  /// Hora local no fuso atual do sistema. Use no lugar de `DateTime.now()`,
  /// cujo fuso fica congelado depois que o processo começa.
  DateTime now();

  /// Fusos que o sistema aceita (ex.: America/Sao_Paulo).
  Future<List<String>> timezones();

  /// Ignorado se o app não tiver [PsitoApp.canChangeSettings].
  void setTimezone(String timezone);

  /// Liga o ajuste automático (NTP). Ignorado sem
  /// [PsitoApp.canChangeSettings].
  void setNtp(bool enabled);

  /// As contas de usuário. Sem [PsitoApp.canChangeSettings], é a lista vazia e
  /// nenhuma ação vale.
  PsitoAccounts get accounts;

  /// As conexões de rede guardadas. Sem [PsitoApp.canChangeSettings], é a lista
  /// vazia e nenhuma ação vale.
  PsitoNetworkConnections get networkConnections;

  /// O uso dos discos. Sem [PsitoApp.canChangeSettings], é a lista vazia e
  /// nenhuma ação vale.
  PsitoStorage get storage;

  /// Os discos externos. Sem a permissão `files:removable`, a lista fica vazia.
  PsitoVolumes get volumes;

  /// Os arquivos com que o app foi aberto (o "Abrir" do Files ou de outro
  /// app). No sandbox, o que o app não veria chega montado em
  /// `$XDG_RUNTIME_DIR/doc/`.
  List<String> get openedPaths;

  /// Os arquivos que chegam com o app já aberto, num app de instância única
  /// ([PsitoApp.singleInstance]): o shell entrega a ele em vez de abrir
  /// outro processo.
  Stream<List<String>> get openRequests;

  /// Abre cada arquivo no app padrão do tipo dele, ou em [withApp] (o id do
  /// `.desktop`), pelo shell. Lança [PsitoOpenException] se nenhum app abre.
  Future<void> open(List<String> paths, {String? withApp});

  /// Os apps que abrem o tipo MIME, o padrão primeiro.
  Future<List<PsitoAppChoice>> appsFor(String mimeType);

  /// Muda o app padrão do tipo. Só para apps que veem os arquivos do
  /// usuário (`files:home`).
  Future<void> setDefaultApp(String mimeType, String appId);

  /// Se o shell abre neste app os arquivos que estão soltando na janela dele.
  /// Um app no sandbox não vê esses arquivos, então o shell abre: só o que quem
  /// arrasta ofereceu, e de um tipo que o app abre.
  Future<bool> acceptsDrop(List<String> paths);

  /// Abre os arquivos soltos na janela numa janela nova do app, que vê só eles.
  Future<bool> openDropped(List<String> paths);

  /// O seletor de arquivos do sistema. Devolve o caminho, ou null se a pessoa
  /// cancelou. [patterns] são filtros como `*.conf`. O caminho é o de fora do
  /// sandbox: o app só lê o arquivo se as permissões dele deixarem ver.
  Future<String?> pickFile({
    required String title,
    List<String> patterns = const [],
  });
}

/// Um app que abre um tipo de arquivo, para o "Abrir com".
@immutable
class PsitoAppChoice {
  /// O id do `.desktop`.
  final String id;
  final String name;

  /// O nome do ícone no tema.
  final String? icon;
  final bool isDefault;

  const PsitoAppChoice({
    required this.id,
    required this.name,
    this.icon,
    this.isDefault = false,
  });

  @override
  bool operator ==(Object other) =>
      other is PsitoAppChoice &&
      other.id == id &&
      other.name == name &&
      other.icon == icon &&
      other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(id, name, icon, isDefault);
}

enum PsitoOpenError {
  /// Nenhum app abre: [PsitoOpenException.detail] é o nome do arquivo.
  noApp,

  /// Sem o shell, ou ele não abriu: [PsitoOpenException.detail] é o porquê.
  failed,
}

class PsitoOpenException implements Exception {
  final PsitoOpenError kind;
  final String detail;

  const PsitoOpenException(this.kind, [this.detail = '']);

  /// A mensagem para quem usa.
  String text(SdkLocalizations l) => switch (kind) {
    PsitoOpenError.noApp => l.openNoApp(detail),
    PsitoOpenError.failed => l.openFailed(detail),
  };

  @override
  String toString() => 'PsitoOpenException(${kind.name}, $detail)';
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
  final List<Color> colors;

  const PsitoWallpaper(this.id, this.colors);

  String name(SdkLocalizations l) => switch (id) {
    'calopsita' => l.wallpaperCalopsita,
    'por-do-sol' => l.wallpaperPorDoSol,
    'floresta' => l.wallpaperFloresta,
    'oceano' => l.wallpaperOceano,
    _ => l.wallpaperNoite,
  };
}

const psitoWallpapers = [
  PsitoWallpaper('noite', [Color(0xFF12181B)]),
  PsitoWallpaper('calopsita', [Color(0xFF12181B), Color(0xFF3A2E12)]),
  PsitoWallpaper('por-do-sol', [Color(0xFF2B1220), Color(0xFF5C2A12)]),
  PsitoWallpaper('floresta', [Color(0xFF0E1F17), Color(0xFF1F3A26)]),
  PsitoWallpaper('oceano', [Color(0xFF0B1A2B), Color(0xFF12405C)]),
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

/// Um caminho com esta marca, nos argumentos ou no `openRequests` do Files,
/// abre no Quick Look em vez de só abrir a pasta (o Espaço na mesa).
const psitoQuickLookPrefix = 'quicklook:';

/// Um argumento com esta marca abre as Configurações naquela seção (o "Mudar
/// o papel de parede" da mesa).
const psitoSettingsSectionPrefix = 'section:';

List<PsitoShortcut> psitoShortcuts(SdkLocalizations l) => [
  PsitoShortcut(l.shortcutLauncher, 'Super', l.shortcutLauncherVm),
  PsitoShortcut(l.shortcutSwitchWindows, 'Alt+Tab', 'Ctrl+Tab'),
  PsitoShortcut(l.shortcutCloseWindow, 'Alt+F4 / Super+Q', 'Ctrl+Alt+W'),
  PsitoShortcut(l.shortcutMaximize, 'Super+↑', 'Alt+Shift+↑'),
  PsitoShortcut(l.shortcutSnap, 'Super+← / →', 'Alt+Shift+← / →'),
  PsitoShortcut(l.shortcutMinimize, 'Super+↓', 'Alt+Shift+↓'),
  PsitoShortcut(
    l.shortcutVolume,
    l.shortcutVolumeKeys,
    'Alt+Shift+PageUp / PageDown',
  ),
  PsitoShortcut(l.shortcutMute, l.shortcutMuteKey, 'Alt+Shift+M'),
  PsitoShortcut(l.shortcutClipboard, 'Super+V', 'Alt+Shift+V'),
  PsitoShortcut(
    l.shortcutClipboardCopy,
    l.shortcutClipboardCopyNative,
    l.shortcutClipboardCopyVm,
  ),
  PsitoShortcut(l.shortcutShowDesktop, 'Super+D', 'Alt+Shift+D'),
  PsitoShortcut(l.shortcutLock, 'Super+L', 'Alt+Shift+L'),
  PsitoShortcut(l.shortcutDismiss, 'Esc', 'Esc'),
];

/// Os idiomas do sistema: o primeiro é o de quem pede um que não existe.
const psitoLocales = SdkLocalizations.supportedLocales;

/// O idioma em uso: [language], ou o do sistema, se vazio ou se não existir.
Locale resolvePsitoLocale(
  String language, [
  List<Locale> supported = psitoLocales,
]) => basicLocaleListResolution([
  if (language.isNotEmpty) Locale(language),
  ...WidgetsBinding.instance.platformDispatcher.locales,
], supported);

/// As traduções do [PsitoSettings.language], para um `MaterialApp`.
List<LocalizationsDelegate<dynamic>> psitoLocalizationsDelegates([
  Iterable<LocalizationsDelegate<dynamic>> extra = const [],
]) => [
  ...extra,
  SdkLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

/// Em que borda da tela a dock fica.
enum PsitoDockPosition {
  bottom,
  left,
  right;

  String label(SdkLocalizations l) => switch (this) {
    bottom => l.dockPositionBottom,
    left => l.dockPositionLeft,
    right => l.dockPositionRight,
  };

  bool get vertical => this != bottom;
}

/// Preferências do sistema. O JSON de [toJson] é o formato do arquivo de
/// configurações e, na fase 4, do protocolo.
@immutable
class PsitoSettings {
  final Color accent;
  final String wallpaperId;
  final bool use24h;
  final bool showSeconds;
  final bool doNotDisturb;

  /// Porcentagem ao lado do ícone de bateria (como no macOS).
  final bool showBatteryPercentage;

  /// O lado dos ícones da dock, em px lógicos ([dockSizes]).
  final double dockIconSize;

  /// O ícone sob o mouse cresce.
  final bool dockMagnification;

  static const dockSizes = (min: 32.0, max: 96.0);

  final PsitoDockPosition dockPosition;

  /// A dock some quando o ponteiro sai dela e volta quando ele encosta na
  /// borda; as janelas ocupam o lugar dela.
  final bool dockAutoHide;

  /// A `~/Área de Trabalho` na mesa.
  final bool desktopShowIcons;

  /// O lado dos ícones da mesa, em px lógicos ([desktopSizes]).
  final double desktopIconSize;

  static const desktopSizes = (min: 32.0, max: 96.0);

  /// O home na mesa.
  final bool desktopShowHome;

  /// A lixeira na mesa.
  final bool desktopShowTrash;

  /// Os discos externos, na mesa.
  final bool desktopShowVolumes;

  /// Os ícones ficam em ordem de nome, sem buracos, e não onde foram postos.
  final bool desktopAutoArrange;

  /// O canto de cima à direita da tela mostra a área de trabalho.
  final bool desktopHotCorner;

  /// O idioma escolhido (`en`, `pt`); vazio segue o do sistema.
  final String language;

  /// Bloqueia depois de tantos minutos sem uso; 0 não bloqueia sozinho.
  final int lockAfterMinutes;

  const PsitoSettings({
    this.accent = const Color(0xFFFFC107),
    this.wallpaperId = 'noite',
    this.use24h = true,
    this.showSeconds = false,
    this.doNotDisturb = false,
    this.showBatteryPercentage = true,
    this.dockIconSize = 52,
    this.dockMagnification = true,
    this.dockPosition = PsitoDockPosition.bottom,
    this.dockAutoHide = false,
    this.desktopShowIcons = true,
    this.desktopIconSize = 48,
    this.desktopShowHome = false,
    this.desktopShowTrash = false,
    this.desktopShowVolumes = true,
    this.desktopAutoArrange = false,
    this.desktopHotCorner = false,
    this.language = '',
    this.lockAfterMinutes = 0,
  });

  static const defaults = PsitoSettings();

  PsitoWallpaper get wallpaper => wallpaperById(wallpaperId);

  PsitoSettings copyWith({
    Color? accent,
    String? wallpaperId,
    bool? use24h,
    bool? showSeconds,
    bool? doNotDisturb,
    bool? showBatteryPercentage,
    double? dockIconSize,
    bool? dockMagnification,
    PsitoDockPosition? dockPosition,
    bool? dockAutoHide,
    bool? desktopShowIcons,
    double? desktopIconSize,
    bool? desktopShowHome,
    bool? desktopShowTrash,
    bool? desktopShowVolumes,
    bool? desktopAutoArrange,
    bool? desktopHotCorner,
    String? language,
    int? lockAfterMinutes,
  }) => PsitoSettings(
    accent: accent ?? this.accent,
    wallpaperId: wallpaperId ?? this.wallpaperId,
    use24h: use24h ?? this.use24h,
    showSeconds: showSeconds ?? this.showSeconds,
    doNotDisturb: doNotDisturb ?? this.doNotDisturb,
    showBatteryPercentage: showBatteryPercentage ?? this.showBatteryPercentage,
    dockIconSize: dockIconSize ?? this.dockIconSize,
    dockMagnification: dockMagnification ?? this.dockMagnification,
    dockPosition: dockPosition ?? this.dockPosition,
    dockAutoHide: dockAutoHide ?? this.dockAutoHide,
    desktopShowIcons: desktopShowIcons ?? this.desktopShowIcons,
    desktopIconSize: desktopIconSize ?? this.desktopIconSize,
    desktopShowHome: desktopShowHome ?? this.desktopShowHome,
    desktopShowTrash: desktopShowTrash ?? this.desktopShowTrash,
    desktopShowVolumes: desktopShowVolumes ?? this.desktopShowVolumes,
    desktopAutoArrange: desktopAutoArrange ?? this.desktopAutoArrange,
    desktopHotCorner: desktopHotCorner ?? this.desktopHotCorner,
    language: language ?? this.language,
    lockAfterMinutes: lockAfterMinutes ?? this.lockAfterMinutes,
  );

  Map<String, Object?> toJson() => {
    'accent': accent.toARGB32(),
    'wallpaper': wallpaperId,
    'use24h': use24h,
    'showSeconds': showSeconds,
    'doNotDisturb': doNotDisturb,
    'showBatteryPercentage': showBatteryPercentage,
    'dockIconSize': dockIconSize,
    'dockMagnification': dockMagnification,
    'dockPosition': dockPosition.name,
    'dockAutoHide': dockAutoHide,
    'desktopShowIcons': desktopShowIcons,
    'desktopIconSize': desktopIconSize,
    'desktopShowHome': desktopShowHome,
    'desktopShowTrash': desktopShowTrash,
    'desktopShowVolumes': desktopShowVolumes,
    'desktopAutoArrange': desktopAutoArrange,
    'desktopHotCorner': desktopHotCorner,
    'language': language,
    'lockAfterMinutes': lockAfterMinutes,
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
      showBatteryPercentage: pick(
        'showBatteryPercentage',
        defaults.showBatteryPercentage,
      ),
      dockIconSize: pick<num>(
        'dockIconSize',
        defaults.dockIconSize,
      ).toDouble().clamp(dockSizes.min, dockSizes.max),
      dockMagnification: pick('dockMagnification', defaults.dockMagnification),
      dockPosition:
          PsitoDockPosition.values.asNameMap()[pick<Object?>(
            'dockPosition',
            null,
          )] ??
          defaults.dockPosition,
      dockAutoHide: pick('dockAutoHide', defaults.dockAutoHide),
      desktopShowIcons: pick('desktopShowIcons', defaults.desktopShowIcons),
      desktopIconSize: pick<num>(
        'desktopIconSize',
        defaults.desktopIconSize,
      ).toDouble().clamp(desktopSizes.min, desktopSizes.max),
      desktopShowHome: pick('desktopShowHome', defaults.desktopShowHome),
      desktopShowTrash: pick('desktopShowTrash', defaults.desktopShowTrash),
      desktopShowVolumes: pick(
        'desktopShowVolumes',
        defaults.desktopShowVolumes,
      ),
      desktopAutoArrange: pick(
        'desktopAutoArrange',
        defaults.desktopAutoArrange,
      ),
      desktopHotCorner: pick('desktopHotCorner', defaults.desktopHotCorner),
      language: pick('language', defaults.language),
      lockAfterMinutes: pick('lockAfterMinutes', defaults.lockAfterMinutes),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PsitoSettings &&
      other.accent == accent &&
      other.wallpaperId == wallpaperId &&
      other.use24h == use24h &&
      other.showSeconds == showSeconds &&
      other.doNotDisturb == doNotDisturb &&
      other.showBatteryPercentage == showBatteryPercentage &&
      other.dockIconSize == dockIconSize &&
      other.dockMagnification == dockMagnification &&
      other.dockPosition == dockPosition &&
      other.dockAutoHide == dockAutoHide &&
      other.desktopShowIcons == desktopShowIcons &&
      other.desktopIconSize == desktopIconSize &&
      other.desktopShowHome == desktopShowHome &&
      other.desktopShowTrash == desktopShowTrash &&
      other.desktopShowVolumes == desktopShowVolumes &&
      other.desktopAutoArrange == desktopAutoArrange &&
      other.desktopHotCorner == desktopHotCorner &&
      other.language == language &&
      other.lockAfterMinutes == lockAfterMinutes;

  @override
  int get hashCode => Object.hash(
    accent,
    wallpaperId,
    use24h,
    showSeconds,
    doNotDisturb,
    showBatteryPercentage,
    dockIconSize,
    dockMagnification,
    dockPosition,
    dockAutoHide,
    desktopShowIcons,
    desktopIconSize,
    desktopShowHome,
    desktopShowTrash,
    desktopShowVolumes,
    desktopAutoArrange,
    desktopHotCorner,
    language,
    lockAfterMinutes,
  );
}

enum PsitoConnectivity { unknown, none, portal, limited, full }

enum PsitoNetworkKind { ethernet, wifi, vpn, other }

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

  final String? ipv6;
  final String? gateway;
  final List<String> dns;
  final String? mac;

  const PsitoNetworkDevice({
    required this.interface,
    required this.kind,
    required this.state,
    this.connection,
    this.ipv4,
    this.wifiStrength,
    this.ipv6,
    this.gateway,
    this.dns = const [],
    this.mac,
  });

  @override
  bool operator ==(Object other) =>
      other is PsitoNetworkDevice &&
      other.interface == interface &&
      other.kind == kind &&
      other.state == state &&
      other.connection == connection &&
      other.ipv4 == ipv4 &&
      other.wifiStrength == wifiStrength &&
      other.ipv6 == ipv6 &&
      other.gateway == gateway &&
      listEquals(other.dns, dns) &&
      other.mac == mac;

  @override
  int get hashCode => Object.hash(
    interface,
    kind,
    state,
    connection,
    ipv4,
    wifiStrength,
    ipv6,
    gateway,
    Object.hashAll(dns),
    mac,
  );
}

/// O que a rede está fazendo (NetworkManager no Linux).
enum PsitoWifiSecurity {
  open,

  /// Com senha: WPA2 ou WPA3.
  personal,

  /// WEP ou corporativa, que o Psito ainda não conecta.
  unsupported,
}

/// Uma rede ao alcance: os pontos de acesso do mesmo nome viram um só, com o
/// sinal do mais forte.
@immutable
class PsitoWifiNetwork {
  final String ssid;

  /// 0–100.
  final int strength;
  final PsitoWifiSecurity security;
  final bool active;

  /// Já tem uma conexão guardada, então não pede a senha.
  final bool saved;

  const PsitoWifiNetwork({
    required this.ssid,
    required this.strength,
    this.security = PsitoWifiSecurity.open,
    this.active = false,
    this.saved = false,
  });

  @override
  bool operator ==(Object other) =>
      other is PsitoWifiNetwork &&
      other.ssid == ssid &&
      other.strength == strength &&
      other.security == security &&
      other.active == active &&
      other.saved == saved;

  @override
  int get hashCode => Object.hash(ssid, strength, security, active, saved);
}

/// Uma VPN guardada.
@immutable
class PsitoVpn {
  final String uuid;
  final String name;
  final bool active;

  /// Ligando ou desligando.
  final bool busy;

  const PsitoVpn({
    required this.uuid,
    required this.name,
    this.active = false,
    this.busy = false,
  });

  @override
  bool operator ==(Object other) =>
      other is PsitoVpn &&
      other.uuid == uuid &&
      other.name == name &&
      other.active == active &&
      other.busy == busy;

  @override
  int get hashCode => Object.hash(uuid, name, active, busy);
}

/// O Wi-Fi servindo de ponto de acesso: a rede que os outros aparelhos veem.
@immutable
class PsitoHotspot {
  final String uuid;
  final String name;

  /// Ainda subindo. Quem entrar agora não consegue.
  final bool busy;

  const PsitoHotspot({
    required this.uuid,
    required this.name,
    this.busy = false,
  });

  @override
  bool operator ==(Object other) =>
      other is PsitoHotspot &&
      other.uuid == uuid &&
      other.name == name &&
      other.busy == busy;

  @override
  int get hashCode => Object.hash(uuid, name, busy);
}

/// O rádio de Wi-Fi, quando há um.
@immutable
class PsitoWifiState {
  final bool enabled;

  /// A ativa primeiro, depois por sinal.
  final List<PsitoWifiNetwork> networks;

  /// O adaptador sabe ser ponto de acesso.
  final bool canShare;

  /// Null quando não está compartilhando. Enquanto compartilha, o rádio não
  /// procura redes, e [networks] fica vazia.
  final PsitoHotspot? hotspot;

  const PsitoWifiState({
    this.enabled = true,
    this.networks = const [],
    this.canShare = false,
    this.hotspot,
  });

  @override
  bool operator ==(Object other) =>
      other is PsitoWifiState &&
      other.enabled == enabled &&
      listEquals(other.networks, networks) &&
      other.canShare == canShare &&
      other.hotspot == hotspot;

  @override
  int get hashCode =>
      Object.hash(enabled, Object.hashAll(networks), canShare, hotspot);
}

enum PsitoWifiResult {
  connected,

  /// A rede pede senha, e não veio nenhuma.
  needsPassword,
  wrongPassword,
  notFound,
  failed,
}

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

  /// Null quando não há adaptador de Wi-Fi.
  final PsitoWifiState? wifi;

  /// O endereço que o sistema usa para ver se há internet. Numa rede com portal,
  /// abrir ele no navegador leva à página de login. Vazio sem essa verificação.
  final String checkUrl;

  /// Por nome.
  final List<PsitoVpn> vpns;

  const PsitoNetworkState({
    required this.available,
    this.enabled = true,
    this.connectivity = PsitoConnectivity.unknown,
    this.connecting = false,
    this.primary,
    this.devices = const [],
    this.wifi,
    this.checkUrl = '',
    this.vpns = const [],
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
      listEquals(other.devices, devices) &&
      other.wifi == wifi &&
      other.checkUrl == checkUrl &&
      listEquals(other.vpns, vpns);

  @override
  int get hashCode => Object.hash(
    available,
    enabled,
    connectivity,
    connecting,
    primary,
    Object.hashAll(devices),
    wifi,
    checkUrl,
    Object.hashAll(vpns),
  );
}

/// Um disco externo, ou uma partição dele.
@immutable
class PsitoVolume {
  /// Não muda enquanto o disco está ligado.
  final String id;

  /// O nome que o disco tem. Pode ser vazio.
  final String label;

  /// Ex.: /dev/sdb1.
  final String device;

  /// Null se não está montado.
  final String? mountPoint;

  /// Em bytes.
  final int size;

  /// Ex.: vfat, ext4. Vazio num trancado.
  final String fileSystem;
  final bool readOnly;

  /// Criptografado e ainda sem a senha.
  final bool locked;

  /// O volume de dentro de um criptografado.
  final bool unlocked;

  /// As partições de um mesmo disco têm o mesmo.
  final String? drive;

  /// Dá para desligar o disco, para tirar com segurança.
  final bool canEject;

  /// O sistema indica montar ao ligar, como num pendrive.
  final bool autoMount;

  const PsitoVolume({
    required this.id,
    required this.label,
    required this.device,
    this.mountPoint,
    this.size = 0,
    this.fileSystem = '',
    this.readOnly = false,
    this.locked = false,
    this.unlocked = false,
    this.drive,
    this.canEject = false,
    this.autoMount = false,
  });

  PsitoVolume copyWith({
    String? label,
    String? fileSystem,
    String? Function()? mountPoint,
    bool? locked,
    bool? unlocked,
  }) => PsitoVolume(
    id: id,
    label: label ?? this.label,
    device: device,
    mountPoint: mountPoint == null ? this.mountPoint : mountPoint(),
    size: size,
    fileSystem: fileSystem ?? this.fileSystem,
    readOnly: readOnly,
    locked: locked ?? this.locked,
    unlocked: unlocked ?? this.unlocked,
    drive: drive,
    canEject: canEject,
    autoMount: autoMount,
  );

  @override
  bool operator ==(Object other) =>
      other is PsitoVolume &&
      other.id == id &&
      other.label == label &&
      other.device == device &&
      other.mountPoint == mountPoint &&
      other.size == size &&
      other.fileSystem == fileSystem &&
      other.readOnly == readOnly &&
      other.locked == locked &&
      other.unlocked == unlocked &&
      other.drive == drive &&
      other.canEject == canEject &&
      other.autoMount == autoMount;

  @override
  int get hashCode => Object.hash(
    id,
    label,
    device,
    mountPoint,
    size,
    fileSystem,
    readOnly,
    locked,
    unlocked,
    drive,
    canEject,
    autoMount,
  );
}

/// Os discos externos: quem liga e tira. Só o shell fala com o sistema.
abstract class PsitoVolumes {
  /// Vazia enquanto carrega, ou sem a permissão.
  ValueListenable<List<PsitoVolume>> get volumes;

  /// Monta e devolve onde. Null se não deu.
  Future<String?> mount(String id);

  Future<PsitoDiskResult> unmount(String id);

  /// Desmonta tudo que está no mesmo disco e desliga. Depois disso pode tirar.
  Future<PsitoDiskResult> eject(String id);

  /// Destranca um volume criptografado e monta o que tem dentro. Quem pede a
  /// senha é o shell, e o app não a vê. Devolve onde montou. Null se a pessoa
  /// desistiu ou se não deu, e aí o shell já avisou.
  Future<String?> unlock(String id);

  /// O nome de quem está segurando o disco: o motivo do [PsitoDiskResult.busy].
  Future<List<String>> usersOf(String id);
}

enum PsitoDiskResult {
  ok,

  /// Tem alguém usando.
  busy,
  wrongPassword,
  failed,
}

/// Relógio do sistema (systemd-timedated no Linux).
@immutable
class PsitoUserAccount {
  final int uid;
  final String login;
  final String name;
  final bool isAdmin;

  /// A conta de quem está na sessão.
  final bool isCurrent;

  const PsitoUserAccount({
    required this.uid,
    required this.login,
    required this.name,
    this.isAdmin = false,
    this.isCurrent = false,
  });

  PsitoUserAccount copyWith({String? name}) => PsitoUserAccount(
    uid: uid,
    login: login,
    name: name ?? this.name,
    isAdmin: isAdmin,
    isCurrent: isCurrent,
  );
}

/// Em potências de 1000, como no Files: "512 B", "1,2 KB", "3,4 GB".
String formatPsitoSize(int bytes, String locale) {
  if (bytes < 1000) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final number = NumberFormat(value < 10 ? '0.0' : '0', locale);
  return '${number.format(value)} ${units[unit]}';
}

/// O uso de um disco.
class PsitoDiskUsage {
  /// O id do volume. Vazio é o disco do sistema, onde está o home.
  final String id;

  /// O rótulo. Vazio é sem nome.
  final String name;

  /// Onde ele está montado (no do sistema, o home). Null é sem montar.
  final String? path;

  final int total;

  /// Null sem montar: só o sistema de arquivos sabe.
  final int? free;

  const PsitoDiskUsage({
    this.id = '',
    this.name = '',
    this.path,
    required this.total,
    this.free,
  });

  bool get isSystem => id.isEmpty;

  /// Dá para avisar com folga, mas um disco grande com 5% livres ainda tem
  /// muito espaço, e um pequeno vive com menos de 2 GB: vale o menor dos dois.
  bool get almostFull {
    final free = this.free;
    if (free == null || total <= 0) return false;
    return free < min(total * 0.05, 2000000000);
  }

  @override
  bool operator ==(Object other) =>
      other is PsitoDiskUsage &&
      other.id == id &&
      other.name == name &&
      other.path == path &&
      other.total == total &&
      other.free == free;

  @override
  int get hashCode => Object.hash(id, name, path, total, free);
}

/// Uma pasta e o quanto ela ocupa.
class PsitoFolderSize {
  final String path;
  final int size;

  const PsitoFolderSize(this.path, this.size);
}

/// O sistema de arquivos de um disco formatado, com o tamanho do rótulo. O nome
/// é o que o UDisks2 entende.
enum PsitoDiskFormat {
  vfat(11),
  exfat(11),
  ext4(16);

  final int maxLabel;

  const PsitoDiskFormat(this.maxLabel);
}

/// O espaço em disco, para as Configurações: o shell mede, porque no sandbox o
/// app não vê os discos nem o home.
abstract class PsitoStorage {
  /// O disco do sistema primeiro, depois os externos.
  ValueListenable<List<PsitoDiskUsage>> get disks;

  /// Mede de novo.
  Future<void> refresh();

  /// As maiores pastas logo abaixo de [path], da maior para a menor. Em disco
  /// grande pode demorar.
  Future<List<PsitoFolderSize>> largestFolders(String path);

  /// Quanto as lixeiras ocupam, a do home e as dos discos.
  Future<int> trashSize();

  /// O shell pergunta antes de esvaziar.
  Future<void> emptyTrash();

  /// Abre a pasta nos Arquivos.
  Future<void> openFolder(String path);

  /// Apaga tudo de um disco externo e formata. Nunca o do sistema.
  Future<PsitoDiskResult> format(String id, PsitoDiskFormat type, String label);
}

/// Sem a permissão: nada a mostrar, e nada acontece.
class PsitoNoStorage implements PsitoStorage {
  static final _empty = ValueNotifier<List<PsitoDiskUsage>>(const []);

  const PsitoNoStorage();

  @override
  ValueListenable<List<PsitoDiskUsage>> get disks => _empty;

  @override
  Future<void> refresh() async {}

  @override
  Future<List<PsitoFolderSize>> largestFolders(String path) async => const [];

  @override
  Future<int> trashSize() async => 0;

  @override
  Future<void> emptyTrash() async {}

  @override
  Future<void> openFolder(String path) async {}

  @override
  Future<PsitoDiskResult> format(
    String id,
    PsitoDiskFormat type,
    String label,
  ) async => PsitoDiskResult.failed;
}

/// As contas de usuário do sistema. Cada ação devolve se deu certo: recusada,
/// ou com o diálogo de senha cancelado, é false.
abstract class PsitoAccounts {
  /// Vazia enquanto carrega, ou sem o serviço.
  ValueListenable<List<PsitoUserAccount>> get users;

  Future<bool> setName(int uid, String name);

  Future<bool> setPassword(int uid, String password);

  Future<bool> create({
    required String login,
    required String name,
    required bool admin,
    required String password,
  });

  /// Apaga a conta e os arquivos dela.
  Future<bool> delete(int uid);
}

/// O [PsitoAppContext.accounts] de quem não pode mexer no sistema.
class PsitoNoAccounts implements PsitoAccounts {
  static final _empty = ValueNotifier<List<PsitoUserAccount>>(const []);

  const PsitoNoAccounts();

  @override
  ValueListenable<List<PsitoUserAccount>> get users => _empty;

  @override
  Future<bool> setName(int uid, String name) async => false;

  @override
  Future<bool> setPassword(int uid, String password) async => false;

  @override
  Future<bool> create({
    required String login,
    required String name,
    required bool admin,
    required String password,
  }) async => false;

  @override
  Future<bool> delete(int uid) async => false;
}

/// De onde vem o IPv4 de uma conexão guardada.
enum PsitoIpMethod {
  auto,
  manual,

  /// Outro modo (ex.: compartilhar a conexão), que as Configurações não mudam.
  other,
}

/// Se a rede cobra por dados. Em [auto], o sistema decide.
enum PsitoMetered { auto, yes, no }

/// Uma conexão guardada, com o que dá para mudar nela.
@immutable
class PsitoSavedConnection {
  final String uuid;
  final String name;
  final PsitoNetworkKind kind;

  /// Entra sozinha quando a rede aparece.
  final bool autoconnect;

  /// Entre duas redes ao alcance, a de número maior.
  final int priority;
  final PsitoMetered metered;
  final PsitoIpMethod ipv4Method;

  /// Só em [PsitoIpMethod.manual]. Ex.: 192.168.0.10/24.
  final String address;
  final String gateway;

  /// Vazia, usa o DNS que a rede oferece.
  final List<String> dns;

  const PsitoSavedConnection({
    required this.uuid,
    required this.name,
    required this.kind,
    this.autoconnect = true,
    this.priority = 0,
    this.metered = PsitoMetered.auto,
    this.ipv4Method = PsitoIpMethod.auto,
    this.address = '',
    this.gateway = '',
    this.dns = const [],
  });

  PsitoSavedConnection copyWith({
    bool? autoconnect,
    int? priority,
    PsitoMetered? metered,
    PsitoIpMethod? ipv4Method,
    String? address,
    String? gateway,
    List<String>? dns,
  }) => PsitoSavedConnection(
    uuid: uuid,
    name: name,
    kind: kind,
    autoconnect: autoconnect ?? this.autoconnect,
    priority: priority ?? this.priority,
    metered: metered ?? this.metered,
    ipv4Method: ipv4Method ?? this.ipv4Method,
    address: address ?? this.address,
    gateway: gateway ?? this.gateway,
    dns: dns ?? this.dns,
  );

  @override
  bool operator ==(Object other) =>
      other is PsitoSavedConnection &&
      other.uuid == uuid &&
      other.name == name &&
      other.kind == kind &&
      other.autoconnect == autoconnect &&
      other.priority == priority &&
      other.metered == metered &&
      other.ipv4Method == ipv4Method &&
      other.address == address &&
      other.gateway == gateway &&
      listEquals(other.dns, dns);

  @override
  int get hashCode => Object.hash(
    uuid,
    name,
    kind,
    autoconnect,
    priority,
    metered,
    ipv4Method,
    address,
    gateway,
    Object.hashAll(dns),
  );
}

/// As conexões guardadas. Cada ação devolve se deu certo: recusada, ou com o
/// diálogo de senha cancelado, é false. As da conta não pedem senha, e as do
/// sistema (o cabo) pedem a de administrador a quem não está no grupo `sudo` ou
/// `netdev`, que o Debian libera.
abstract class PsitoNetworkConnections {
  /// Vazia enquanto carrega, ou sem o serviço.
  ValueListenable<List<PsitoSavedConnection>> get connections;

  /// Grava, e vale na hora se a conexão estiver ativa.
  Future<bool> update(PsitoSavedConnection connection);

  /// Apaga a conexão, com a senha dela.
  Future<bool> forget(String uuid);

  /// Guarda a VPN de um arquivo do WireGuard (`.conf`) ou do OpenVPN (`.ovpn`),
  /// sem ligar, e devolve se deu certo.
  Future<bool> importVpn(String path);

  /// O nome e a senha da última vez que compartilhou, ou null se nunca.
  Future<PsitoHotspotConfig?> hotspotConfig();

  /// Grava e liga o ponto de acesso, e espera ele subir. O Wi-Fi sai da rede em
  /// que está.
  Future<bool> startHotspot(PsitoHotspotConfig config);

  Future<bool> stopHotspot();
}

/// O nome e a senha do ponto de acesso (WPA2).
@immutable
class PsitoHotspotConfig {
  final String name;
  final String password;

  const PsitoHotspotConfig({required this.name, required this.password});

  /// O nome tem de 1 a 32 bytes, como todo SSID.
  static bool validName(String name) {
    final bytes = utf8.encode(name).length;
    return bytes >= 1 && bytes <= 32;
  }

  /// O WPA2 aceita de 8 a 63 caracteres ASCII.
  static bool validPassword(String password) =>
      RegExp(r'^[\x20-\x7e]{8,63}$').hasMatch(password);

  @override
  bool operator ==(Object other) =>
      other is PsitoHotspotConfig &&
      other.name == name &&
      other.password == password;

  @override
  int get hashCode => Object.hash(name, password);
}

/// O [PsitoAppContext.networkConnections] de quem não pode mexer no sistema.
class PsitoNoNetworkConnections implements PsitoNetworkConnections {
  static final _empty = ValueNotifier<List<PsitoSavedConnection>>(const []);

  const PsitoNoNetworkConnections();

  @override
  ValueListenable<List<PsitoSavedConnection>> get connections => _empty;

  @override
  Future<bool> update(PsitoSavedConnection connection) async => false;

  @override
  Future<bool> forget(String uuid) async => false;

  @override
  Future<PsitoHotspotConfig?> hotspotConfig() async => null;

  @override
  Future<bool> startHotspot(PsitoHotspotConfig config) async => false;

  @override
  Future<bool> stopHotspot() async => false;

  @override
  Future<bool> importVpn(String path) async => false;
}

class PsitoTimeState {
  /// False enquanto carrega ou se o serviço não existe.
  final bool available;

  /// Nome IANA, ex.: America/Fortaleza.
  final String timezone;

  /// Ajuste automático pela rede ligado.
  final bool ntp;
  final bool ntpSynchronized;

  /// O sistema tem um serviço de NTP para ligar.
  final bool canNtp;

  const PsitoTimeState({
    required this.available,
    this.timezone = '',
    this.ntp = false,
    this.ntpSynchronized = false,
    this.canNtp = false,
  });

  static const unavailable = PsitoTimeState(available: false);

  @override
  bool operator ==(Object other) =>
      other is PsitoTimeState &&
      other.available == available &&
      other.timezone == timezone &&
      other.ntp == ntp &&
      other.ntpSynchronized == ntpSynchronized &&
      other.canNtp == canNtp;

  @override
  int get hashCode =>
      Object.hash(available, timezone, ntp, ntpSynchronized, canNtp);
}

/// As cores do sistema, pelo que cada uma faz. A interface pega daqui
/// (`context.palette`), e o tema claro será só outra paleta.
@immutable
class PsitoPalette extends ThemeExtension<PsitoPalette> {
  final Color background;
  final Color panel;
  final Color panelAlt;
  final Color panelRaised;

  /// O painel translúcido das camadas sobre a tela (o OSD, o seletor).
  final Color panelGlass;
  final Color control;
  final Color controlStrong;
  final Color text;
  final Color textBody;
  final Color textSecondary;
  final Color textTertiary;
  final Color textQuiet;
  final Color textDisabled;
  final Color line;
  final Color lineSoft;
  final Color hover;

  /// O texto sobre a cor de destaque.
  final Color onAccent;
  final Color shadow;
  final Color shadowSoft;
  final Color scrim;
  final Color highlight;
  final Color cheek;
  final Color neutral;
  final Color success;
  final Color warning;
  final Color danger;

  const PsitoPalette({
    required this.background,
    required this.panel,
    required this.panelAlt,
    required this.panelRaised,
    required this.panelGlass,
    required this.control,
    required this.controlStrong,
    required this.text,
    required this.textBody,
    required this.textSecondary,
    required this.textTertiary,
    required this.textQuiet,
    required this.textDisabled,
    required this.line,
    required this.lineSoft,
    required this.hover,
    required this.onAccent,
    required this.shadow,
    required this.shadowSoft,
    required this.scrim,
    required this.highlight,
    required this.cheek,
    required this.neutral,
    required this.success,
    required this.warning,
    required this.danger,
  });

  static const dark = PsitoPalette(
    background: Color(0xFF12181B),
    panel: Color(0xFF1E252B),
    panelAlt: Color(0xFF1C2327),
    panelRaised: Color(0xFF1E262A),
    panelGlass: Color(0xEE1E262A),
    control: Color(0xFF263238),
    controlStrong: Color(0xFF37474F),
    text: Color(0xFFFFFFFF),
    textBody: Color(0xFFE0E0E0),
    textSecondary: Color(0xB3FFFFFF),
    textTertiary: Color(0x99FFFFFF),
    textQuiet: Color(0x8AFFFFFF),
    textDisabled: Color(0x62FFFFFF),
    line: Color(0x3DFFFFFF),
    lineSoft: Color(0x1FFFFFFF),
    hover: Color(0x1AFFFFFF),
    onAccent: Color(0xDD000000),
    shadow: Color(0xFF000000),
    shadowSoft: Color(0x42000000),
    scrim: Color(0x8A000000),
    highlight: Color(0xFFFFC107),
    cheek: Color(0xFFFF5722),
    neutral: Color(0xFF90A4AE),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFF9800),
    danger: Color(0xFFF44336),
  );

  @override
  PsitoPalette copyWith() => this;

  @override
  PsitoPalette lerp(PsitoPalette? other, double t) =>
      t < 0.5 ? this : other ?? this;
}

extension PsitoPaletteContext on BuildContext {
  PsitoPalette get palette =>
      Theme.of(this).extension<PsitoPalette>() ?? PsitoPalette.dark;
}

/// Tema escuro do Psito com a cor de destaque das Configurações.
ThemeData psitoTheme(Color accent) => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: PsitoPalette.dark.background,
  extensions: const [PsitoPalette.dark],
  colorScheme: ColorScheme.dark(
    primary: accent, // Amarelo calopsita 🦜 por padrão
    secondary: PsitoPalette.dark.cheek, // Bochecha alaranjada
  ),
);

/// Os ícones do tema do sistema (o canal `psito/icons` do runtime, sobre o
/// GtkIconTheme, que também lê SVG), carregados uma vez por nome e tamanho.
const _iconsChannel = MethodChannel('psito/icons');
final _iconCache = <String, Future<Uint8List?>>{};

/// O PNG do primeiro dos [names] que o tema tiver (ou de um caminho
/// absoluto), no tamanho em pixels. Null se nenhum existir ou sem o runtime
/// (nos testes).
Future<Uint8List?> loadThemeIcon(List<String> names, int size) =>
    _iconCache.putIfAbsent('${names.join('|')}@$size', () async {
      try {
        return await _iconsChannel.invokeMethod<Uint8List>('iconPng', {
          'names': names,
          'size': size,
        });
      } on MissingPluginException {
        return null;
      } on PlatformException {
        return null;
      }
    });

/// Um ícone do tema: [names] do mais exato para o mais genérico
/// (`text-x-python`, `text-x-script`, `text-x-generic`), ou um caminho.
/// Enquanto carrega, um espaço do tamanho; sem nenhum, [fallback].
class PsitoIcon extends StatelessWidget {
  final List<String> names;
  final double size;
  final Widget? fallback;

  const PsitoIcon(this.names, {super.key, required this.size, this.fallback});

  /// Os tamanhos em que o tema costuma ter os ícones: o pedido sobe para o
  /// próximo, para o cache servir a mais de um tamanho.
  static const _buckets = [16, 24, 32, 48, 64, 96, 128, 256];

  @override
  Widget build(BuildContext context) {
    final pixels =
        size * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1).clamp(1, 4);
    final load = _buckets.firstWhere((b) => b >= pixels, orElse: () => 256);
    return FutureBuilder(
      future: names.isEmpty ? Future.value(null) : loadThemeIcon(names, load),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return snapshot.connectionState == ConnectionState.done
              ? SizedBox.square(dimension: size, child: fallback)
              : SizedBox.square(dimension: size);
        }
        return Image.memory(
          bytes,
          width: size,
          height: size,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        );
      },
    );
  }
}
