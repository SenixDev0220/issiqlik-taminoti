import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/boiler_house.dart';
import '../auth/auth_providers.dart';
import '../boilerhouse/boilerhouse_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final user = ref.watch(currentUserProvider);
    final unread = user != null ? ref.watch(unreadCountProvider(user.id)) : 0;
    final isAdminOrCo = user?.role == UserRole.admin || user?.role == UserRole.coAdmin;
    final houses = ref.watch(boilerHouseListProvider);
    final emergencies = houses.where((h) => h.status == BoilerHouseStatus.emergencyShutdown).length;

    return GlassScaffold(
      tab: AppTab.home,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, kBottomNavSpace),
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.14),
                        backgroundImage: user != null && user.photoUrl.isNotEmpty
                            ? ResizeImage(
                                NetworkImage(user.photoUrl),
                                width: (48 * MediaQuery.devicePixelRatioOf(context)).round(),
                                height: (48 * MediaQuery.devicePixelRatioOf(context)).round(),
                              )
                            : null,
                        child: user == null || user.photoUrl.isEmpty
                            ? Text(
                                user?.initials ?? '?',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.homeWelcome,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.inkSoft),
                            ),
                            if (user != null) ...[
                              const SizedBox(height: 1),
                              Text(
                                user.firstName,
                                style: Theme.of(context).textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 1),
                            Text(
                              '${_formatDateUz(DateTime.now())}${user != null ? '  •  ${_roleLabel(user.role, l)}' : ''}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.inkFaint),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isAdminOrCo)
                        IconButton(
                          icon: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.ink),
                          onPressed: () => context.push('/admin'),
                        ),
                      _BellButton(unread: unread, onTap: () => context.push('/notifications')),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Overall state ──
                  GlassCard(
                    child: Row(
                      children: [
                        Expanded(child: _Stat(label: l.navBoilerhouses, value: '${houses.length}', color: AppTheme.primary)),
                        Container(width: 1, height: 44, color: AppTheme.primary.withValues(alpha: 0.12)),
                        Expanded(child: _Stat(label: l.statEmergency, value: '$emergencies', color: AppTheme.error)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Shortcuts grid ──
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      _ShortcutTile(title: l.navBoilerhouses, icon: Icons.local_fire_department_outlined, color: AppTheme.primary, route: '/boilerhouses'),
                      _ShortcutTile(title: l.navJournal, icon: Icons.assignment_outlined, color: AppTheme.accent, route: '/journal'),
                      _ShortcutTile(title: l.navInstructions, icon: Icons.menu_book_outlined, color: AppTheme.success, route: '/instructions'),
                      _ShortcutTile(title: l.navDrawings, icon: Icons.architecture_outlined, color: AppTheme.warning, route: '/drawings'),
                      _ShortcutTile(title: l.navNotifications, icon: Icons.notifications_outlined, color: AppTheme.error, route: '/notifications', badge: unread > 0 ? '$unread' : null),
                      _ShortcutTile(title: l.navWorkers, icon: Icons.groups_outlined, color: AppTheme.accent, route: '/workers'),
                      _ShortcutTile(title: l.shiftsTitle, icon: Icons.schedule_outlined, color: AppTheme.primary, route: '/shifts'),
                      _ShortcutTile(title: l.analyticsTitle, icon: Icons.insights_outlined, color: AppTheme.success, route: '/analytics'),
                      _ShortcutTile(title: l.navProfile, icon: Icons.person_outline, color: AppTheme.primary, route: '/profile'),
                      _ShortcutTile(title: l.aboutTitle, icon: Icons.info_outline, color: AppTheme.inkFaint, route: '/about'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _roleLabel(UserRole role, dynamic l) {
  switch (role) {
    case UserRole.admin: return l.roleAdmin;
    case UserRole.coAdmin: return l.roleCoAdmin;
    case UserRole.member: return l.roleMember;
  }
}

String _formatDateUz(DateTime d) {
  const months = ['январ', 'феврал', 'март', 'апрел', 'май', 'июн', 'июл', 'август', 'сентябр', 'октябр', 'ноябр', 'декабр'];
  const days = ['душанба', 'сешанба', 'чоршанба', 'пайшанба', 'жума', 'шанба', 'якшанба'];
  return '${d.day} ${months[d.month - 1]}, ${days[d.weekday - 1]}';
}

class _BellButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;
  const _BellButton({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.ink),
          onPressed: onTap,
        ),
        if (unread > 0)
          Positioned(
            right: 4,
            top: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: color)),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.inkSoft),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ]);
  }
}

class _ShortcutTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  final String? badge;

  const _ShortcutTile({required this.title, required this.icon, required this.color, required this.route, this.badge});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GlassCard(
        onTap: () => context.push(route),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                GlassIconTile(icon: icon, color: color),
                if (badge != null)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
