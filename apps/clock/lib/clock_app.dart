// apps/clock/lib/clock_app.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:psito_sdk/psito_sdk.dart';

import 'l10n/clock_localizations.dart';

class ClockView extends StatefulWidget {
  /// Para notificar quando o timer termina; null em previews.
  final PsitoAppContext? appContext;

  const ClockView({super.key, this.appContext});

  static const timerDuration = Duration(seconds: 10);

  @override
  State<ClockView> createState() => _ClockViewState();
}

class _ClockViewState extends State<ClockView> {
  late Timer _timer;
  late DateTime _currentTime = _now();

  /// Hora no fuso do sistema; sem contexto (testes), a do processo.
  DateTime _now() => widget.appContext?.now() ?? DateTime.now();

  /// Segundos que faltam no timer; null quando parado.
  int? _remaining;
  Timer? _countdown;

  void _startTimer() {
    _countdown?.cancel();
    setState(() => _remaining = ClockView.timerDuration.inSeconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _remaining = _remaining! - 1);
      if (_remaining! > 0) return;
      timer.cancel();
      setState(() => _remaining = null);
      widget.appContext?.notify(
        PsitoNotification(
          title: ClockLocalizations.of(context).timerDone,
          body: ClockLocalizations.of(context).timerDoneBody,
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = _now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _countdown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = _currentTime.hour.toString().padLeft(2, '0');
    final minute = _currentTime.minute.toString().padLeft(2, '0');
    final second = _currentTime.second.toString().padLeft(2, '0');

    final l = ClockLocalizations.of(context);
    final date = DateFormat.yMMMMEEEEd(
      Localizations.localeOf(context).toString(),
    ).format(_currentTime);

    // Desenhado numa largura fixa e reduzido por inteiro em janelas pequenas
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 380,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone temático
                Icon(
                  Icons.access_time_filled_rounded,
                  size: 40,
                  color: context.palette.warning, // Laranja
                ),
                const SizedBox(height: 12),
                // Horário Grande
                Text(
                  '$hour:$minute:$second',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: context.palette.text,
                  ),
                ),
                const SizedBox(height: 8),
                // Data Completa
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.palette.textTertiary,
                  ),
                ),
                const SizedBox(height: 24),
                Divider(color: context.palette.line),
                const SizedBox(height: 12),
                // Timer de demonstração das notificações
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.palette.shadow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: context.palette.highlight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _remaining == null
                              ? l.timerIdle
                              : l.timerRemaining(_remaining!),
                          style: TextStyle(
                            color: context.palette.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _remaining == null ? _startTimer : null,
                        child: Text(l.timerStart),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ClockApp extends PsitoApp {
  const ClockApp();

  @override
  String get id => 'clock';

  @override
  String get name => 'Clock';

  @override
  String localizedName(Locale locale) =>
      lookupClockLocalizations(locale).appName;

  @override
  List<LocalizationsDelegate<dynamic>> get localizationsDelegates => const [
    ClockLocalizations.delegate,
  ];

  @override
  IconData get icon => Icons.access_time_rounded;

  @override
  Color get color => const Color(0xFFFF9800);

  @override
  Widget build(PsitoAppContext context) => ClockView(appContext: context);
}
