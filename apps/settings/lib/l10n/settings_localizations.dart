import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'settings_localizations_en.dart';
import 'settings_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of SettingsLocalizations
/// returned by `SettingsLocalizations.of(context)`.
///
/// Applications need to include `SettingsLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/settings_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: SettingsLocalizations.localizationsDelegates,
///   supportedLocales: SettingsLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the SettingsLocalizations.supportedLocales
/// property.
abstract class SettingsLocalizations {
  SettingsLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static SettingsLocalizations of(BuildContext context) {
    return Localizations.of<SettingsLocalizations>(
      context,
      SettingsLocalizations,
    )!;
  }

  static const LocalizationsDelegate<SettingsLocalizations> delegate =
      _SettingsLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get appName;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// No description provided for @sectionDock.
  ///
  /// In en, this message translates to:
  /// **'Dock'**
  String get sectionDock;

  /// No description provided for @sectionDesktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get sectionDesktop;

  /// No description provided for @sectionDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get sectionDateTime;

  /// No description provided for @sectionNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get sectionNetwork;

  /// No description provided for @sectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get sectionNotifications;

  /// No description provided for @sectionPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get sectionPower;

  /// No description provided for @sectionShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get sectionShortcuts;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @shortcutsNote.
  ///
  /// In en, this message translates to:
  /// **'Super and Alt+Tab are taken by the computer\'s system and don\'t reach the VM, so each action has an alternative combination. Both work at the same time. In Switch windows, hold the modifier and press Tab to choose; Shift goes back.'**
  String get shortcutsNote;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Flutter shell as a Wayland client of labwc, with each app in its own process.'**
  String get aboutDescription;

  /// No description provided for @desktopAutoArrangeHint.
  ///
  /// In en, this message translates to:
  /// **'Icons stay sorted by name, with no gaps. Moving an icon turns this off, so it stays where it was dropped.'**
  String get desktopAutoArrangeHint;

  /// No description provided for @desktopHotCornerHint.
  ///
  /// In en, this message translates to:
  /// **'Moving the pointer to the top right corner of the screen minimizes the windows, and doing it again brings them back.'**
  String get desktopHotCornerHint;

  /// No description provided for @deviceConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get deviceConnected;

  /// No description provided for @deviceConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get deviceConnecting;

  /// No description provided for @deviceDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get deviceDisconnected;

  /// No description provided for @deviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No cable or signal'**
  String get deviceUnavailable;

  /// No description provided for @deviceUnmanaged.
  ///
  /// In en, this message translates to:
  /// **'Unmanaged'**
  String get deviceUnmanaged;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Same as the system'**
  String get languageSystem;

  /// No description provided for @languageNote.
  ///
  /// In en, this message translates to:
  /// **'Psito apps change right away. Other programs follow when opened again.'**
  String get languageNote;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get wallpaper;

  /// No description provided for @iconSize.
  ///
  /// In en, this message translates to:
  /// **'Icon size'**
  String get iconSize;

  /// No description provided for @magnification.
  ///
  /// In en, this message translates to:
  /// **'Magnification'**
  String get magnification;

  /// No description provided for @magnificationHint.
  ///
  /// In en, this message translates to:
  /// **'The icon under the mouse grows.'**
  String get magnificationHint;

  /// No description provided for @screenPosition.
  ///
  /// In en, this message translates to:
  /// **'Position on screen'**
  String get screenPosition;

  /// No description provided for @autoHide.
  ///
  /// In en, this message translates to:
  /// **'Hide automatically'**
  String get autoHide;

  /// No description provided for @autoHideHint.
  ///
  /// In en, this message translates to:
  /// **'The dock disappears and comes back when the pointer touches the edge.'**
  String get autoHideHint;

  /// No description provided for @desktopShowIcons.
  ///
  /// In en, this message translates to:
  /// **'Show icons'**
  String get desktopShowIcons;

  /// No description provided for @desktopShowIconsHint.
  ///
  /// In en, this message translates to:
  /// **'The files in the Desktop folder, on the desktop.'**
  String get desktopShowIconsHint;

