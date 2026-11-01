import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'greeter_localizations_en.dart';
import 'greeter_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of GreeterLocalizations
/// returned by `GreeterLocalizations.of(context)`.
///
/// Applications need to include `GreeterLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/greeter_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: GreeterLocalizations.localizationsDelegates,
///   supportedLocales: GreeterLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the GreeterLocalizations.supportedLocales
/// property.
abstract class GreeterLocalizations {
  GreeterLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static GreeterLocalizations of(BuildContext context) {
    return Localizations.of<GreeterLocalizations>(
      context,
      GreeterLocalizations,
    )!;
  }

  static const LocalizationsDelegate<GreeterLocalizations> delegate =
      _GreeterLocalizationsDelegate();

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

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @wrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password.'**
  String get wrongPassword;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in. {detail}'**
  String signInFailed(Object detail);

  /// No description provided for @startFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the session.'**
  String get startFailed;

  /// No description provided for @noUsers.
  ///
  /// In en, this message translates to:
  /// **'No user accounts.'**
  String get noUsers;

  /// No description provided for @otherUser.
  ///
  /// In en, this message translates to:
  /// **'Choose another user'**
  String get otherUser;

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
}

class _GreeterLocalizationsDelegate
    extends LocalizationsDelegate<GreeterLocalizations> {
  const _GreeterLocalizationsDelegate();

  @override
  Future<GreeterLocalizations> load(Locale locale) {
    return SynchronousFuture<GreeterLocalizations>(
      lookupGreeterLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_GreeterLocalizationsDelegate old) => false;
}

GreeterLocalizations lookupGreeterLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return GreeterLocalizationsEn();
    case 'pt':
      return GreeterLocalizationsPt();
  }

  throw FlutterError(
    'GreeterLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
