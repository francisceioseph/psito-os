// Contrato entre o shell e os apps do Psito OS.
//
// Os apps só conhecem o que está aqui: nada de screens/, widgets/ ou shell/.
// Na fase 4 este contrato vira o protocolo entre processos, então tudo que um
// app pede ao shell precisa passar pelo PsitoAppContext.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Brightness, ColorScheme, ThemeData;
import 'package:flutter/services.dart';
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

class PsitoOpenException implements Exception {
  final String message;

  const PsitoOpenException(this.message);

  @override
  String toString() => message;
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

/// Um caminho com esta marca, nos argumentos ou no `openRequests` do Files,
/// abre no Quick Look em vez de só abrir a pasta (o Espaço na mesa).
const psitoQuickLookPrefix = 'quicklook:';

/// Um argumento com esta marca abre as Configurações naquela seção (o "Mudar
/// o papel de parede" da mesa).
const psitoSettingsSectionPrefix = 'section:';

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
  PsitoShortcut('Abrir a área de transferência', 'Super+V', 'Alt+Shift+V'),
  PsitoShortcut(
    'Copiar de novo o item 1 a 5 da área de transferência',
    'Super+1 a 5',
    'Alt+Shift+1 a 5',
  ),
  PsitoShortcut('Mostrar a área de trabalho', 'Super+D', 'Alt+Shift+D'),
  PsitoShortcut('Fechar launcher, painel ou seletor', 'Esc', 'Esc'),
];

/// Em que borda da tela a dock fica.
enum PsitoDockPosition {
  bottom('Embaixo'),
  left('À esquerda'),
  right('À direita');

  final String label;
  const PsitoDockPosition(this.label);

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

  /// Os ícones ficam em ordem de nome, sem buracos, e não onde foram postos.
  final bool desktopAutoArrange;

  /// O canto de cima à direita da tela mostra a área de trabalho.
  final bool desktopHotCorner;

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
    this.desktopAutoArrange = false,
    this.desktopHotCorner = false,
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
    bool? desktopAutoArrange,
    bool? desktopHotCorner,
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
    desktopAutoArrange: desktopAutoArrange ?? this.desktopAutoArrange,
    desktopHotCorner: desktopHotCorner ?? this.desktopHotCorner,
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
    'desktopAutoArrange': desktopAutoArrange,
    'desktopHotCorner': desktopHotCorner,
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
      desktopAutoArrange: pick(
        'desktopAutoArrange',
        defaults.desktopAutoArrange,
      ),
      desktopHotCorner: pick('desktopHotCorner', defaults.desktopHotCorner),
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
      other.desktopAutoArrange == desktopAutoArrange &&
      other.desktopHotCorner == desktopHotCorner;

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
    desktopAutoArrange,
    desktopHotCorner,
  );
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

/// Relógio do sistema (systemd-timedated no Linux).
@immutable
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

/// Tema escuro do Psito com a cor de destaque das Configurações.
ThemeData psitoTheme(Color accent) => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF12181B),
  colorScheme: ColorScheme.dark(
    primary: accent, // Amarelo calopsita 🦜 por padrão
    secondary: const Color(0xFFFF5722), // Bochecha alaranjada
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
