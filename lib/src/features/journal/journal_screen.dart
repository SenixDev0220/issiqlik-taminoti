import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_state.dart';
import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../core/l10n.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/journal_entry.dart';
import '../../services/firebase_service.dart';
import '../auth/auth_providers.dart';
import 'journal_providers.dart';

// Convenience getter used throughout this file
extension _JournalRef on WidgetRef {
  void addJournalEntry(JournalEntry e) => read(journalStoreNotifierProvider).addEntry(e);
  void updateJournalEntry(JournalEntry e) => read(journalStoreNotifierProvider).updateEntry(e);
  void deleteJournalEntry(String id) => read(journalStoreNotifierProvider).deleteEntry(id);
}

// Shared color/icon mapping for importance and status (glass palette).
Color _importanceColor(JournalEntryImportance i) {
  switch (i) {
    case JournalEntryImportance.normal:
      return AppTheme.primary;
    case JournalEntryImportance.important:
      return AppTheme.warning;
    case JournalEntryImportance.critical:
      return AppTheme.error;
  }
}

IconData _importanceIcon(JournalEntryImportance i) {
  switch (i) {
    case JournalEntryImportance.normal:
      return Icons.assignment_outlined;
    case JournalEntryImportance.important:
      return Icons.error_outline_rounded;
    case JournalEntryImportance.critical:
      return Icons.warning_amber_rounded;
  }
}

Color _statusColor(JournalEntryStatus s) {
  switch (s) {
    case JournalEntryStatus.open:
      return AppTheme.accent;
    case JournalEntryStatus.inProgress:
      return AppTheme.warning;
    case JournalEntryStatus.closed:
      return AppTheme.success;
  }
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final allEntries = ref.watch(journalEntriesProvider);
    final l = ref.watch(l10nProvider);
    final currentUser = ref.watch(currentUserProvider);
    final entries = _search.isEmpty
        ? allEntries
        : allEntries.where((e) => e.title.toLowerCase().contains(_search) || e.category.toLowerCase().contains(_search) || e.authorName.toLowerCase().contains(_search)).toList();

    return GlassScaffold(
      title: l.journalTitle,
      leading: BackButton(onPressed: () => context.go('/home')),
      tab: AppTab.journal,
      onFab: () => _showEntrySheet(context, ref, null),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: GlassSearchField(
              hint: '${l.journalTitle}...',
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? _EmptyState(l: l)
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(journalStreamProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, kBottomNavSpace),
                      itemCount: entries.length,
                      scrollCacheExtent: ScrollCacheExtent.pixels(400),
                      addAutomaticKeepAlives: false,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final isOwner = currentUser?.id == entry.authorId;
                        final isAdmin = currentUser?.role == UserRole.admin || currentUser?.role == UserRole.coAdmin;
                        return RepaintBoundary(
                          child: _JournalCard(entry: entry, l: l, canEdit: isOwner, canDelete: isOwner || isAdmin),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static void _showEntrySheet(BuildContext context, WidgetRef ref, JournalEntry? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EntrySheet(existing: existing),
    );
  }
}

// -- Empty state --------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final AppL10n l;
  const _EmptyState({required this.l});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.assignment_outlined, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(l.journalEmpty, style: const TextStyle(fontSize: 16, color: AppTheme.inkSoft)),
        ],
      ),
    );
  }
}

// -- Journal card -------------------------------------------------------------
class _JournalCard extends ConsumerWidget {
  final JournalEntry entry;
  final AppL10n l;
  final bool canEdit;
  final bool canDelete;

