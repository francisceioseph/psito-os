// system_shell/lib/apps/clock_app.dart
import 'dart:async';
import 'package:flutter/material.dart';

class ClockApp extends StatefulWidget {
  const ClockApp({super.key});

  @override
  State<ClockApp> createState() => _ClockAppState();
}

class _ClockAppState extends State<ClockApp> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = _currentTime.hour.toString().padLeft(2, '0');
    final minute = _currentTime.minute.toString().padLeft(2, '0');
    final second = _currentTime.second.toString().padLeft(2, '0');

    const weekdays = ['Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado'];
    const months = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];

    final weekDayStr = weekdays[_currentTime.weekday % 7];
    final day = _currentTime.day;
    final monthStr = months[_currentTime.month - 1];
    final year = _currentTime.year;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          // Status ou Alarme Simulado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Row(
                  children: [
                    Icon(Icons.alarm_rounded, size: 18, color: Color(0xFFFFC107)),
                    SizedBox(width: 8),
                    Text('Próximo alarme', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                Text('07:00 (Acordar os passarinhos)', style: TextStyle(color: Color(0xFFFFC107), fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}