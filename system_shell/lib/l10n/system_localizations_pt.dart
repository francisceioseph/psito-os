// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'system_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class SystemLocalizationsPt extends SystemLocalizations {
  SystemLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get durationUnderMinute => 'menos de 1 min';

  @override
  String durationMinutes(Object minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(Object hours) {
    return '$hours h';
  }

  @override
  String durationHoursMinutes(Object hours, Object minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get batteryFull => 'Carregada';

  @override
  String get batteryCharging => 'Carregando';

  @override
  String get batteryDischarging => 'Na bateria';

  @override
  String batteryUntilFull(Object time) {
    return '$time até completar';
  }

  @override
  String batteryRemaining(Object time) {
    return '$time restantes';
  }

  @override
  String batteryTooltip(Object percent) {
    return 'Bateria: $percent';
  }

  @override
  String powerSource(Object source) {
    return 'Fonte de energia: $source';
  }

  @override
  String get powerSourceAdapter => 'Adaptador';

  @override
  String get powerSourceBattery => 'Bateria';

  @override
  String clipboardTooltip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Área de transferência: $count itens',
      one: 'Área de transferência: 1 item',
    );
    return '$_temp0';
  }

  @override
  String get timeNow => 'agora';

  @override
  String timeMinutesAgo(Object minutes) {
    return 'há $minutes min';
  }

  @override
  String timeHoursAgo(Object hours) {
    return 'há $hours h';
  }

  @override
  String timeDaysAgo(Object days) {
    return 'há $days d';
  }

  @override
  String orShortcut(Object keys) {
    return 'ou $keys';
  }

  @override
  String copied(Object what) {
    return 'Copiado: $what';
  }

  @override
  String get clipImage => 'Imagem';

  @override
  String clipFiles(Object count, Object names) {
    return '$count arquivos: $names';
  }

  @override
  String get networkOff => 'Rede desativada';

  @override
  String get networkConnecting => 'Conectando…';

  @override
  String get networkDisconnected => 'Desconectado';

  @override
  String get networkNoInternet => 'Conectado, sem internet';

  @override
  String get connectivityFull => 'Internet';

  @override
  String get connectivityNone => 'Sem internet';

  @override
  String get connectivityPortal => 'Portal de acesso';

  @override
  String get connectivityUnknown => 'Verificando…';

  @override
  String get kindEthernet => 'Cabo';

  @override
  String get kindWifi => 'Wi-Fi';

  @override
  String get network => 'Rede';

  @override
  String get powerOffQuestion => 'Desligar o Psito OS?';

  @override
  String get rebootQuestion => 'Reiniciar o Psito OS?';

  @override
  String powerOffCountdown(Object seconds) {
    return 'Desligando em $seconds s…';
  }

  @override
  String rebootCountdown(Object seconds) {
    return 'Reiniciando em $seconds s…';
  }

  @override
  String get suspend => 'Suspender';

  @override
  String get reboot => 'Reiniciar';

  @override
  String get powerOff => 'Desligar';

  @override
  String get volumeMutedTooltip => 'Sem som';

  @override
  String volumeTooltip(Object percent) {
    return 'Volume: $percent';
  }

  @override
  String get clipboardTitle => 'Área de transferência';

  @override
  String get clear => 'Limpar';

  @override
  String get clipboardEmpty => 'Nada copiado nos últimos 15 minutos.';

  @override
  String get tagline => 'O Sistema Operacional Penoso';

  @override
  String get cancel => 'Cancelar';

  @override
  String get openInFiles => 'Abrir no Files';

  @override
  String get folderEmpty => 'A pasta está vazia.';

  @override
  String get searchApps => 'Buscar apps';

  @override
  String get noAppsFound => 'Nenhum app encontrado';

  @override
  String get notifications => 'Notificações';

  @override
  String get clearAll => 'Limpar tudo';

  @override
  String get noNotifications => 'Nenhuma notificação';

  @override
  String get dismiss => 'Dispensar';

  @override
  String get minimize => 'Minimizar';

  @override
  String get restore => 'Restaurar';

  @override
  String get maximize => 'Maximizar';

  @override
  String get close => 'Fechar';

  @override
  String get menu => 'Menu';

  @override
  String get power => 'Energia';

  @override
  String get battery => 'Bateria';

  @override
  String get muted => 'Mudo';

  @override
  String get unmute => 'Ativar som';

  @override
  String get mute => 'Silenciar';

  @override
  String get powerOffNow => 'Desligar agora';

  @override
  String get rebootNow => 'Reiniciar agora';

  @override
  String get lock => 'Bloquear';

  @override
  String get logout => 'Sair';
}
