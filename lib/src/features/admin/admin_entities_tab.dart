part of 'admin_panel_screen.dart';

class _BoilerhousesTab extends ConsumerWidget {
  const _BoilerhousesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houses = ref.watch(boilerHouseListProvider);
    final l = ref.watch(l10nProvider);
    final canArchive = _isAdmin(ref.watch(currentUserProvider));
    if (houses.isEmpty) return const Center(child: Text('—'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: houses.length,
      itemBuilder: (context, index) {
        final house = houses[index];
        return _EntityCard(
          icon: Icons.local_fire_department_outlined,
          color: AppTheme.accent,
          title: house.name,
          subtitle: '${house.installedCapacity} ${l.unitGcalShort} • ${house.address}',
          l: l,
          onEdit: () => _showAdminSheet(context, _BoilerForm(existing: house)),
          onArchive: canArchive
              ? () => _confirmArchive(context, ref, house.name, () => _fb.deleteBoilerhouse(house.id))
              : null,
        );
      },
    );
  }
}

class _InstructionsTab extends ConsumerWidget {
  const _InstructionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(instructionsProvider);
    final l = ref.watch(l10nProvider);
    final canArchive = _isAdmin(ref.watch(currentUserProvider));
    if (items.isEmpty) return const Center(child: Text('—'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final instruction = items[index];
        return _EntityCard(
          icon: Icons.menu_book_outlined,
          color: AppTheme.success,
          title: instruction.title,
          subtitle: instruction.category,
          l: l,
          onEdit: () => _showAdminSheet(context, _InstructionForm(existing: instruction)),
          onArchive: canArchive
              ? () => _confirmArchive(context, ref, instruction.title, () => _fb.deleteInstruction(instruction.id))
              : null,
        );
      },
    );
  }
}

class _DrawingsTab extends ConsumerWidget {
  const _DrawingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(drawingsProvider);
    final l = ref.watch(l10nProvider);
    final canArchive = _isAdmin(ref.watch(currentUserProvider));
    if (items.isEmpty) return const Center(child: Text('—'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final drawing = items[index];
        return _EntityCard(
          icon: Icons.architecture_outlined,
          color: AppTheme.primary,
          title: drawing.title,
          subtitle: '${drawing.number} • ${drawing.category}',
          l: l,
          onEdit: () => _showAdminSheet(context, _DrawingForm(existing: drawing)),
          onArchive: canArchive
              ? () => _confirmArchive(context, ref, drawing.title, () => _fb.deleteDrawing(drawing.id))
              : null,
        );
      },
    );
  }
}

class _EntityCard extends StatelessWidget {
  const _EntityCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.l,
    required this.onEdit,
    this.onArchive,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final AppL10n l;
  final VoidCallback onEdit;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) => GlassCard(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
    child: Row(
      children: [
        GlassIconTile(icon: icon, color: color, size: 40),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ],
        )),
        IconButton(
          tooltip: l.formEdit,
          icon: Icon(Icons.edit_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
          onPressed: onEdit,
        ),
        if (onArchive != null)
          IconButton(
            tooltip: l.archiveAction,
            icon: Icon(Icons.archive_outlined, size: 20, color: AppTheme.adaptiveColor(context, AppTheme.warning)),
            onPressed: onArchive,
          ),
      ],
    ),
  );
}

Future<void> _confirmArchive(
  BuildContext context,
  WidgetRef ref,
  String name,
  Future<void> Function() archive,
) async {
  if (!_isAdmin(ref.read(currentUserProvider))) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Consumer(builder: (context, dialogRef, _) {
      final l = dialogRef.watch(l10nProvider);
      final canArchive = _isAdmin(dialogRef.watch(currentUserProvider));
      return AlertDialog(
        title: Text(l.archiveAction),
        content: Text(l.archiveConfirm(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: canArchive ? () async {
              if (!_isAdmin(dialogRef.read(currentUserProvider))) return;
              final saved = await runUiAction(dialogContext, dialogRef, archive);
              if (saved && dialogContext.mounted) Navigator.pop(dialogContext);
            } : null,
            child: Text(l.archiveAction),
          ),
        ],
      );
    }),
  );
}
