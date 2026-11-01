// examples/hello_psito/lib/hello_app.dart
//
// Um app de terceiro: fora de apps/, empacotado sozinho (tools/psito-deb) e
// instalado com o apt, sem recompilar o shell. Mostra a permissão network
// (o estado da rede e uma conexão de verdade) e serve aos testes de
// robustez da fase 4 (sair com erro).
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'l10n/hello_localizations.dart';

/// Abre uma conexão TCP com o espelho do Debian. Devolve null se conectou,
/// ou o erro. Sem a permissão network, o sandbox não tem rede e falha.
Future<String?> probeInternet() async {
  try {
    final socket = await Socket.connect(
      'deb.debian.org',
      80,
      timeout: const Duration(seconds: 3),
    );
    socket.destroy();
    return null;
  } on SocketException catch (e) {
    return e.osError?.message ?? e.message;
  }
}

class HelloView extends StatefulWidget {
  final ValueListenable<PsitoNetworkState> network;
  final Future<String?> Function() probe;
  final VoidCallback onCrash;

  const HelloView({
    super.key,
    required this.network,
    this.probe = probeInternet,
    required this.onCrash,
  });

  @override
  State<HelloView> createState() => _HelloViewState();
}

class _HelloViewState extends State<HelloView> {
  bool _testing = false;
  String? _result;

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    final error = await widget.probe();
    if (!mounted) return;
    final l = HelloLocalizations.of(context);
    setState(() {
      _testing = false;
      _result = error == null ? l.connected : l.noConnection(error);
    });
  }

  static String networkLabel(HelloLocalizations l, PsitoNetworkState s) {
    if (!s.available) return l.networkUnavailable;
    return switch (s.connectivity) {
      PsitoConnectivity.full => l.networkConnected,
      PsitoConnectivity.none => l.networkNone,
      _ => l.networkLimited,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = HelloLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hello, Psito', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            ValueListenableBuilder(
              valueListenable: widget.network,
              builder: (_, s, _) =>
                  Text(networkLabel(l, s), style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: _testing ? null : _test,
                  child: Text(_testing ? l.testing : l.testConnection),
                ),
                OutlinedButton(
                  onPressed: widget.onCrash,
                  child: Text(l.exitWithError),
                ),
              ],
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              Text(
                _result!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HelloApp extends PsitoApp {
  const HelloApp();

  @override
  String get id => 'hello_psito';

  @override
  String get name => 'Hello Psito';

  @override
  List<LocalizationsDelegate<dynamic>> get localizationsDelegates => const [
    HelloLocalizations.delegate,
  ];

  @override
  IconData get icon => Icons.waving_hand_rounded;

  @override
  Color get color => const Color(0xFF9C27B0);

  @override
  Size get defaultSize => const Size(360, 240);

  @override
  Widget build(PsitoAppContext context) =>
      HelloView(network: context.network, onCrash: () => exit(1));
}