  /// No description provided for @desktopHome.
  ///
  /// In en, this message translates to:
  /// **'Home folder'**
  String get desktopHome;

  /// No description provided for @desktopTrash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get desktopTrash;

  /// No description provided for @desktopAutoArrange.
  ///
  /// In en, this message translates to:
  /// **'Arrange automatically'**
  String get desktopAutoArrange;

  /// No description provided for @desktopHotCorner.
  ///
  /// In en, this message translates to:
  /// **'Corner to show the desktop'**
  String get desktopHotCorner;

  /// No description provided for @use24h.
  ///
  /// In en, this message translates to:
  /// **'24-hour format'**
  String get use24h;

  /// No description provided for @showSeconds.
  ///
  /// In en, this message translates to:
  /// **'Show seconds'**
  String get showSeconds;

  /// No description provided for @timeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'System date and time unavailable (timedated)'**
  String get timeUnavailable;

  /// No description provided for @ntp.
  ///
  /// In en, this message translates to:
  /// **'Set automatically'**
  String get ntp;

  /// No description provided for @ntpOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get ntpOff;

  /// No description provided for @ntpSynced.
  ///
  /// In en, this message translates to:
  /// **'Synchronized with the internet'**
  String get ntpSynced;

  /// No description provided for @ntpWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for synchronization'**
  String get ntpWaiting;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get timezone;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @ntpHint.
  ///
  /// In en, this message translates to:
  /// **'With automatic setting on, the time comes from the network.'**
  String get ntpHint;

  /// No description provided for @timezoneSearch.
  ///
  /// In en, this message translates to:
  /// **'Search time zone (e.g. sao paulo)'**
  String get timezoneSearch;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @networkManagerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'NetworkManager unavailable'**
  String get networkManagerUnavailable;

  /// No description provided for @noNetworkDevice.
  ///
  /// In en, this message translates to:
  /// **'No network device'**
  String get noNetworkDevice;

  /// No description provided for @networkHint.
  ///
  /// In en, this message translates to:
  /// **'To turn the network on or off, use the network icon in the top bar.'**
  String get networkHint;

  /// No description provided for @doNotDisturb.
  ///
  /// In en, this message translates to:
  /// **'Do not disturb'**
  String get doNotDisturb;

  /// No description provided for @doNotDisturbHint.
  ///
  /// In en, this message translates to:
  /// **'Notifications go to the panel without appearing on screen.'**
  String get doNotDisturbHint;

  /// No description provided for @showBatteryPercentage.
  ///
  /// In en, this message translates to:
  /// **'Show battery percentage'**
  String get showBatteryPercentage;

  /// No description provided for @batteryHint.
  ///
  /// In en, this message translates to:
  /// **'The battery icon only appears on computers with a battery.'**
  String get batteryHint;

  /// No description provided for @shortcutAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get shortcutAction;

  /// No description provided for @shortcutNative.
  ///
  /// In en, this message translates to:
  /// **'Native'**
  String get shortcutNative;

  /// No description provided for @systemInfoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'System information unavailable (hostnamed)'**
  String get systemInfoUnavailable;

  /// No description provided for @computerName.
  ///
  /// In en, this message translates to:
  /// **'Computer name'**
  String get computerName;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @hardware.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get hardware;

  /// No description provided for @settingsPath.
  ///
  /// In en, this message translates to:
  /// **'Settings saved in ~/.config/psito/settings.json'**
  String get settingsPath;

  /// No description provided for @sectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get sectionPrivacy;

  /// No description provided for @lockAfter.
  ///
  /// In en, this message translates to:
  /// **'Lock the screen after'**
  String get lockAfter;

  /// No description provided for @lockNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get lockNever;

  /// No description provided for @lockMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String lockMinutes(Object minutes);

  /// No description provided for @lockNote.
  ///
  /// In en, this message translates to:
  /// **'The screen also locks with Super+L and before suspending.'**
  String get lockNote;

  /// No description provided for @sectionUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get sectionUsers;

  /// No description provided for @usersUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The list of users isn\'t available.'**
  String get usersUnavailable;

  /// No description provided for @userAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get userAdmin;

  /// No description provided for @userStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get userStandard;

