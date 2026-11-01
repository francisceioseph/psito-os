import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'system_localizations_en.dart';
import 'system_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of SystemLocalizations
/// returned by `SystemLocalizations.of(context)`.
///
/// Applications need to include `SystemLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/system_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: SystemLocalizations.localizationsDelegates,
///   supportedLocales: SystemLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the SystemLocalizations.supportedLocales
/// property.
abstract class SystemLocalizations {
  SystemLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static SystemLocalizations of(BuildContext context) {
    return Localizations.of<SystemLocalizations>(context, SystemLocalizations)!;
  }

  static const LocalizationsDelegate<SystemLocalizations> delegate =
      _SystemLocalizationsDelegate();

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

  /// No description provided for @durationUnderMinute.
  ///
  /// In en, this message translates to:
  /// **'less than 1 min'**
  String get durationUnderMinute;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(Object minutes);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String durationHours(Object hours);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(Object hours, Object minutes);

  /// No description provided for @batteryFull.
  ///
  /// In en, this message translates to:
  /// **'Charged'**
  String get batteryFull;

  /// No description provided for @batteryCharging.
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get batteryCharging;

  /// No description provided for @batteryDischarging.
  ///
  /// In en, this message translates to:
  /// **'On battery'**
  String get batteryDischarging;

  /// No description provided for @batteryUntilFull.
  ///
  /// In en, this message translates to:
  /// **'{time} until full'**
  String batteryUntilFull(Object time);

  /// No description provided for @batteryRemaining.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String batteryRemaining(Object time);

  /// No description provided for @batteryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Battery: {percent}'**
  String batteryTooltip(Object percent);

  /// No description provided for @powerSource.
  ///
  /// In en, this message translates to:
  /// **'Power source: {source}'**
  String powerSource(Object source);

  /// No description provided for @powerSourceAdapter.
  ///
  /// In en, this message translates to:
  /// **'Adapter'**
  String get powerSourceAdapter;

  /// No description provided for @powerSourceBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get powerSourceBattery;

  /// No description provided for @clipboardTooltip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Clipboard: 1 item} other{Clipboard: {count} items}}'**
  String clipboardTooltip(num count);

