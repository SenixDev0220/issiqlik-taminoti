import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../domain/models/app_user.dart';
import '../auth/auth_providers.dart';

class WorkersScreen extends ConsumerWidget {
  const WorkersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final users = ref.watch(activeUsersProvider);

    // Sort by role hierarchy: admin → coAdmin → member
    final sorted = List<AppUser>.from(users)
      ..sort((a, b) => _roleOrder(a.role).compareTo(_roleOrder(b.role)));

    return GlassScaffold(
      title: l.workersTitle,
      leading: BackButton(onPressed: () => context.go('/home')),
      body: sorted.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: sorted.length,
              scrollCacheExtent: ScrollCacheExtent.pixels(300),
              addAutomaticKeepAlives: false,
              itemBuilder: (context, index) {
                final user = sorted[index];
                return RepaintBoundary(child: _WorkerCard(user: user, rank: index + 1, l: l));
              },
            ),
    );
  }

  int _roleOrder(UserRole r) {
    switch (r) {
      case UserRole.admin: return 0;
      case UserRole.coAdmin: return 1;
      case UserRole.member: return 2;
    }
  }
}

class _WorkerCard extends StatelessWidget {
  final AppUser user;
  final int rank;
  final dynamic l;

  const _WorkerCard({required this.user, required this.rank, required this.l});

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(user.role);
    final roleLabel = _roleLabel(user.role, l);
    final positionText = user.position.isNotEmpty ? user.position : roleLabel;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: roleColor.withValues(alpha: 0.18)),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: roleColor),
              ),
            ),
          ),
          const SizedBox(width: 12),

          CircleAvatar(
            radius: 24,
            backgroundColor: roleColor.withValues(alpha: 0.14),
            backgroundImage: user.photoUrl.isNotEmpty
                ? ResizeImage(
                    NetworkImage(user.photoUrl),
                    width: (48 * MediaQuery.devicePixelRatioOf(context)).round(),
                    height: (48 * MediaQuery.devicePixelRatioOf(context)).round(),
                  )
                : null,
            child: user.photoUrl.isEmpty
                ? Text(user.initials, style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 14))
                : null,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  positionText,
                  style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          StatusChip(label: roleLabel, color: roleColor),
        ],
      ),
    );
  }

  Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.admin: return AppTheme.error;
      case UserRole.coAdmin: return AppTheme.primary;
      case UserRole.member: return AppTheme.accent;
    }
  }

  String _roleLabel(UserRole r, dynamic l) {
    switch (r) {
      case UserRole.admin: return l.roleAdmin;
      case UserRole.coAdmin: return l.roleCoAdmin;
      case UserRole.member: return l.roleMember;
    }
  }
}
