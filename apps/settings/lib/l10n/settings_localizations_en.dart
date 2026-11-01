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

  @override
  String get sectionPrivacy => 'Privacy';

  @override
  String get lockAfter => 'Lock the screen after';

  @override
  String get lockNever => 'Never';

  @override
  String lockMinutes(Object minutes) {
    return '$minutes min';
  }

  @override
  String get lockNote =>
      'The screen also locks with Super+L and before suspending.';

  @override
  String get sectionUsers => 'Users';

  @override
  String get usersUnavailable => 'The list of users isn\'t available.';

  @override
  String get userAdmin => 'Administrator';

  @override
  String get userStandard => 'Standard';

  @override
  String userYou(Object login, Object role) {
    return '$login · $role · you';
  }

  @override
  String get userName => 'Full name';

  @override
  String get userLogin => 'Login name';

  @override
  String get userNewPassword => 'New password';

  @override
  String get userConfirmPassword => 'Confirm the password';

  @override
  String get userSaveName => 'Save name';

  @override
  String get userChangePassword => 'Change password';

  @override
  String get userDelete => 'Delete account';

  @override
  String userDeleteConfirm(Object login) {
    return 'Delete $login and all their files?';
  }

  @override
  String get userAdd => 'Add user';

  @override
  String get userCreate => 'Create account';

  @override
  String get userAdminChoice => 'Administrator';

  @override
  String get userSaved => 'Saved.';

  @override
  String get userFailed => 'That didn\'t work, or it was cancelled.';

  @override
  String get userPasswordEmpty => 'Enter a password.';

  @override
  String get userPasswordMismatch => 'The passwords don\'t match.';

  @override
  String get userLoginInvalid =>
      'Use lowercase letters, digits, - and _, starting with a letter.';

  @override
  String get savedNetworks => 'Saved networks';

  @override
  String get connectionAuto => 'Connects automatically';

  @override
  String get connectionManual => 'Only when you ask';

  @override
  String get connectionAutoconnect => 'Connect automatically';

  @override
  String get connectionPriority => 'Priority';

  @override
  String get connectionPriorityHint =>
      'With two networks in range, joins the one with the higher number.';

  @override
  String get connectionMetered => 'Metered network';

  @override
  String get connectionMeteredAuto => 'Automatic';

  @override
  String get connectionMeteredYes => 'Yes, charges for data';

  @override
  String get connectionMeteredNo => 'No';

  @override
  String get connectionIpv4 => 'IPv4';

  @override
  String get connectionIpv4Auto => 'Automatic (DHCP)';

  @override
  String get connectionIpv4Manual => 'Manual';

  @override
  String get connectionAddress => 'Address and network';

  @override
  String get connectionDnsHint =>
      'Separated by commas. Empty uses the network\'s DNS.';

  @override
  String get connectionSave => 'Save';

  @override
  String get connectionForget => 'Forget';

  @override
  String get connectionBadPriority => 'The priority is a whole number.';

  @override
  String get connectionBadAddress => 'Use an address like 192.168.0.10/24.';

  @override
  String get connectionBadGateway =>
      'The gateway is an address like 192.168.0.1.';

  @override
  String get connectionBadDns => 'The DNS is a list of addresses like 1.1.1.1.';

  @override
  String get detailIpv4 => 'IPv4';

  @override
  String get detailIpv6 => 'IPv6';

  @override
  String get detailGateway => 'Gateway';

  @override
  String get detailDns => 'DNS';

  @override
  String get detailMac => 'MAC address';

  @override
  String connectionForgetConfirm(String name) {
    return 'Forget $name?';
  }

  @override
  String get vpnImport => 'Import VPN…';

  @override
  String get vpnImportTitle => 'Import VPN (WireGuard or OpenVPN)';

  @override
  String get vpnImported =>
      'VPN saved. Turn it on from the network icon in the top bar.';

  @override
  String get vpnImportFailed => 'Could not import this file.';

  @override
  String get hotspotTitle => 'Share this connection';

  @override
  String get hotspotHint =>
      'Other devices join this network and use this computer\'s internet. While sharing, Wi-Fi leaves the network it is on.';

  @override
  String get hotspotName => 'Network name';

  @override
  String get hotspotPassword => 'Password';

  @override
  String get hotspotNewPassword => 'Generate another password';

  @override
  String get hotspotBadName => 'The name needs 1 to 32 bytes.';

  @override
  String get hotspotBadPassword =>
      'The password needs 8 to 63 characters, with no accents.';

  @override
  String get hotspotStart => 'Start sharing';

  @override
  String get hotspotStop => 'Stop sharing';

  @override
  String get hotspotStarting => 'Starting…';

  @override
  String get hotspotActive => 'Sharing. Other devices can join now.';

  @override
  String get hotspotNoUplink =>
      'There is no other connection: whoever joins will not have internet.';

  @override
  String get hotspotWifiOff => 'Turn on Wi-Fi to share.';

  @override
  String get hotspotFailed => 'Could not start sharing.';

  @override
  String get accentYellow => 'Yellow';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentPurple => 'Purple';

  @override
  String get accentPink => 'Pink';

  @override
  String get desktopVolumes => 'External disks';

  @override
  String get sectionStorage => 'Storage';

  @override
  String get storageUnavailable => 'Could not measure the disks.';

  @override
  String get storageThisComputer => 'This computer';

  @override
  String get storageUnnamed => 'Unnamed disk';

  @override
  String storageFree(String free, String total) {
    return '$free free of $total';
  }

  @override
  String storageNotMounted(String total) {
    return '$total, not mounted';
  }

  @override
  String get storageAlmostFull => 'This disk is almost full.';

  @override
  String get storageLargest => 'Largest folders';

  @override
  String get storageHideLargest => 'Hide folders';

  @override
  String get storageNoFolders => 'No folders here.';

  @override
  String storageOpenFolder(String name) {
    return 'Open $name in Files';
  }

  @override
  String get storageTrash => 'Trash';

  @override
  String storageTrashSize(String size) {
    return '$size in the trash, on every disk';
  }

  @override
  String get storageEmptyTrash => 'Empty';

  @override
  String get storageFormat => 'Format…';

  @override
  String storageFormatWarning(String name) {
    return 'This erases everything on $name, and it cannot be undone.';
  }

  @override
  String get storageFormatType => 'Format';

  @override
  String get storageFormatFat => 'FAT: works on any device, files up to 4 GB';

  @override
  String get storageFormatExfat => 'exFAT: works on most devices, large files';

  @override
  String get storageFormatExt4 => 'ext4: Linux only';

  @override
  String get storageFormatLabel => 'New name';

  @override
  String storageFormatConfirm(String name) {
    return 'Type $name to confirm';
  }

  @override
  String get storageFormatAction => 'Erase and format';

  @override
  String get storageFormatCancel => 'Cancel';

  @override
  String get storageFormatBusy =>
      'The disk is in use. Close what is using it and try again.';

  @override
  String get storageFormatFailed => 'Could not format the disk.';

  @override
  String get storageFormatDone => 'Disk formatted.';
}
