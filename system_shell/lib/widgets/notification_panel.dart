// system_shell/lib/widgets/notification_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shell/notification_center.dart';
import 'notification_toasts.dart';
import 'top_bar.dart';

import 'package:system_shell/l10n/l10n.dart';

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

  static String relativeTime(
    SystemLocalizations l,
    DateTime time,
    DateTime now,
  ) {
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return l.timeNow;
    if (diff.inHours < 1) return l.timeMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l.timeHoursAgo(diff.inHours);
    return l.timeDaysAgo(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            // Clicar fora fecha. A top bar fica de fora: clicar em outro
            // ícone dela troca de painel em vez de só fechar este
            Positioned.fill(
              top: TopBar.height,
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
                builder: (context, _) => _buildPanel(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
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
                  Expanded(
                    child: Text(
                      context.l10n.notifications,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: items.isEmpty ? null : center.clear,
                    child: Text(context.l10n.clearAll),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Text(
                  context.l10n.noNotifications,
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
                      timeLabel: relativeTime(context.l10n, items[i].time, now),
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