  /// No description provided for @timeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String timeMinutesAgo(Object minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} h ago'**
  String timeHoursAgo(Object hours);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} d ago'**
  String timeDaysAgo(Object days);

  /// No description provided for @orShortcut.
  ///
  /// In en, this message translates to:
  /// **'or {keys}'**
  String orShortcut(Object keys);

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied: {what}'**
  String copied(Object what);

  /// No description provided for @clipImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get clipImage;

  /// No description provided for @clipFiles.
  ///
  /// In en, this message translates to:
  /// **'{count} files: {names}'**
  String clipFiles(Object count, Object names);

  /// No description provided for @wifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get wifi;

  /// No description provided for @wifiSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for networks…'**
  String get wifiSearching;

  /// No description provided for @wifiNoNetworks.
  ///
  /// In en, this message translates to:
  /// **'No networks found'**
  String get wifiNoNetworks;

  /// No description provided for @wifiOtherNetwork.
  ///
  /// In en, this message translates to:
  /// **'Other network…'**
  String get wifiOtherNetwork;

  /// No description provided for @wifiNetworkName.
  ///
  /// In en, this message translates to:
  /// **'Network name'**
  String get wifiNetworkName;

  /// No description provided for @wifiPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get wifiPassword;

  /// No description provided for @wifiShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get wifiShowPassword;

  /// No description provided for @wifiHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get wifiHidePassword;

  /// No description provided for @wifiConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get wifiConnect;

  /// No description provided for @wifiCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get wifiCancel;

  /// No description provided for @wifiDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get wifiDisconnect;

  /// No description provided for @wifiWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get wifiWrongPassword;

  /// No description provided for @wifiNotFound.
  ///
  /// In en, this message translates to:
  /// **'Network not found'**
  String get wifiNotFound;

  /// No description provided for @wifiFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect'**
  String get wifiFailed;

  /// No description provided for @wifiUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This kind of network is not supported yet'**
  String get wifiUnsupported;

  /// No description provided for @networkSettings.
  ///
  /// In en, this message translates to:
  /// **'Network settings'**
  String get networkSettings;

  /// No description provided for @networkOff.
  ///
  /// In en, this message translates to:
  /// **'Network off'**
  String get networkOff;

  /// No description provided for @networkConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get networkConnecting;

  /// No description provided for @networkDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get networkDisconnected;

  /// No description provided for @networkNoInternet.
  ///
  /// In en, this message translates to:
  /// **'Connected, no internet'**
  String get networkNoInternet;

  /// No description provided for @connectivityFull.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get connectivityFull;

  /// No description provided for @connectivityNone.
  ///
  /// In en, this message translates to:
  /// **'No internet'**
  String get connectivityNone;

  /// No description provided for @connectivityPortal.
  ///
  /// In en, this message translates to:
  /// **'Sign-in portal'**
  String get connectivityPortal;

  /// No description provided for @connectivityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get connectivityUnknown;

  /// No description provided for @kindEthernet.
  ///
  /// In en, this message translates to:
  /// **'Cable'**
  String get kindEthernet;

  /// No description provided for @kindWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get kindWifi;

  /// No description provided for @network.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get network;

  /// No description provided for @powerOffQuestion.
  ///
  /// In en, this message translates to:
  /// **'Shut down Psito OS?'**
  String get powerOffQuestion;

  /// No description provided for @rebootQuestion.
  ///
  /// In en, this message translates to:
  /// **'Restart Psito OS?'**
  String get rebootQuestion;

  /// No description provided for @powerOffCountdown.
  ///
  /// In en, this message translates to:
  /// **'Shutting down in {seconds} s…'**
  String powerOffCountdown(Object seconds);

  /// No description provided for @rebootCountdown.
  ///
  /// In en, this message translates to:
  /// **'Restarting in {seconds} s…'**
  String rebootCountdown(Object seconds);

  /// No description provided for @suspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get suspend;

  /// No description provided for @reboot.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get reboot;

  /// No description provided for @powerOff.
  ///
  /// In en, this message translates to:
  /// **'Shut down'**
  String get powerOff;

  /// No description provided for @volumeMutedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get volumeMutedTooltip;

  /// No description provided for @volumeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Volume: {percent}'**
  String volumeTooltip(Object percent);

  /// No description provided for @clipboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get clipboardTitle;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing copied in the last 15 minutes.'**
  String get clipboardEmpty;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'The Feathered Operating System'**
  String get tagline;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @openInFiles.
  ///
  /// In en, this message translates to:
  /// **'Open in Files'**
  String get openInFiles;

  /// No description provided for @folderEmpty.
  ///
  /// In en, this message translates to:
  /// **'The folder is empty.'**
  String get folderEmpty;

  /// No description provided for @searchApps.
  ///
  /// In en, this message translates to:
  /// **'Search apps'**
  String get searchApps;

  /// No description provided for @noAppsFound.
  ///
  /// In en, this message translates to:
  /// **'No apps found'**
  String get noAppsFound;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @maximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get maximize;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @power.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get power;

  /// No description provided for @battery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get battery;

  /// No description provided for @muted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get muted;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @powerOffNow.
  ///
  /// In en, this message translates to:
  /// **'Shut down now'**
  String get powerOffNow;

  /// No description provided for @rebootNow.
  ///
  /// In en, this message translates to:
  /// **'Restart now'**
  String get rebootNow;

  /// No description provided for @lock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lock;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;
}

class _SystemLocalizationsDelegate
    extends LocalizationsDelegate<SystemLocalizations> {
  const _SystemLocalizationsDelegate();

  @override
  Future<SystemLocalizations> load(Locale locale) {
    return SynchronousFuture<SystemLocalizations>(
      lookupSystemLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_SystemLocalizationsDelegate old) => false;
}

SystemLocalizations lookupSystemLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SystemLocalizationsEn();
    case 'pt':
      return SystemLocalizationsPt();
  }

  throw FlutterError(
    'SystemLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
