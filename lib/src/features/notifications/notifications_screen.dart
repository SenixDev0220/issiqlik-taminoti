import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../core/l10n.dart';
import '../../domain/models/notification_model.dart';
import '../auth/auth_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final l = ref.watch(l10nProvider);

    if (user == null) {
      return GlassScaffold(
        title: l.notificationsTitle,
        leading: BackButton(onPressed: () => context.go('/home')),
        body: Center(child: Text(l.notificationsEmpty)),
      );
    }

    final notifications = ref.watch(notificationsStreamProvider(user.id)).valueOrNull ?? [];
    final hasUnread = notifications.any((n) => !n.isRead);
    final actions = ref.read(notificationsNotifierProvider(user.id));

    return GlassScaffold(
      title: l.notificationsTitle,
      leading: BackButton(onPressed: () => context.go('/home')),
      actions: [
        if (hasUnread)
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: AppTheme.primary),
            tooltip: l.notificationsMarkAllRead,
            onPressed: () => actions.markAllRead(user.id),
          ),
      ],
      body: notifications.isEmpty
          ? Center(child: Text(l.notificationsEmpty, style: const TextStyle(color: AppTheme.inkSoft)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: notifications.length,
              addAutomaticKeepAlives: false,
              itemBuilder: (context, index) {
                final n = notifications[index];
                return RepaintBoundary(
                  child: _NotifCard(
                    notif: n,
                    l: l,
                    onTap: () => actions.markRead(n.id),
                  ),
                );
              },
            ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final AppL10n l;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.l, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      tint: notif.isRead ? null : AppTheme.primary,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassIconTile(icon: _typeIcon(notif.type), color: _typeColor(notif.type)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notif.message,
                  style: textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _timeAgo(notif.sentAt, l),
                style: textTheme.bodySmall?.copyWith(color: AppTheme.inkFaint),
              ),
              if (!notif.isRead) ...[
                const SizedBox(height: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt, AppL10n l) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l.timeJustNow;
    if (diff.inHours < 1) return l.timeMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l.timeHoursAgo(diff.inHours);
    return l.timeDaysAgo(diff.inDays);
  }

  IconData _typeIcon(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.emergency: return Icons.emergency;
      case AppNotificationType.important: return Icons.notifications_active;
      case AppNotificationType.informational: return Icons.info_outline;
      case AppNotificationType.system: return Icons.settings;
    }
  }

  Color _typeColor(AppNotificationType t) {
    switch (t) {
      case AppNotificationType.emergency: return AppTheme.error;
      case AppNotificationType.important: return AppTheme.warning;
      case AppNotificationType.informational: return AppTheme.accent;
      case AppNotificationType.system: return AppTheme.primary;
    }
  }
}
