import 'package:flutter/widgets.dart';

import 'settings_localizations.dart';

export 'settings_localizations.dart';

extension SettingsLocalizationsContext on BuildContext {
  SettingsLocalizations get l10n => SettingsLocalizations.of(this);
}
