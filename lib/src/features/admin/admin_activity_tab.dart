part of 'admin_panel_screen.dart';

final _auditProvider = StreamProvider<List<AuditEntry>>((ref) => _fb.auditLogStream());

class _AuditLogTab extends ConsumerWidget {
  const _AuditLogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final audit = ref.watch(_auditProvider);
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Text(l.isCyrl
          ? 'Эски клиент фаолияти: мустақил сервер аудити эмас. Янги журнал ва архив тарихи тегишли ҳужжатда сақланади.'
          : 'Eski klient faoliyati: mustaqil server auditi emas. Yangi jurnal va arxiv tarixi tegishli hujjatda saqlanadi.')),
      Expanded(child: audit.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l.syncError)),
      data: (entries) {
        if (entries.isEmpty) return const Center(child: Text('—'));
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                GlassIconTile(icon: _actionIcon(entry.action), color: _actionColor(entry.action), size: 40),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${entry.userName} • ${entry.action.name}', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text('${entry.targetType}: ${entry.targetName}', style: Theme.of(context).textTheme.bodySmall),
                ])),
                const SizedBox(width: 8),
                Text(_formatDate(entry.createdAt), style: Theme.of(context).textTheme.bodySmall),
              ]),
            );
          },
        );
      },
      )),
    ]);
  }

  static String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  static Color _actionColor(AuditAction action) => switch (action) {
    AuditAction.add || AuditAction.unban || AuditAction.approve => AppTheme.success,
    AuditAction.edit => AppTheme.primary,
    AuditAction.delete || AuditAction.ban => AppTheme.error,
    AuditAction.decline => AppTheme.warning,
    AuditAction.changeRole => AppTheme.accent,
  };

  static IconData _actionIcon(AuditAction action) => switch (action) {
    AuditAction.add => Icons.add_circle_outline,
    AuditAction.edit => Icons.edit_outlined,
    AuditAction.delete => Icons.delete_outline,
    AuditAction.ban => Icons.block,
    AuditAction.unban => Icons.check_circle_outline,
    AuditAction.approve => Icons.how_to_reg,
    AuditAction.decline => Icons.person_off_outlined,
    AuditAction.changeRole => Icons.swap_horiz,
  };
}
