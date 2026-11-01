import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'clock_localizations_en.dart';
import 'clock_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of ClockLocalizations
/// returned by `ClockLocalizations.of(context)`.
///
/// Applications need to include `ClockLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/clock_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: ClockLocalizations.localizationsDelegates,
///   supportedLocales: ClockLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the ClockLocalizations.supportedLocales
/// property.
abstract class ClockLocalizations {
  ClockLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static ClockLocalizations of(BuildContext context) {
    return Localizations.of<ClockLocalizations>(context, ClockLocalizations)!;
  }

  static const LocalizationsDelegate<ClockLocalizations> delegate =
      _ClockLocalizationsDelegate();

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
  /// **'Clock'**
  String get appName;

  /// No description provided for @timerDone.
  ///
  /// In en, this message translates to:
  /// **'Timer finished'**
  String get timerDone;

  /// No description provided for @timerDoneBody.
  ///
  /// In en, this message translates to:
  /// **'10 seconds have passed.'**
  String get timerDoneBody;

  /// No description provided for @timerIdle.
  ///
  /// In en, this message translates to:
  /// **'10 s timer'**
  String get timerIdle;

  /// No description provided for @timerRemaining.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s left'**
  String timerRemaining(Object seconds);

  /// No description provided for @timerStart.
  ///
  /// In en, this message translates to:
  /// **'Start timer'**
  String get timerStart;
}

class _ClockLocalizationsDelegate
    extends LocalizationsDelegate<ClockLocalizations> {
  const _ClockLocalizationsDelegate();

  @override
  Future<ClockLocalizations> load(Locale locale) {
    return SynchronousFuture<ClockLocalizations>(
      lookupClockLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_ClockLocalizationsDelegate old) => false;
}

ClockLocalizations lookupClockLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return ClockLocalizationsEn();
    case 'pt':
      return ClockLocalizationsPt();
  }

  throw FlutterError(
    'ClockLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
