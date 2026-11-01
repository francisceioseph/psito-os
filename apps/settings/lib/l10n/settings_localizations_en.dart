// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'settings_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SettingsLocalizationsEn extends SettingsLocalizations {
  SettingsLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Settings';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get sectionDock => 'Dock';

  @override
  String get sectionDesktop => 'Desktop';

  @override
  String get sectionDateTime => 'Date & time';

  @override
  String get sectionNetwork => 'Network';

  @override
  String get sectionNotifications => 'Notifications';

  @override
  String get sectionPower => 'Power';

  @override
  String get sectionShortcuts => 'Shortcuts';

  @override
  String get sectionAbout => 'About';

  @override
  String get shortcutsNote =>
      'Super and Alt+Tab are taken by the computer\'s system and don\'t reach the VM, so each action has an alternative combination. Both work at the same time. In Switch windows, hold the modifier and press Tab to choose; Shift goes back.';

  @override
  String get aboutDescription =>
      'Flutter shell as a Wayland client of labwc, with each app in its own process.';

  @override
  String get desktopAutoArrangeHint =>
      'Icons stay sorted by name, with no gaps. Moving an icon turns this off, so it stays where it was dropped.';

  @override
  String get desktopHotCornerHint =>
      'Moving the pointer to the top right corner of the screen minimizes the windows, and doing it again brings them back.';

  @override
  String get deviceConnected => 'Connected';

  @override
  String get deviceConnecting => 'Connecting…';

  @override
  String get deviceDisconnected => 'Disconnected';

  @override
  String get deviceUnavailable => 'No cable or signal';

  @override
  String get deviceUnmanaged => 'Unmanaged';

  @override
  String get languageSystem => 'Same as the system';

  @override
  String get languageNote =>
      'Psito apps change right away. Other programs follow when opened again.';

  @override
  String get accentColor => 'Accent color';

  @override
  String get wallpaper => 'Wallpaper';

  @override
  String get iconSize => 'Icon size';

  @override
  String get magnification => 'Magnification';

  @override
  String get magnificationHint => 'The icon under the mouse grows.';

  @override
  String get screenPosition => 'Position on screen';

  @override
  String get autoHide => 'Hide automatically';

  @override
  String get autoHideHint =>
      'The dock disappears and comes back when the pointer touches the edge.';

  @override
  String get desktopShowIcons => 'Show icons';

  @override
  String get desktopShowIconsHint =>
      'The files in the Desktop folder, on the desktop.';

  @override
  String get desktopHome => 'Home folder';

  @override
  String get desktopTrash => 'Trash';

  @override
  String get desktopAutoArrange => 'Arrange automatically';

  @override
  String get desktopHotCorner => 'Corner to show the desktop';

  @override
  String get use24h => '24-hour format';

  @override
  String get showSeconds => 'Show seconds';

  @override
  String get timeUnavailable => 'System date and time unavailable (timedated)';

  @override
  String get ntp => 'Set automatically';

  @override
  String get ntpOff => 'Off';

  @override
  String get ntpSynced => 'Synchronized with the internet';

  @override
  String get ntpWaiting => 'Waiting for synchronization';

  @override
  String get timezone => 'Time zone';

  @override
  String get change => 'Change';

  @override
  String get ntpHint =>
      'With automatic setting on, the time comes from the network.';

  @override
  String get timezoneSearch => 'Search time zone (e.g. sao paulo)';

  @override
  String get cancel => 'Cancel';

  @override
  String get networkManagerUnavailable => 'NetworkManager unavailable';

  @override
  String get noNetworkDevice => 'No network device';

  @override
  String get networkHint =>
      'To turn the network on or off, use the network icon in the top bar.';

  @override
  String get doNotDisturb => 'Do not disturb';

  @override
  String get doNotDisturbHint =>
      'Notifications go to the panel without appearing on screen.';

  @override
  String get showBatteryPercentage => 'Show battery percentage';

  @override
  String get batteryHint =>
      'The battery icon only appears on computers with a battery.';

  @override
  String get shortcutAction => 'Action';

  @override
  String get shortcutNative => 'Native';

  @override
  String get systemInfoUnavailable =>
      'System information unavailable (hostnamed)';

  @override
  String get computerName => 'Computer name';

  @override
  String get system => 'System';

  @override
  String get hardware => 'Hardware';

  @override
  String get settingsPath => 'Settings saved in ~/.config/psito/settings.json';
}
