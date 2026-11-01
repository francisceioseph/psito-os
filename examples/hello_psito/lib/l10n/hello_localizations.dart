import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'hello_localizations_en.dart';
import 'hello_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of HelloLocalizations
/// returned by `HelloLocalizations.of(context)`.
///
/// Applications need to include `HelloLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/hello_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: HelloLocalizations.localizationsDelegates,
///   supportedLocales: HelloLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the HelloLocalizations.supportedLocales
/// property.
abstract class HelloLocalizations {
  HelloLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static HelloLocalizations of(BuildContext context) {
    return Localizations.of<HelloLocalizations>(context, HelloLocalizations)!;
  }

  static const LocalizationsDelegate<HelloLocalizations> delegate =
      _HelloLocalizationsDelegate();

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

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection: {error}'**
  String noConnection(Object error);

  /// No description provided for @networkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Network unavailable to the app'**
  String get networkUnavailable;

  /// No description provided for @networkConnected.
  ///
  /// In en, this message translates to:
  /// **'Network connected'**
  String get networkConnected;

  /// No description provided for @networkNone.
  ///
  /// In en, this message translates to:
  /// **'No network'**
  String get networkNone;

  /// No description provided for @networkLimited.
  ///
  /// In en, this message translates to:
  /// **'Limited network'**
  String get networkLimited;

  /// No description provided for @testing.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get testing;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @exitWithError.
  ///
  /// In en, this message translates to:
  /// **'Exit with error'**
  String get exitWithError;
}

class _HelloLocalizationsDelegate
    extends LocalizationsDelegate<HelloLocalizations> {
  const _HelloLocalizationsDelegate();

  @override
  Future<HelloLocalizations> load(Locale locale) {
    return SynchronousFuture<HelloLocalizations>(
      lookupHelloLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_HelloLocalizationsDelegate old) => false;
}

HelloLocalizations lookupHelloLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return HelloLocalizationsEn();
    case 'pt':
      return HelloLocalizationsPt();
  }

  throw FlutterError(
    'HelloLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