  const _JournalCard({
    required this.entry,
    required this.l,
    required this.canEdit,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importanceColor = _importanceColor(entry.importance);
    final statusColor = _statusColor(entry.status);
    final textTheme = Theme.of(context).textTheme;
    final author = entry.authorName.isNotEmpty ? entry.authorName : entry.authorId;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      onTap: () => _showDetails(context, ref),
      child: Row(
        children: [
          GlassIconTile(icon: _importanceIcon(entry.importance), color: importanceColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(color: AppTheme.ink, height: 1.3),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.category} • $author • ${_fmtDate(entry.eventDateTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: AppTheme.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(label: entry.status.label(l), color: statusColor),
          if (canEdit || canDelete)
            _OptionsMenu(entry: entry, l: l, canEdit: canEdit, canDelete: canDelete),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.92,
        builder: (_, ctrl) => _DetailsSheet(entry: entry, l: l, scrollCtrl: ctrl),
      ),
    );
  }
}

// -- Options menu (edit / delete) ---------------------------------------------
class _OptionsMenu extends ConsumerWidget {
  final JournalEntry entry;
  final AppL10n l;
  final bool canEdit;
  final bool canDelete;

  const _OptionsMenu({required this.entry, required this.l, required this.canEdit, required this.canDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.inkFaint),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        itemBuilder: (_) => [
          if (canEdit)
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                const SizedBox(width: 10),
                Text(l.journalEdit),
              ]),
            ),
          if (canEdit)
            PopupMenuItem(
              value: 'status',
              child: Row(children: [
                const Icon(Icons.swap_horiz_outlined, size: 18, color: AppTheme.accent),
                const SizedBox(width: 10),
                Text(l.journalStatus),
              ]),
            ),
          if (canDelete)
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                const SizedBox(width: 10),
                Text(l.journalDelete, style: const TextStyle(color: AppTheme.error)),
              ]),
            ),
        ],
        onSelected: (value) {
          if (value == 'edit') {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => _EntrySheet(existing: entry),
            );
          } else if (value == 'status') {
            _showStatusPicker(context, ref);
          } else if (value == 'delete') {
            _confirmDelete(context, ref);
          }
        },
      ),
    );
  }

  void _showStatusPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.journalStatus),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: JournalEntryStatus.values.map((s) {
            final selected = entry.status == s;
            return ListTile(
              dense: true,
              leading: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? AppTheme.primary : AppTheme.inkFaint,
              ),
              title: Text(s.label(l)),
              onTap: () {
                ref.updateJournalEntry(_copyWith(entry, status: s));
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.journalDeleteTitle),
        content: Text(l.journalDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.journalCancel)),
          ElevatedButton(
            onPressed: () {
              ref.deleteJournalEntry(entry.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              minimumSize: const Size(0, 44),
            ),
            child: Text(l.journalDelete),
          ),
        ],
      ),
    );
  }

  JournalEntry _copyWith(JournalEntry e, {JournalEntryStatus? status}) {
    return JournalEntry(
      id: e.id,
      boilerHouseId: e.boilerHouseId,
      equipmentId: e.equipmentId,
      eventDateTime: e.eventDateTime,
      category: e.category,
      title: e.title,
      description: e.description,
      importance: e.importance,
      status: status ?? e.status,
      photoPaths: e.photoPaths,
      authorId: e.authorId,
      authorName: e.authorName,
      createdAt: e.createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

// -- Details sheet ------------------------------------------------------------
class _DetailsSheet extends StatelessWidget {
  final JournalEntry entry;
  final AppL10n l;
  final ScrollController scrollCtrl;

  const _DetailsSheet({required this.entry, required this.l, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    final importanceColor = _importanceColor(entry.importance);
    final statusColor = _statusColor(entry.status);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).bottomSheetTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.inkFaint.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header: chips + title
            Row(
              children: [
                StatusChip(
                  label: entry.importance.label(l),
                  color: importanceColor,
                  icon: _importanceIcon(entry.importance),
                ),
                const SizedBox(width: 6),
                StatusChip(label: entry.status.label(l), color: statusColor),
              ],
            ),
            const SizedBox(height: 12),
            Text(entry.title, style: textTheme.headlineMedium?.copyWith(fontSize: 20, height: 1.3)),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  _InfoRow(icon: Icons.category_outlined, label: l.journalCategory, value: entry.category),
                  _InfoRow(icon: Icons.flag_outlined, label: l.journalStatus, value: entry.status.label(l)),
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: l.journalAuthor,
                    value: entry.authorName.isNotEmpty ? entry.authorName : entry.authorId,
                  ),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: '',
                    value: '${entry.eventDateTime.day.toString().padLeft(2, '0')}.${entry.eventDateTime.month.toString().padLeft(2, '0')}.${entry.eventDateTime.year}  ${entry.eventDateTime.hour.toString().padLeft(2, '0')}:${entry.eventDateTime.minute.toString().padLeft(2, '0')}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.journalDescription, style: textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(entry.description, style: textTheme.bodyMedium?.copyWith(height: 1.6)),
                ],
              ),
            ),
            if (entry.photoPaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l.journalPhotos, style: textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: entry.photoPaths.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _openPhoto(context, entry.photoPaths[i]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        entry.photoPaths[i],
                        width: 100,
                        height: 100,
                        cacheWidth: (100 * MediaQuery.devicePixelRatioOf(context)).round(),
                        cacheHeight: (100 * MediaQuery.devicePixelRatioOf(context)).round(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 100, height: 100,
                          color: AppTheme.inkFaint.withValues(alpha: 0.15),
                          child: const Icon(Icons.broken_image, color: AppTheme.inkFaint),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40, right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.inkSoft),
          const SizedBox(width: 8),
          if (label.isNotEmpty) ...[
            Text('$label: ', style: const TextStyle(fontSize: 13, color: AppTheme.inkSoft, fontWeight: FontWeight.w500)),
          ],
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Add / Edit entry sheet ---------------------------------------------------
class _EntrySheet extends ConsumerStatefulWidget {
  final JournalEntry? existing;
  const _EntrySheet({this.existing});

  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _categoryCtrl;
  late JournalEntryImportance _importance;
  late JournalEntryStatus _status;
  final List<File> _newPhotos = [];
  late List<String> _existingPhotoUrls;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _categoryCtrl = TextEditingController(text: e?.category ?? '');
    _importance = e?.importance ?? JournalEntryImportance.normal;
    _status = e?.status ?? JournalEntryStatus.open;
    _existingPhotoUrls = List<String>.from(e?.photoPaths ?? []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _saving = true);

    // Upload any new photos to Firebase Storage
    List<String> uploadedUrls = [];
    if (_newPhotos.isNotEmpty) {
      try {
        uploadedUrls = await FirebaseService.instance.uploadFiles(
          files: _newPhotos,
          folder: 'journal_photos',
        );
      } catch (_) {
        if (mounted) setState(() => _saving = false);
        return;
      }
    }

    final allPhotos = [..._existingPhotoUrls, ...uploadedUrls];

    if (_isEditing) {
      final updated = JournalEntry(
        id: widget.existing!.id,
        boilerHouseId: widget.existing!.boilerHouseId,
        equipmentId: widget.existing!.equipmentId,
        eventDateTime: widget.existing!.eventDateTime,
        category: _categoryCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        importance: _importance,
        status: _status,
        photoPaths: allPhotos,
        authorId: widget.existing!.authorId,
        authorName: widget.existing!.authorName,
        createdAt: widget.existing!.createdAt,
        updatedAt: DateTime.now(),
      );
      ref.updateJournalEntry(updated);
    } else {
      final entry = JournalEntry(
        id: 'je-${DateTime.now().millisecondsSinceEpoch}',
        boilerHouseId: user.boilerhouseIds.isNotEmpty ? user.boilerhouseIds.first : '',
        eventDateTime: DateTime.now(),
        category: _categoryCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        importance: _importance,
        status: _status,
        photoPaths: allPhotos,
        authorId: user.id,
        authorName: user.fullName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      ref.addJournalEntry(entry);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickPhoto({required ImageSource source}) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ref.read(l10nProvider).photoUploadUnavailable), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    const sectionLabelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.inkSoft);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).bottomSheetTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.inkFaint.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isEditing ? l.journalEditTitle : l.journalAddEntry,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l.journalTitleField,
                  hintText: l.journalTitleHint,
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? l.fieldRequired : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _categoryCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l.journalCategory,
                  hintText: l.journalCategoryHint,
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? l.fieldRequired : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: l.journalDescription,
                  hintText: l.journalDescHint,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.notes),
                  ),
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? l.fieldRequired : null,
              ),
              const SizedBox(height: 16),

              // Importance
              Text(l.journalImportance, style: sectionLabelStyle),
              const SizedBox(height: 8),
              Row(
                children: JournalEntryImportance.values.map((imp) {
                  final selected = _importance == imp;
                  final color = _importanceColor(imp);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _importance = imp),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? color : color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? color : color.withValues(alpha: 0.25), width: 1.5),
                        ),
                        child: Text(
                          imp.label(l),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : color,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Status
              Text(l.journalStatus, style: sectionLabelStyle),
              const SizedBox(height: 8),
              Row(
                children: JournalEntryStatus.values.map((st) {
                  final selected = _status == st;
                  final color = _statusColor(st);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _status = st),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? color : color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? color : color.withValues(alpha: 0.25), width: 1.5),
                        ),
                        child: Text(
                          st.label(l),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : color,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Photos
              Text(l.journalPhotos, style: sectionLabelStyle),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Add buttons
                    _PhotoActionButton(
                      icon: Icons.camera_alt_outlined,
                      onTap: () => _pickPhoto(source: ImageSource.camera),
                    ),
                    const SizedBox(width: 8),
                    _PhotoActionButton(
                      icon: Icons.photo_library_outlined,
                      onTap: () => _pickPhoto(source: ImageSource.gallery),
                    ),
                    const SizedBox(width: 8),
                    // Existing photos (URLs)
                    ..._existingPhotoUrls.map((url) => _PhotoThumb(
                          url: url,
                          onRemove: () => setState(() => _existingPhotoUrls.remove(url)),
                        )),
                    // New photos (local files)
                    ..._newPhotos.map((f) => _PhotoThumbLocal(
                          file: f,
                          onRemove: () => setState(() => _newPhotos.remove(f)),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.journalCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isEditing ? l.save : l.journalSave),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Extensions ---------------------------------------------------------------
extension JournalEntryImportanceX on JournalEntryImportance {
  String label(AppL10n l) {
    switch (this) {
      case JournalEntryImportance.normal: return l.importanceNormal;
      case JournalEntryImportance.important: return l.importanceImportant;
      case JournalEntryImportance.critical: return l.importanceCritical;
    }
  }
}

extension JournalEntryStatusX on JournalEntryStatus {
  String label(AppL10n l) {
    switch (this) {
      case JournalEntryStatus.open: return l.jStatusOpen;
      case JournalEntryStatus.inProgress: return l.jStatusInProgress;
      case JournalEntryStatus.closed: return l.jStatusClosed;
    }
  }
}


// -- Photo widgets ------------------------------------------------------------

class _PhotoActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _PhotoActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.30), style: BorderStyle.solid),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 28),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;
  const _PhotoThumb({required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              url,
              width: 80,
              height: 80,
              cacheWidth: (80 * MediaQuery.devicePixelRatioOf(context)).round(),
              cacheHeight: (80 * MediaQuery.devicePixelRatioOf(context)).round(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 80, height: 80,
                color: AppTheme.inkFaint.withValues(alpha: 0.15),
                child: const Icon(Icons.broken_image, color: AppTheme.inkFaint),
              ),
              loadingBuilder: (_, child, prog) => prog == null ? child : Container(
                width: 80, height: 80,
                color: AppTheme.inkFaint.withValues(alpha: 0.08),
                child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
            ),
          ),
          Positioned(
            top: 2, right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppTheme.ink.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumbLocal extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const _PhotoThumbLocal({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
          ),
          Positioned(
            top: 2, right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppTheme.ink.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
