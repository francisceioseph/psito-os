// system_shell/lib/widgets/notification_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shell/notification_center.dart';
import 'notification_toasts.dart';

/// Painel de notificações abaixo da top bar, à direita.
class NotificationPanel extends StatelessWidget {
  final NotificationCenter center;
  final VoidCallback onClose;

  /// Clique numa notificação (ex.: focar a janela que notificou).
  final void Function(ShellNotification notification) onTap;

  const NotificationPanel({
    super.key,
    required this.center,
    required this.onClose,
    required this.onTap,
  });

  static String relativeTime(DateTime time, DateTime now) {
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inHours < 1) return 'há ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'há ${diff.inHours} h';
    return 'há ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            // Clicar fora fecha
            Positioned.fill(
              child: GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
              ),
            ),
            Positioned(
              top: 48,
              right: 12,
              width: 360,
              child: ListenableBuilder(
                listenable: center,
                builder: (context, _) => _buildPanel(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    final now = DateTime.now();
    final items = center.history;

    return Container(
      constraints: const BoxConstraints(maxHeight: 480),
      decoration: BoxDecoration(
        color: const Color(0xFF1E252B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      // Material transparente: o hover dos itens pinta dentro do painel
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notificações',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: items.isEmpty ? null : center.clear,
                    child: const Text('Limpar tudo'),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Text(
                  'Nenhuma notificação',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(14, 4, 6, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: Colors.white12, height: 16),
                  itemBuilder: (context, i) => InkWell(
                    key: ValueKey('panel-${items[i].id}'),
                    borderRadius: BorderRadius.circular(10),
                    hoverColor: Colors.white10,
                    onTap: () => onTap(items[i]),
                    child: NotificationTile(
                      notification: items[i],
                      timeLabel: relativeTime(items[i].time, now),
                      onClose: () => center.dismiss(items[i].id),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
