import 'package:flutter/widgets.dart';

import 'files_localizations.dart';

export 'files_localizations.dart';

extension FilesLocalizationsContext on BuildContext {
  FilesLocalizations get l10n => FilesLocalizations.of(this);
}
