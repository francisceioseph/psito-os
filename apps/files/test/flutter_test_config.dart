import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Os testes conferem os textos em português.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized()
      .platformDispatcher
      .localesTestValue = const [
    Locale('pt'),
  ];
  await initializeDateFormatting('pt');
  await testMain();
}
