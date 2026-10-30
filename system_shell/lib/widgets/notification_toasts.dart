// system_shell/lib/widgets/notification_toasts.dart
import 'package:flutter/material.dart';

import '../shell/notification_center.dart';

/// Toasts no canto superior direito, mais novo em cima.
class NotificationToasts extends StatelessWidget {
  final NotificationCenter center;

  /// Clique no toast (ex.: focar a janela que notificou).
  final void Function(ShellNotification notification) onTap;

  const NotificationToasts({
    super.key,
    required this.center,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: center,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final n in center.toasts)
            Padding(
              key: ValueKey('toast-${n.id}'),
              padding: const EdgeInsets.only(bottom: 8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(24 * (1 - t), 0),
                    child: child,
                  ),
                ),
                child: _Toast(
                  notification: n,
                  onTap: () {
                    center.dismissToast(n.id);
                    onTap(n);
                  },
                  onClose: () => center.dismissToast(n.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  final ShellNotification notification;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _Toast({
    required this.notification,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 320,
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E252B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: n.color.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: NotificationTile(notification: n, onClose: onClose),
      ),
    );
  }
}

/// Conteúdo de uma notificação, usado no toast e no painel.
class NotificationTile extends StatelessWidget {
  final ShellNotification notification;
  final VoidCallback onClose;
  final String? timeLabel;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onClose,
    this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: n.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(n.icon, size: 18, color: n.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeLabel == null ? n.appName : '${n.appName} · $timeLabel',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 2),
              Text(
                n.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (n.body case final body?)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16),
          tooltip: 'Dispensar',
          onPressed: onClose,
          color: Colors.white54,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
