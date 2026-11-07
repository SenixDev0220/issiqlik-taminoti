part of 'admin_panel_screen.dart';

class _PendingTab extends ConsumerWidget {
  const _PendingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingUsersProvider);
    final l = ref.watch(l10nProvider);
    final isAdmin = _isAdmin(ref.watch(currentUserProvider));
    if (pending.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success),
        const SizedBox(height: 12),
        Text(l.adminNoPending, style: Theme.of(context).textTheme.bodyLarge),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final user = pending[index];
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _InitialsAvatar(initials: user.initials, color: AppTheme.warning),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.fullName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('${user.login} • ${user.phone}', style: Theme.of(context).textTheme.bodySmall),
              ])),
              if (!isAdmin) const Icon(Icons.hourglass_top, color: AppTheme.warning),
            ]),
            if (isAdmin) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(l.adminApprove),
                  onPressed: () => runUiAction(context, ref, () => _fb.approveUser(user.id)),
                )),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(l.adminDecline),
                  onPressed: () => runUiAction(context, ref, () => _fb.declineUser(user.id)),
                )),
              ]),
            ],
          ]),
        );
      },
    );
  }
}

class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final users = ref.watch(userStoreProvider).where((user) => user.status != UserStatus.pending).toList();
    final l = ref.watch(l10nProvider);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isBlocked = user.status == UserStatus.blocked;
        final canManage = _isAdmin(currentUser) && currentUser!.id != user.id && user.role != UserRole.admin;
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 10),
          tint: isBlocked ? AppTheme.error : null,
          child: Row(children: [
            _InitialsAvatar(initials: user.initials, color: isBlocked ? AppTheme.inkFaint : _roleColor(user.role)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.fullName, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                decoration: isBlocked ? TextDecoration.lineThrough : null,
              )),
              const SizedBox(height: 2),
              Text('${user.login} • ${user.phone}', style: Theme.of(context).textTheme.bodySmall),
            ])),
            const SizedBox(width: 8),
            if (canManage)
              PopupMenuButton<String>(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                itemBuilder: (_) => [
                  if (!isBlocked) ...[
                    PopupMenuItem(value: 'houses', child: Text(l.navBoilerhouses)),
                    PopupMenuItem(value: 'role', child: Text(l.adminChangeRole)),
                    PopupMenuItem(value: 'resetpw', child: Text(l.resetPassword)),
                    PopupMenuItem(value: 'ban', child: Text(l.ban)),
                  ] else
                    PopupMenuItem(value: 'unban', child: Text(l.unban)),
                ],
                onSelected: (value) {
                  if (!_isAdmin(ref.read(currentUserProvider))) return;
                  if (value == 'houses') _showHousePicker(context, user);
                  if (value == 'role') _showRolePicker(context, user);
                  if (value == 'resetpw') _showResetPassword(context, user, l);
                  if (value == 'ban') runUiAction(context, ref, () => _fb.banUser(user.id));
                  if (value == 'unban') runUiAction(context, ref, () => _fb.unbanUser(user.id));
                },
              )
            else
              Flexible(child: StatusChip(
                label: isBlocked ? l.userBlocked : _roleLabel(user.role, l),
                color: isBlocked ? AppTheme.error : _roleColor(user.role),
              )),
          ]),
        );
      },
    );
  }

  void _showHousePicker(BuildContext context, AppUser user) {
    final selected = user.boilerhouseIds.toSet();
    showDialog<void>(context: context, builder: (dialogContext) => Consumer(
      builder: (context, ref, _) => StatefulBuilder(builder: (context, update) {
        final houses = ref.watch(boilerHouseListProvider);
        final l = ref.watch(l10nProvider);
        final activeIds = houses.map((house) => house.id).toSet();
        final unavailable = selected.difference(activeIds).toList();
        return AlertDialog(
          title: Text('${l.navBoilerhouses} (${selected.length}/30)'),
          content: SizedBox(width: 480, height: 360, child: ListView(children: [
            if (unavailable.isNotEmpty) _ReferenceNotice(l: l),
            for (final id in unavailable)
              CheckboxListTile(
                title: Text(l.archivedReferenceLabel),
                value: true,
                onChanged: (_) => update(() => selected.remove(id)),
              ),
            for (final house in houses)
              CheckboxListTile(
                title: Text(house.name),
                value: selected.contains(house.id),
                onChanged: selected.length >= 30 && !selected.contains(house.id) ? null : (value) => update(() {
                  if (value == true) { selected.add(house.id); } else { selected.remove(house.id); }
                }),
              ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l.cancel)),
            TextButton(
              onPressed: !_isAdmin(ref.watch(currentUserProvider)) || unavailable.isNotEmpty ? null : () async {
                final saved = await runUiAction(dialogContext, ref, () => _fb.assignBoilerhouses(user.id, selected.toList()));
                if (saved && dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(l.save),
            ),
          ],
        );
      }),
    ));
  }

  void _showRolePicker(BuildContext context, AppUser user) {
    showDialog<void>(context: context, builder: (dialogContext) => Consumer(builder: (context, ref, _) {
      final l = ref.watch(l10nProvider);
      final isAdmin = _isAdmin(ref.watch(currentUserProvider));
      return AlertDialog(
        title: Text(l.adminChangeRole),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final role in UserRole.values.where((role) => role != UserRole.admin))
            ListTile(
              dense: true,
              leading: Icon(user.role == role ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(_roleLabel(role, l)),
              onTap: !isAdmin ? null : () async {
                final saved = await runUiAction(dialogContext, ref, () => _fb.changeRole(user.id, role));
                if (saved && dialogContext.mounted) Navigator.pop(dialogContext);
              },
            ),
        ]),
      );
    }));
  }

  void _showResetPassword(BuildContext context, AppUser user, AppL10n l) {
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(user.fullName),
      content: Text(l.operatorAssistance),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l.cancel))],
    ));
  }
}

Color _roleColor(UserRole role) => switch (role) {
  UserRole.admin => AppTheme.primary,
  UserRole.coAdmin => AppTheme.accent,
  UserRole.member => AppTheme.inkFaint,
};

String _roleLabel(UserRole role, AppL10n l) => switch (role) {
  UserRole.admin => l.roleAdmin,
  UserRole.coAdmin => l.roleCoAdmin,
  UserRole.member => l.roleMember,
};

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials, required this.color});
  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.adaptiveColor(context, this.color);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Center(child: Text(initials, style: TextStyle(fontWeight: FontWeight.w700, color: color))),
    );
  }
}
