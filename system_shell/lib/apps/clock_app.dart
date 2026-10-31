// system_shell/lib/apps/clock_app.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:psito_sdk/psito_sdk.dart';

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
  DateTime _currentTime = DateTime.now();

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
        const PsitoNotification(
          title: 'Timer concluído',
          body: '10 segundos se passaram.',
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
          _currentTime = DateTime.now();
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

    const weekdays = [
      'Domingo',
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
    ];
    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];

    final weekDayStr = weekdays[_currentTime.weekday % 7];
    final day = _currentTime.day;
    final monthStr = months[_currentTime.month - 1];
    final year = _currentTime.year;

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
                const Icon(
                  Icons.access_time_filled_rounded,
                  size: 40,
                  color: Color(0xFFFF9800), // Laranja
                ),
                const SizedBox(height: 12),
                // Horário Grande
                Text(
                  '$hour:$minute:$second',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                // Data Completa
                Text(
                  '$weekDayStr, $day de $monthStr de $year',
                  style: const TextStyle(fontSize: 14, color: Colors.white60),
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),
                // Timer de demonstração das notificações
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: Color(0xFFFFC107),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _remaining == null
                              ? 'Timer de 10 s'
                              : 'Faltam $_remaining s',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _remaining == null ? _startTimer : null,
                        child: const Text('Iniciar timer'),
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
  IconData get icon => Icons.access_time_rounded;

  @override
  Color get color => const Color(0xFFFF9800);

  @override
  Widget build(PsitoAppContext context) => ClockView(appContext: context);
}
