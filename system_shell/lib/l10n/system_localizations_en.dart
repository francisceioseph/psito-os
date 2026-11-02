// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'system_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SystemLocalizationsEn extends SystemLocalizations {
  SystemLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get durationUnderMinute => 'less than 1 min';

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
  String get batteryFull => 'Charged';

  @override
  String get batteryCharging => 'Charging';

  @override
  String get batteryDischarging => 'On battery';

  @override
  String batteryUntilFull(Object time) {
    return '$time until full';
  }

  @override
  String batteryRemaining(Object time) {
    return '$time left';
  }

  @override
  String batteryTooltip(Object percent) {
    return 'Battery: $percent';
  }

  @override
  String powerSource(Object source) {
    return 'Power source: $source';
  }

  @override
  String get powerSourceAdapter => 'Adapter';

  @override
  String get powerSourceBattery => 'Battery';

  @override
  String clipboardTooltip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Clipboard: $count items',
      one: 'Clipboard: 1 item',
    );
    return '$_temp0';
  }

  @override
  String get timeNow => 'now';

  @override
  String timeMinutesAgo(Object minutes) {
    return '$minutes min ago';
  }

  @override
  String timeHoursAgo(Object hours) {
    return '$hours h ago';
  }

  @override
  String timeDaysAgo(Object days) {
    return '$days d ago';
  }

  @override
  String orShortcut(Object keys) {
    return 'or $keys';
  }

  @override
  String copied(Object what) {
    return 'Copied: $what';
  }

  @override
  String get clipImage => 'Image';

  @override
  String clipFiles(Object count, Object names) {
    return '$count files: $names';
  }

  @override
  String get wifi => 'Wi-Fi';

  @override
  String get wifiSearching => 'Searching for networks…';

  @override
  String get wifiNoNetworks => 'No networks found';

  @override
  String get wifiOtherNetwork => 'Other network…';

  @override
  String get wifiNetworkName => 'Network name';

  @override
  String get wifiPassword => 'Password';

  @override
  String get wifiShowPassword => 'Show password';

  @override
  String get wifiHidePassword => 'Hide password';

  @override
  String get wifiConnect => 'Connect';

  @override
  String get wifiCancel => 'Cancel';

  @override
  String get wifiDisconnect => 'Disconnect';

  @override
  String get wifiWrongPassword => 'Wrong password';

  @override
  String get wifiNotFound => 'Network not found';

  @override
  String get wifiFailed => 'Could not connect';

  @override
  String get wifiUnsupported => 'This kind of network is not supported yet';

  @override
  String get networkSettings => 'Network settings';

  @override
  String get networkOff => 'Network off';

  @override
  String get networkConnecting => 'Connecting…';

  @override
  String get networkDisconnected => 'Disconnected';

  @override
  String get networkNoInternet => 'Connected, no internet';

  @override
  String get connectivityFull => 'Internet';

  @override
  String get connectivityNone => 'No internet';

  @override
  String get connectivityPortal => 'Sign-in portal';

  @override
  String get connectivityUnknown => 'Checking…';

  @override
  String get kindEthernet => 'Cable';

  @override
  String get kindWifi => 'Wi-Fi';

  @override
  String get network => 'Network';

  @override
  String get powerOffQuestion => 'Shut down Psito OS?';

  @override
  String get rebootQuestion => 'Restart Psito OS?';

  @override
  String powerOffCountdown(Object seconds) {
    return 'Shutting down in $seconds s…';
  }

  @override
  String rebootCountdown(Object seconds) {
    return 'Restarting in $seconds s…';
  }

  @override
  String get suspend => 'Suspend';

  @override
  String get reboot => 'Restart';

  @override
  String get powerOff => 'Shut down';

  @override
  String get volumeMutedTooltip => 'Muted';

  @override
  String volumeTooltip(Object percent) {
    return 'Volume: $percent';
  }

  @override
  String get clipboardTitle => 'Clipboard';

  @override
  String get clear => 'Clear';

  @override
  String get clipboardEmpty => 'Nothing copied in the last 15 minutes.';

  @override
  String get cancel => 'Cancel';

  @override
  String get openInFiles => 'Open in Files';

  @override
  String get folderEmpty => 'The folder is empty.';

  @override
  String get searchApps => 'Search apps';

  @override
  String get noAppsFound => 'No apps found';

  @override
  String get notifications => 'Notifications';

  @override
  String get clearAll => 'Clear all';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get minimize => 'Minimize';

  @override
  String get restore => 'Restore';

  @override
  String get maximize => 'Maximize';

  @override
  String get close => 'Close';

  @override
  String get menu => 'Menu';

  @override
  String get power => 'Power';

  @override
  String get battery => 'Battery';

  @override
  String get muted => 'Muted';

  @override
  String get unmute => 'Unmute';

  @override
  String get mute => 'Mute';

  @override
  String get powerOffNow => 'Shut down now';

  @override
  String get rebootNow => 'Restart now';

  @override
  String get lock => 'Lock';

  @override
  String get logout => 'Log out';

  @override
  String get networkPortalLogin => 'Open the login page';

  @override
  String get kindVpn => 'VPN';

  @override
  String vpnFailed(String name) {
    return 'Could not turn on $name.';
  }

  @override
  String hotspotSharing(String name) {
    return 'Sharing as $name';
  }

  @override
  String get hotspotStarting => 'Starting to share…';

  @override
  String get hotspotStop => 'Stop';
}
