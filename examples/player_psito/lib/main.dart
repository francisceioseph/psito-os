// examples/player_psito/lib/main.dart
import 'package:psito_runtime/psito_runtime.dart';

import 'player_app.dart';

Future<void> main(List<String> args) =>
    runPsitoApp(const PlayerApp(), args: args);
