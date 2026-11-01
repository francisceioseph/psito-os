// system_shell/lib/widgets/hot_corner.dart
//
// O canto da tela que faz uma ação com o ponteiro parado nele por um instante:
// passar por ali a caminho do botão de desligar não dispara.
import 'dart:async';

import 'package:flutter/widgets.dart';

class HotCorner extends StatefulWidget {
  final VoidCallback onTrigger;

  /// O lado do quadrado sensível.
  static const size = 4.0;
  static const dwell = Duration(milliseconds: 150);

  const HotCorner({super.key, required this.onTrigger});

  @override
  State<HotCorner> createState() => _HotCornerState();
}

class _HotCornerState extends State<HotCorner> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Translúcido: o clique continua indo para o que está embaixo
  @override
  Widget build(BuildContext context) => MouseRegion(
    hitTestBehavior: HitTestBehavior.translucent,
    onEnter: (_) => _timer = Timer(HotCorner.dwell, widget.onTrigger),
    onExit: (_) => _timer?.cancel(),
    child: const SizedBox.square(dimension: HotCorner.size),
  );
}
