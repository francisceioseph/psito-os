import 'package:flutter/material.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  /// Botão do Menu Psito: abre e fecha o launcher.
  final VoidCallback? onMenuTap;

  const TopBar({super.key, this.onMenuTap});

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.black.withValues(alpha: 0.65),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Lado Esquerdo: Espaço reservado para janelas ativas ou app launcher futuro
          Row(
            children: [
              const SizedBox(width: 4),

              // Menu Psito (Botão do Passarinho à Direita)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onMenuTap,
                  borderRadius: BorderRadius.circular(6),
                  hoverColor: Colors.white12,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flutter_dash,
                          size: 20,
                          color: Color(0xFFFFC107), // Amarelo Calopsita
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Menu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFC107),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Lado Direito: Status do Sistema, Menu Psito e Data/Hora (Estilo Cinnamon)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicadores de Periféricos / Status
              _buildSystemTrayIcon(Icons.bluetooth, 'Bluetooth Ativo'),
              const SizedBox(width: 12),
              _buildSystemTrayIcon(Icons.wifi, 'Conectado à Rede'),
              const SizedBox(width: 12),
              _buildSystemTrayIcon(Icons.volume_up, 'Volume: 100%'),
              const SizedBox(width: 12),

              // Indicador de Bateria / Energia do Psito Device
              Row(
                children: const [
                  Icon(
                    Icons.battery_charging_full,
                    size: 16,
                    color: Color(0xFFFFC107),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '100%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('|', style: TextStyle(color: Colors.white24)),
              ),

              // Relógio / Data completa estilo Cinnamon
              StreamBuilder<DateTime>(
                stream: Stream.periodic(
                  const Duration(seconds: 1),
                  (_) => DateTime.now(),
                ),
                builder: (context, snapshot) {
                  final now = snapshot.data ?? DateTime.now();

                  // Formatação amigável da data em português (ex: Sáb, 12 de set, 16:41)
                  final formattedDateTime = _formatCinnamonDate(now);

                  return Text(
                    formattedDateTime,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemTrayIcon(IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 16, color: Colors.white70),
    );
  }

  String _formatCinnamonDate(DateTime dt) {
    const weekdays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    const months = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];

    final weekDay = weekdays[dt.weekday % 7];
    final day = dt.day;
    final month = months[dt.month - 1];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$weekDay, $day de $month, $hour:$minute';
  }
}
