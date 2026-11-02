// examples/player/lib/l10n/l10n.dart
import 'package:flutter/widgets.dart';

import 'player_localizations.dart';

extension PlayerL10n on BuildContext {
  PlayerLocalizations get l10n => PlayerLocalizations.of(this);
}