  /// No description provided for @userYou.
  ///
  /// In en, this message translates to:
  /// **'{login} · {role} · you'**
  String userYou(Object login, Object role);

  /// No description provided for @userName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get userName;

  /// No description provided for @userLogin.
  ///
  /// In en, this message translates to:
  /// **'Login name'**
  String get userLogin;

  /// No description provided for @userNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get userNewPassword;

  /// No description provided for @userConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm the password'**
  String get userConfirmPassword;

  /// No description provided for @userSaveName.
  ///
  /// In en, this message translates to:
  /// **'Save name'**
  String get userSaveName;

  /// No description provided for @userChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get userChangePassword;

  /// No description provided for @userDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get userDelete;

  /// No description provided for @userDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {login} and all their files?'**
  String userDeleteConfirm(Object login);

  /// No description provided for @userAdd.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get userAdd;

  /// No description provided for @userCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get userCreate;

  /// No description provided for @userAdminChoice.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get userAdminChoice;

  /// No description provided for @userSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get userSaved;

  /// No description provided for @userFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work, or it was cancelled.'**
  String get userFailed;

  /// No description provided for @userPasswordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a password.'**
  String get userPasswordEmpty;

  /// No description provided for @userPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords don\'t match.'**
  String get userPasswordMismatch;

  /// No description provided for @userLoginInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use lowercase letters, digits, - and _, starting with a letter.'**
  String get userLoginInvalid;

  /// No description provided for @savedNetworks.
  ///
  /// In en, this message translates to:
  /// **'Saved networks'**
  String get savedNetworks;

  /// No description provided for @connectionAuto.
  ///
  /// In en, this message translates to:
  /// **'Connects automatically'**
  String get connectionAuto;

  /// No description provided for @connectionManual.
  ///
  /// In en, this message translates to:
  /// **'Only when you ask'**
  String get connectionManual;

  /// No description provided for @connectionAutoconnect.
  ///
  /// In en, this message translates to:
  /// **'Connect automatically'**
  String get connectionAutoconnect;

  /// No description provided for @connectionPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get connectionPriority;

  /// No description provided for @connectionPriorityHint.
  ///
  /// In en, this message translates to:
  /// **'With two networks in range, joins the one with the higher number.'**
  String get connectionPriorityHint;

  /// No description provided for @connectionMetered.
  ///
  /// In en, this message translates to:
  /// **'Metered network'**
  String get connectionMetered;

  /// No description provided for @connectionMeteredAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get connectionMeteredAuto;

  /// No description provided for @connectionMeteredYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, charges for data'**
  String get connectionMeteredYes;

  /// No description provided for @connectionMeteredNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get connectionMeteredNo;

  /// No description provided for @connectionIpv4.
  ///
  /// In en, this message translates to:
  /// **'IPv4'**
  String get connectionIpv4;

  /// No description provided for @connectionIpv4Auto.
  ///
  /// In en, this message translates to:
  /// **'Automatic (DHCP)'**
  String get connectionIpv4Auto;

  /// No description provided for @connectionIpv4Manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get connectionIpv4Manual;

  /// No description provided for @connectionAddress.
  ///
  /// In en, this message translates to:
  /// **'Address and network'**
  String get connectionAddress;

  /// No description provided for @connectionDnsHint.
  ///
  /// In en, this message translates to:
  /// **'Separated by commas. Empty uses the network\'s DNS.'**
  String get connectionDnsHint;

  /// No description provided for @connectionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get connectionSave;

  /// No description provided for @connectionForget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get connectionForget;

  /// No description provided for @connectionBadPriority.
  ///
  /// In en, this message translates to:
  /// **'The priority is a whole number.'**
  String get connectionBadPriority;

  /// No description provided for @connectionBadAddress.
  ///
  /// In en, this message translates to:
  /// **'Use an address like 192.168.0.10/24.'**
  String get connectionBadAddress;

  /// No description provided for @connectionBadGateway.
  ///
  /// In en, this message translates to:
  /// **'The gateway is an address like 192.168.0.1.'**
  String get connectionBadGateway;

