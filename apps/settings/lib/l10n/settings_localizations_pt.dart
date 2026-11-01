// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'settings_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class SettingsLocalizationsPt extends SettingsLocalizations {
  SettingsLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Configurações';

  @override
  String get sectionAppearance => 'Aparência';

  @override
  String get sectionLanguage => 'Idioma';

  @override
  String get sectionDock => 'Dock';

  @override
  String get sectionDesktop => 'Área de trabalho';

  @override
  String get sectionDateTime => 'Data e hora';

  @override
  String get sectionNetwork => 'Rede';

  @override
  String get sectionNotifications => 'Notificações';

  @override
  String get sectionPower => 'Energia';

  @override
  String get sectionShortcuts => 'Atalhos';

  @override
  String get sectionAbout => 'Sobre';

  @override
  String get shortcutsNote =>
      'Super e Alt+Tab ficam com o sistema do computador e não chegam à VM; por isso cada ação tem uma combinação alternativa. As duas valem ao mesmo tempo. Em Alternar janelas, segure o modificador e aperte Tab para escolher; Shift volta.';

  @override
  String get aboutDescription =>
      'Shell em Flutter como cliente Wayland do labwc, com cada app no seu processo.';

  @override
  String get desktopAutoArrangeHint =>
      'Os ícones ficam em ordem de nome, sem buracos. Mover um ícone desliga, para ele ficar onde foi solto.';

  @override
  String get desktopHotCornerHint =>
      'Levar o ponteiro ao canto de cima à direita da tela minimiza as janelas, e de novo traz elas de volta.';

  @override
  String get deviceConnected => 'Conectado';

  @override
  String get deviceConnecting => 'Conectando…';

  @override
  String get deviceDisconnected => 'Desconectado';

  @override
  String get deviceUnavailable => 'Sem cabo ou sinal';

  @override
  String get deviceUnmanaged => 'Não gerenciado';

  @override
  String get languageSystem => 'Igual ao do sistema';

  @override
  String get languageNote =>
      'Os apps do Psito mudam na hora. Os outros programas mudam ao abrir de novo.';

  @override
  String get accentColor => 'Cor de destaque';

  @override
  String get wallpaper => 'Papel de parede';

  @override
  String get iconSize => 'Tamanho dos ícones';

  @override
  String get magnification => 'Ampliação';

  @override
  String get magnificationHint => 'O ícone sob o mouse cresce.';

  @override
  String get screenPosition => 'Posição na tela';

  @override
  String get autoHide => 'Ocultar automaticamente';

  @override
  String get autoHideHint =>
      'A dock some e volta quando o ponteiro encosta na borda.';

  @override
  String get desktopShowIcons => 'Mostrar os ícones';

  @override
  String get desktopShowIconsHint =>
      'Os arquivos da pasta Área de Trabalho, na mesa.';

  @override
  String get desktopHome => 'Pasta pessoal';

  @override
  String get desktopTrash => 'Lixeira';

  @override
  String get desktopAutoArrange => 'Organizar automaticamente';

  @override
  String get desktopHotCorner => 'Canto para mostrar a área de trabalho';

  @override
  String get use24h => 'Formato 24 horas';

  @override
  String get showSeconds => 'Mostrar segundos';

  @override
  String get timeUnavailable =>
      'Data e hora do sistema indisponíveis (timedated)';

  @override
  String get ntp => 'Ajustar automaticamente';

  @override
  String get ntpOff => 'Desligado';

  @override
  String get ntpSynced => 'Sincronizado com a internet';

  @override
  String get ntpWaiting => 'Aguardando sincronização';

  @override
  String get timezone => 'Fuso horário';

  @override
  String get change => 'Alterar';

  @override
  String get ntpHint => 'Com o ajuste automático ligado, a hora vem da rede.';

  @override
  String get timezoneSearch => 'Buscar fuso (ex.: sao paulo)';

  @override
  String get cancel => 'Cancelar';

  @override
  String get networkManagerUnavailable => 'NetworkManager indisponível';

  @override
  String get noNetworkDevice => 'Nenhum dispositivo de rede';

  @override
  String get networkHint =>
      'Para ligar ou desligar a rede, use o ícone de rede na barra superior.';

  @override
  String get doNotDisturb => 'Não perturbe';

  @override
  String get doNotDisturbHint =>
      'As notificações vão para o painel, sem aparecer na tela.';

  @override
  String get showBatteryPercentage => 'Mostrar porcentagem da bateria';

  @override
  String get batteryHint =>
      'O ícone de bateria só aparece em computadores com bateria.';

  @override
  String get shortcutAction => 'Ação';

  @override
  String get shortcutNative => 'Nativo';

  @override
  String get systemInfoUnavailable =>
      'Informações do sistema indisponíveis (hostnamed)';

  @override
  String get computerName => 'Nome do computador';

  @override
  String get system => 'Sistema';

  @override
  String get hardware => 'Hardware';

  @override
  String get settingsPath =>
      'Configurações salvas em ~/.config/psito/settings.json';
}
