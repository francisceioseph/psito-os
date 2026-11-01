import 'package:flutter/widgets.dart';

import 'system_localizations.dart';

export 'system_localizations.dart';

extension SystemLocalizationsContext on BuildContext {
  SystemLocalizations get l10n => SystemLocalizations.of(this);
}