  /// No description provided for @connectionBadDns.
  ///
  /// In en, this message translates to:
  /// **'The DNS is a list of addresses like 1.1.1.1.'**
  String get connectionBadDns;

  /// No description provided for @detailIpv4.
  ///
  /// In en, this message translates to:
  /// **'IPv4'**
  String get detailIpv4;

  /// No description provided for @detailIpv6.
  ///
  /// In en, this message translates to:
  /// **'IPv6'**
  String get detailIpv6;

  /// No description provided for @detailGateway.
  ///
  /// In en, this message translates to:
  /// **'Gateway'**
  String get detailGateway;

  /// No description provided for @detailDns.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get detailDns;

  /// No description provided for @detailMac.
  ///
  /// In en, this message translates to:
  /// **'MAC address'**
  String get detailMac;

  /// No description provided for @connectionForgetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Forget {name}?'**
  String connectionForgetConfirm(String name);

  /// No description provided for @vpnImport.
  ///
  /// In en, this message translates to:
  /// **'Import VPN…'**
  String get vpnImport;

  /// No description provided for @vpnImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import VPN (WireGuard or OpenVPN)'**
  String get vpnImportTitle;

  /// No description provided for @vpnImported.
  ///
  /// In en, this message translates to:
  /// **'VPN saved. Turn it on from the network icon in the top bar.'**
  String get vpnImported;

  /// No description provided for @vpnImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import this file.'**
  String get vpnImportFailed;

  /// No description provided for @hotspotTitle.
  ///
  /// In en, this message translates to:
  /// **'Share this connection'**
  String get hotspotTitle;

  /// No description provided for @hotspotHint.
  ///
  /// In en, this message translates to:
  /// **'Other devices join this network and use this computer\'s internet. While sharing, Wi-Fi leaves the network it is on.'**
  String get hotspotHint;

  /// No description provided for @hotspotName.
  ///
  /// In en, this message translates to:
  /// **'Network name'**
  String get hotspotName;

  /// No description provided for @hotspotPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get hotspotPassword;

  /// No description provided for @hotspotNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Generate another password'**
  String get hotspotNewPassword;

  /// No description provided for @hotspotBadName.
  ///
  /// In en, this message translates to:
  /// **'The name needs 1 to 32 bytes.'**
  String get hotspotBadName;

  /// No description provided for @hotspotBadPassword.
  ///
  /// In en, this message translates to:
  /// **'The password needs 8 to 63 characters, with no accents.'**
  String get hotspotBadPassword;

  /// No description provided for @hotspotStart.
  ///
  /// In en, this message translates to:
  /// **'Start sharing'**
  String get hotspotStart;

  /// No description provided for @hotspotStop.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get hotspotStop;

  /// No description provided for @hotspotStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get hotspotStarting;

  /// No description provided for @hotspotActive.
  ///
  /// In en, this message translates to:
  /// **'Sharing. Other devices can join now.'**
  String get hotspotActive;

  /// No description provided for @hotspotNoUplink.
  ///
  /// In en, this message translates to:
  /// **'There is no other connection: whoever joins will not have internet.'**
  String get hotspotNoUplink;

  /// No description provided for @hotspotWifiOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on Wi-Fi to share.'**
  String get hotspotWifiOff;

  /// No description provided for @hotspotFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start sharing.'**
  String get hotspotFailed;

  /// No description provided for @accentYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get accentYellow;

  /// No description provided for @accentOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get accentOrange;

  /// No description provided for @accentGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get accentGreen;

  /// No description provided for @accentBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get accentBlue;

  /// No description provided for @accentPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get accentPurple;

  /// No description provided for @accentPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get accentPink;
}

class _SettingsLocalizationsDelegate
    extends LocalizationsDelegate<SettingsLocalizations> {
  const _SettingsLocalizationsDelegate();

  @override
  Future<SettingsLocalizations> load(Locale locale) {
    return SynchronousFuture<SettingsLocalizations>(
      lookupSettingsLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_SettingsLocalizationsDelegate old) => false;
}

SettingsLocalizations lookupSettingsLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SettingsLocalizationsEn();
    case 'pt':
      return SettingsLocalizationsPt();
  }

  throw FlutterError(
    'SettingsLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
