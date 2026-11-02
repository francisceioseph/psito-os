import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'sdk_localizations_en.dart';
import 'sdk_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of SdkLocalizations
/// returned by `SdkLocalizations.of(context)`.
///
/// Applications need to include `SdkLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/sdk_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: SdkLocalizations.localizationsDelegates,
///   supportedLocales: SdkLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the SdkLocalizations.supportedLocales
/// property.
abstract class SdkLocalizations {
  SdkLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static SdkLocalizations of(BuildContext context) {
    return Localizations.of<SdkLocalizations>(context, SdkLocalizations)!;
  }

  static const LocalizationsDelegate<SdkLocalizations> delegate =
      _SdkLocalizationsDelegate();

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

  /// No description provided for @wallpaperNoite.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get wallpaperNoite;

  /// No description provided for @wallpaperCalopsita.
  ///
  /// In en, this message translates to:
  /// **'Cockatiel'**
  String get wallpaperCalopsita;

  /// No description provided for @wallpaperPorDoSol.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get wallpaperPorDoSol;

  /// No description provided for @wallpaperFloresta.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get wallpaperFloresta;

  /// No description provided for @wallpaperOceano.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get wallpaperOceano;

  /// No description provided for @dockPositionBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get dockPositionBottom;

  /// No description provided for @dockPositionLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get dockPositionLeft;

  /// No description provided for @dockPositionRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get dockPositionRight;

  /// No description provided for @shortcutLauncher.
  ///
  /// In en, this message translates to:
  /// **'Open and close the launcher'**
  String get shortcutLauncher;

  /// No description provided for @shortcutLauncherVm.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+Space'**
  String get shortcutLauncherVm;

  /// No description provided for @shortcutSwitchWindows.
  ///
  /// In en, this message translates to:
  /// **'Switch windows'**
  String get shortcutSwitchWindows;

  /// No description provided for @shortcutCloseWindow.
  ///
  /// In en, this message translates to:
  /// **'Close the window'**
  String get shortcutCloseWindow;

  /// No description provided for @shortcutMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get shortcutMaximize;

  /// No description provided for @shortcutSnap.
  ///
  /// In en, this message translates to:
  /// **'Snap left / right'**
  String get shortcutSnap;

  /// No description provided for @shortcutMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get shortcutMinimize;

  /// No description provided for @shortcutVolume.
  ///
  /// In en, this message translates to:
  /// **'Raise / lower the volume'**
  String get shortcutVolume;

  /// No description provided for @shortcutVolumeKeys.
  ///
  /// In en, this message translates to:
  /// **'Volume keys'**
  String get shortcutVolumeKeys;

  /// No description provided for @shortcutMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get shortcutMute;

  /// No description provided for @shortcutMuteKey.
  ///
  /// In en, this message translates to:
  /// **'Mute key'**
  String get shortcutMuteKey;

  /// No description provided for @shortcutClipboard.
  ///
  /// In en, this message translates to:
  /// **'Open the clipboard'**
  String get shortcutClipboard;

  /// No description provided for @shortcutClipboardCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy clipboard item 1 to 5 again'**
  String get shortcutClipboardCopy;

  /// No description provided for @shortcutClipboardCopyNative.
  ///
  /// In en, this message translates to:
  /// **'Super+1 to 5'**
  String get shortcutClipboardCopyNative;

  /// No description provided for @shortcutClipboardCopyVm.
  ///
  /// In en, this message translates to:
  /// **'Alt+Shift+1 to 5'**
  String get shortcutClipboardCopyVm;

  /// No description provided for @shortcutShowDesktop.
  ///
  /// In en, this message translates to:
  /// **'Show the desktop'**
  String get shortcutShowDesktop;

  /// No description provided for @shortcutDismiss.
  ///
  /// In en, this message translates to:
  /// **'Close launcher, panel or switcher'**
  String get shortcutDismiss;

  /// No description provided for @openNoApp.
  ///
  /// In en, this message translates to:
  /// **'No app opens \"{file}\".'**
  String openNoApp(Object file);

  /// No description provided for @openFailed.
  ///
  /// In en, this message translates to:
  /// **'The shell couldn\'t open it ({detail}).'**
  String openFailed(Object detail);

  /// No description provided for @shortcutLock.
  ///
  /// In en, this message translates to:
  /// **'Lock the screen'**
  String get shortcutLock;

  /// No description provided for @wallpaperPsitoEscuro.
  ///
  /// In en, this message translates to:
  /// **'Psito dark'**
  String get wallpaperPsitoEscuro;

  /// No description provided for @wallpaperPsitoClaro.
  ///
  /// In en, this message translates to:
  /// **'Psito light'**
  String get wallpaperPsitoClaro;

  /// No description provided for @wallpaperGrafite.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get wallpaperGrafite;

  /// No description provided for @wallpaperMarinho.
  ///
  /// In en, this message translates to:
  /// **'Navy'**
  String get wallpaperMarinho;

  /// No description provided for @wallpaperMusgo.
  ///
  /// In en, this message translates to:
  /// **'Moss'**
  String get wallpaperMusgo;

  /// No description provided for @wallpaperVinho.
  ///
  /// In en, this message translates to:
  /// **'Wine'**
  String get wallpaperVinho;

  /// No description provided for @wallpaperAmeixa.
  ///
  /// In en, this message translates to:
  /// **'Plum'**
  String get wallpaperAmeixa;
}

class _SdkLocalizationsDelegate
    extends LocalizationsDelegate<SdkLocalizations> {
  const _SdkLocalizationsDelegate();

  @override
  Future<SdkLocalizations> load(Locale locale) {
    return SynchronousFuture<SdkLocalizations>(lookupSdkLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_SdkLocalizationsDelegate old) => false;
}

SdkLocalizations lookupSdkLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SdkLocalizationsEn();
    case 'pt':
      return SdkLocalizationsPt();
  }

  throw FlutterError(
    'SdkLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
