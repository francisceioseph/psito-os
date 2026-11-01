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

  @override
  String get sectionPrivacy => 'Privacidade';

  @override
  String get lockAfter => 'Bloquear a tela depois de';

  @override
  String get lockNever => 'Nunca';

  @override
  String lockMinutes(Object minutes) {
    return '$minutes min';
  }

  @override
  String get lockNote =>
      'A tela também bloqueia com Super+L e antes de suspender.';

  @override
  String get sectionUsers => 'Usuários';

  @override
  String get usersUnavailable => 'A lista de usuários não está disponível.';

  @override
  String get userAdmin => 'Administrador';

  @override
  String get userStandard => 'Padrão';

  @override
  String userYou(Object login, Object role) {
    return '$login · $role · você';
  }

  @override
  String get userName => 'Nome completo';

  @override
  String get userLogin => 'Nome de login';

  @override
  String get userNewPassword => 'Nova senha';

  @override
  String get userConfirmPassword => 'Confirme a senha';

  @override
  String get userSaveName => 'Salvar o nome';

  @override
  String get userChangePassword => 'Mudar a senha';

  @override
  String get userDelete => 'Apagar a conta';

  @override
  String userDeleteConfirm(Object login) {
    return 'Apagar $login e todos os arquivos da conta?';
  }

  @override
  String get userAdd => 'Adicionar usuário';

  @override
  String get userCreate => 'Criar a conta';

  @override
  String get userAdminChoice => 'Administrador';

  @override
  String get userSaved => 'Salvo.';

  @override
  String get userFailed => 'Não deu certo, ou foi cancelado.';

  @override
  String get userPasswordEmpty => 'Digite uma senha.';

  @override
  String get userPasswordMismatch => 'As senhas não são iguais.';

  @override
  String get userLoginInvalid =>
      'Use letras minúsculas, números, - e _, começando com uma letra.';

  @override
  String get savedNetworks => 'Redes salvas';

  @override
  String get connectionAuto => 'Conecta sozinha';

  @override
  String get connectionManual => 'Só quando você pedir';

  @override
  String get connectionAutoconnect => 'Conectar sozinha';

  @override
  String get connectionPriority => 'Prioridade';

  @override
  String get connectionPriorityHint =>
      'Com duas redes ao alcance, entra na de número maior.';

  @override
  String get connectionMetered => 'Rede limitada';

  @override
  String get connectionMeteredAuto => 'Automático';

  @override
  String get connectionMeteredYes => 'Sim, cobra por dados';

  @override
  String get connectionMeteredNo => 'Não';

  @override
  String get connectionIpv4 => 'IPv4';

  @override
  String get connectionIpv4Auto => 'Automático (DHCP)';

  @override
  String get connectionIpv4Manual => 'Manual';

  @override
  String get connectionAddress => 'Endereço e rede';

  @override
  String get connectionDnsHint =>
      'Separados por vírgula. Vazio usa o DNS da rede.';

  @override
  String get connectionSave => 'Salvar';

  @override
  String get connectionForget => 'Esquecer';

  @override
  String get connectionBadPriority => 'A prioridade é um número inteiro.';

  @override
  String get connectionBadAddress => 'Use um endereço como 192.168.0.10/24.';

  @override
  String get connectionBadGateway =>
      'O gateway é um endereço como 192.168.0.1.';

  @override
  String get connectionBadDns => 'O DNS é uma lista de endereços como 1.1.1.1.';

  @override
  String get detailIpv4 => 'IPv4';

  @override
  String get detailIpv6 => 'IPv6';

  @override
  String get detailGateway => 'Gateway';

  @override
  String get detailDns => 'DNS';

  @override
  String get detailMac => 'Endereço MAC';

  @override
  String connectionForgetConfirm(String name) {
    return 'Esquecer $name?';
  }

  @override
  String get vpnImport => 'Importar VPN…';

  @override
  String get vpnImportTitle => 'Importar VPN (WireGuard ou OpenVPN)';

  @override
  String get vpnImported =>
      'VPN guardada. Ela liga pelo ícone de rede na barra superior.';

  @override
  String get vpnImportFailed => 'Não foi possível importar este arquivo.';

  @override
  String get hotspotTitle => 'Compartilhar a conexão';

  @override
  String get hotspotHint =>
      'Outros aparelhos entram nesta rede e usam a internet deste computador. Enquanto isso, o Wi-Fi sai da rede em que está.';

  @override
  String get hotspotName => 'Nome da rede';

  @override
  String get hotspotPassword => 'Senha';

  @override
  String get hotspotNewPassword => 'Gerar outra senha';

  @override
  String get hotspotBadName => 'O nome precisa ter de 1 a 32 bytes.';

  @override
  String get hotspotBadPassword =>
      'A senha precisa ter de 8 a 63 caracteres, sem acentos.';

  @override
  String get hotspotStart => 'Começar a compartilhar';

  @override
  String get hotspotStop => 'Parar de compartilhar';

  @override
  String get hotspotStarting => 'Começando…';

  @override
  String get hotspotActive =>
      'Compartilhando. Outros aparelhos já podem entrar.';

  @override
  String get hotspotNoUplink =>
      'Não há outra conexão: quem entrar ficará sem internet.';

  @override
  String get hotspotWifiOff => 'Ligue o Wi-Fi para compartilhar.';

  @override
  String get hotspotFailed => 'Não foi possível compartilhar.';

  @override
  String get accentYellow => 'Amarelo';

  @override
  String get accentOrange => 'Laranja';

  @override
  String get accentGreen => 'Verde';

  @override
  String get accentBlue => 'Azul';

  @override
  String get accentPurple => 'Roxo';

  @override
  String get accentPink => 'Rosa';

  @override
  String get desktopVolumes => 'Discos externos';

  @override
  String get sectionStorage => 'Armazenamento';

  @override
  String get storageUnavailable => 'Não deu para medir os discos.';

  @override
  String get storageThisComputer => 'Este computador';

  @override
  String get storageUnnamed => 'Disco sem nome';

  @override
  String storageFree(String free, String total) {
    return '$free livres de $total';
  }

  @override
  String storageNotMounted(String total) {
    return '$total, sem montar';
  }

  @override
  String get storageAlmostFull => 'Este disco está quase cheio.';

  @override
  String get storageLargest => 'Maiores pastas';

  @override
  String get storageHideLargest => 'Esconder as pastas';

  @override
  String get storageNoFolders => 'Nenhuma pasta aqui.';

  @override
  String storageOpenFolder(String name) {
    return 'Abrir $name nos Arquivos';
  }

  @override
  String get storageTrash => 'Lixeira';

  @override
  String storageTrashSize(String size) {
    return '$size na lixeira, somando todos os discos';
  }

  @override
  String get storageEmptyTrash => 'Esvaziar';

  @override
  String get storageFormat => 'Formatar…';

  @override
  String storageFormatWarning(String name) {
    return 'Isto apaga tudo que há em $name, sem volta.';
  }

  @override
  String get storageFormatType => 'Formato';

  @override
  String get storageFormatFat =>
      'FAT: serve em qualquer aparelho, arquivos de até 4 GB';

  @override
  String get storageFormatExfat =>
      'exFAT: serve na maioria dos aparelhos, arquivos grandes';

  @override
  String get storageFormatExt4 => 'ext4: só no Linux';

  @override
  String get storageFormatLabel => 'Nome novo';

  @override
  String storageFormatConfirm(String name) {
    return 'Digite $name para confirmar';
  }

  @override
  String get storageFormatAction => 'Apagar e formatar';

  @override
  String get storageFormatCancel => 'Cancelar';

  @override
  String get storageFormatBusy =>
      'O disco está em uso. Feche o que o usa e tente de novo.';

  @override
  String get storageFormatFailed => 'Não deu para formatar o disco.';

  @override
  String get storageFormatDone => 'Disco formatado.';
}
