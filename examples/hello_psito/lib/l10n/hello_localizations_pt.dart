// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'hello_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class HelloLocalizationsPt extends HelloLocalizations {
  HelloLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get connected => 'Conectado';

  @override
  String noConnection(Object error) {
    return 'Sem conexão: $error';
  }

  @override
  String get networkUnavailable => 'Rede indisponível para o app';

  @override
  String get networkConnected => 'Rede conectada';

  @override
  String get networkNone => 'Sem rede';

  @override
  String get networkLimited => 'Rede limitada';

  @override
  String get testing => 'Testando...';

  @override
  String get testConnection => 'Testar conexão';

  @override
  String get exitWithError => 'Sair com erro';
}
