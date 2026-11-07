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
    final isAdminOrCo =
        user?.role == UserRole.admin || user?.role == UserRole.coAdmin;
    final houses = ref.watch(boilerHouseListProvider);
    final emergencies = _countStatus(
      houses,
      BoilerHouseStatus.emergencyShutdown,
    );
    final operating = _countStatus(houses, BoilerHouseStatus.operating);

    return GlassScaffold(
      tab: AppTab.home,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, kBottomNavSpace),
          children: [
            _HomeHeader(
              user: user,
              date: _formatDateUz(DateTime.now(), l.isCyrl),
              welcome: l.homeWelcome,
              fallbackTitle: l.homeTitle,
              isAdmin: isAdminOrCo,
              unread: unread,
            ),
            const SizedBox(height: 20),
            _OperationsOverview(
              total: houses.length,
              operating: operating,
              emergencies: emergencies,
              title: l.homeOverview,
              totalLabel: l.navBoilerhouses,
              operatingLabel: l.statusOperating,
              emergencyLabel: l.statEmergency,
            ),
            if (emergencies > 0) ...[
              const SizedBox(height: 12),
              _EmergencyNotice(
                count: emergencies,
                label: l.statusEmergency,
                onTap: () => context.push('/boilerhouses'),
              ),
            ],
            const SizedBox(height: 24),
            _SectionHeading(title: l.homeOperationalState),
            const SizedBox(height: 12),
            _StatusOverview(
              houses: houses,
              title: l.boilerhousesTitle,
              labels: BoilerHouseStatus.values
                  .map((status) => status.label(l))
                  .toList(),
            ),
            const SizedBox(height: 24),
            _SectionHeading(title: l.homeQuickActions),
            const SizedBox(height: 12),
            ResponsiveWrap(
              minChildWidth: 125,
              children: [
                _QuickAction(
                  label: l.boilerhousesTitle,
                  icon: Icons.factory_rounded,
                  color: AppTheme.primary,
                  onTap: () => context.push('/boilerhouses'),
                ),
                _QuickAction(
                  label: l.navJournal,
                  icon: Icons.edit_note_rounded,
                  color: AppTheme.accent,
                  onTap: () => context.push('/journal'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _SectionHeading(title: l.homeSections, subtitle: l.homeSubtitle),
            const SizedBox(height: 12),
            _SectionMenu(
              title: l.homeOperations,
              entries: [
                _MenuEntry(
                  l.boilerhousesTitle,
                  Icons.factory_outlined,
                  AppTheme.primary,
                  '/boilerhouses',
                ),
                _MenuEntry(
                  l.navJournal,
                  Icons.menu_book_rounded,
                  AppTheme.accent,
                  '/journal',
                ),
                _MenuEntry(
                  l.shiftsTitle,
                  Icons.schedule_rounded,
                  AppTheme.success,
                  '/shifts',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionMenu(
              title: l.homeResources,
              entries: [
                _MenuEntry(
                  l.navInstructions,
                  Icons.description_outlined,
                  AppTheme.warning,
                  '/instructions',
                ),
                _MenuEntry(
                  l.navDrawings,
                  Icons.architecture_rounded,
                  AppTheme.primary,
                  '/drawings',
                ),
                _MenuEntry(
                  l.analyticsTitle,
                  Icons.insights_rounded,
                  AppTheme.success,
                  '/analytics',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionMenu(
              title: l.homeTeam,
              entries: [
                _MenuEntry(
                  l.navWorkers,
                  Icons.groups_outlined,
                  AppTheme.accent,
                  '/workers',
                ),
                _MenuEntry(
                  l.navNotifications,
                  Icons.notifications_outlined,
                  AppTheme.error,
                  '/notifications',
                  badge: unread > 0 ? '$unread' : null,
                ),
                _MenuEntry(
                  l.navProfile,
                  Icons.person_outline_rounded,
                  AppTheme.primary,
                  '/profile',
                ),
                _MenuEntry(
                  l.aboutTitle,
                  Icons.info_outline_rounded,
                  AppTheme.inkFaint,
                  '/about',
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

int _countStatus(List<BoilerHouse> houses, BoilerHouseStatus status) =>
    houses.where((house) => house.status == status).length;

String _formatDateUz(DateTime date, bool isCyrl) {
  const monthsCyrl = [
    'январ',
    'феврал',
    'март',
    'апрел',
    'май',
    'июн',
    'июл',
    'август',
    'сентябр',
    'октябр',
    'ноябр',
    'декабр',
  ];
  const monthsLatin = [
    'yanvar',
    'fevral',
    'mart',
    'aprel',
    'may',
    'iyun',
    'iyul',
    'avgust',
    'sentabr',
    'oktabr',
    'noyabr',
    'dekabr',
  ];
  const daysCyrl = [
    'душанба',
    'сешанба',
    'чоршанба',
    'пайшанба',
    'жума',
    'шанба',
    'якшанба',
  ];
  const daysLatin = [
    'dushanba',
    'seshanba',
    'chorshanba',
    'payshanba',
    'juma',
    'shanba',
    'yakshanba',
  ];
  final months = isCyrl ? monthsCyrl : monthsLatin;
  final days = isCyrl ? daysCyrl : daysLatin;
  return '${date.day} ${months[date.month - 1]}, ${days[date.weekday - 1]}';
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.user,
    required this.date,
    required this.welcome,
    required this.fallbackTitle,
    required this.isAdmin,
    required this.unread,
  });

  final AppUser? user;
  final String date;
  final String welcome;
  final String fallbackTitle;
  final bool isAdmin;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final initials = user?.initials ?? '?';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppTheme.accent, AppTheme.primary],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFFF4F6FD),
            child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                welcome,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                user?.firstName ?? fallbackTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 19,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
        if (isAdmin)
          _HeaderAction(
            icon: Icons.admin_panel_settings_outlined,
            onTap: () => context.push('/admin'),
          ),
        const SizedBox(width: 6),
        _HeaderAction(
          icon: Icons.notifications_none_rounded,
          badge: unread > 0 ? '$unread' : null,
          onTap: () => context.push('/notifications'),
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.onTap, this.badge});

  final IconData icon;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.72),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: AppTheme.ink, size: 21),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OperationsOverview extends StatelessWidget {
  const _OperationsOverview({
    required this.total,
    required this.operating,
    required this.emergencies,
    required this.title,
    required this.totalLabel,
    required this.operatingLabel,
    required this.emergencyLabel,
  });

  final int total;
  final int operating;
  final int emergencies;
  final String title;
  final String totalLabel;
  final String operatingLabel;
  final String emergencyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF394BC5), Color(0xFF5668E1), Color(0xFF397ABF)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -48,
            right: -20,
            child: _GlowCircle(size: 170, opacity: 0.12),
          ),
          Positioned(
            bottom: -76,
            right: 74,
            child: _GlowCircle(size: 150, opacity: 0.08),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 19, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.space_dashboard_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.auto_graph_rounded,
                      color: Color(0xFFB9F1FF),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ResponsiveWrap(
                  minChildWidth: 72,
                  maxColumns: 3,
                  spacing: 1,
                  children: [
                    _HeroMetric(
                      value: '$total',
                      label: totalLabel,
                      icon: Icons.factory_outlined,
                    ),
                    _HeroMetric(
                      value: '$operating',
                      label: operatingLabel,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    _HeroMetric(
                      value: '$emergencies',
                      label: emergencyLabel,
                      icon: Icons.warning_amber_rounded,
                      highlight: emergencies > 0,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
          border: Border.all(
            color: Colors.white.withValues(alpha: opacity * 0.8),
          ),
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFFD6F7FF)),
              const SizedBox(width: 5),
              Flexible(child: Text(
                value,
                style: TextStyle(
                  color: highlight ? const Color(0xFFFFD3C8) : Colors.white,
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              )),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 10,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyNotice extends StatelessWidget {
  const _EmergencyNotice({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: AppTheme.error,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      onTap: onTap,
      child: Row(
        children: [
          const GlassIconTile(
            icon: Icons.warning_amber_rounded,
            color: AppTheme.error,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$label · $count',
              style: const TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 15,
            color: AppTheme.error,
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 17,
                  letterSpacing: -0.25,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(
              colors: [AppTheme.accent, AppTheme.primary],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusOverview extends StatelessWidget {
  const _StatusOverview({
    required this.houses,
    required this.title,
    required this.labels,
  });

  final List<BoilerHouse> houses;
  final String title;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final statuses = BoilerHouseStatus.values.indexed
        .map(
          (entry) => (
            status: entry.$2,
            label: labels[entry.$1],
            count: _countStatus(houses, entry.$2),
          ),
        )
        .toList();
    final total = houses.length;

    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.donut_small_rounded,
                color: AppTheme.primary,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
              const SizedBox(width: 8),
              Text(
                '$total',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Row(
                children: statuses.map((entry) {
                  final flex = entry.count == 0 ? 0 : entry.count;
                  if (flex == 0) return const SizedBox.shrink();
                  return Expanded(
                    flex: flex,
                    child: ColoredBox(color: entry.status.color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statuses
                .map(
                  (entry) => _StatusPill(
                    label: entry.label,
                    count: entry.count,
                    color: entry.status.color,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.inkSoft,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      radius: 22,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassIconTile(icon: icon, color: color, size: 42),
              const Spacer(),
              Icon(Icons.arrow_forward_rounded, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuEntry {
  const _MenuEntry(this.title, this.icon, this.color, this.route, {this.badge});

  final String title;
  final IconData icon;
  final Color color;
  final String route;
  final String? badge;
}

class _SectionMenu extends StatelessWidget {
  const _SectionMenu({required this.title, required this.entries});

  final String title;
  final List<_MenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.inkSoft,
              fontSize: 12,
            ),
          ),
        ),
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                _MenuRow(entry: entries[i]),
                if (i < entries.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 66, right: 16),
                    child: Divider(
                      height: 1,
                      color: AppTheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.entry});

  final _MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(entry.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              GlassIconTile(icon: entry.icon, color: entry.color, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (entry.badge != null)
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    entry.badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.inkFaint,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
