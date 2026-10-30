import 'package:flutter/material.dart';

class DesktopBackground extends StatelessWidget {
  const DesktopBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: () {
              debugPrint('🦜 O Psito foi clicado!');
            },
            borderRadius: BorderRadius.circular(16),
            hoverColor: Colors.white12,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Icon(
                Icons.flutter_dash,
                size: 120,
                color: Color(0xFFFFC107),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Psito OS v0.0.1',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'O Sistema Operacional Penoso',
            style: TextStyle(fontSize: 16, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
