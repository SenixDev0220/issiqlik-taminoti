import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/audit_entry.dart';
import '../../domain/models/boiler_house.dart';
import '../../domain/models/drawing.dart';
import '../../domain/models/instruction.dart';
import '../../services/firebase_service.dart';
import '../auth/auth_providers.dart';
import '../boilerhouse/boilerhouse_providers.dart';
import '../drawings/drawings_providers.dart';
import '../instructions/instructions_providers.dart';

final _fb = FirebaseService.instance;

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 6, vsync: this)..addListener(() => setState(() {})); }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final l = ref.watch(l10nProvider);
    if (user == null || (user.role != UserRole.admin && user.role != UserRole.coAdmin)) {
      return GlassScaffold(
        title: l.adminTitle,
        leading: BackButton(onPressed: () => context.go('/home')),
        body: Center(child: Text(l.adminAccessDenied)),
      );
    }
    final isAdmin = user.role == UserRole.admin;
    return GlassScaffold(
      appBar: AppBar(
        title: Text(l.adminTitle),
        leading: BackButton(onPressed: () => context.go('/home')),
        bottom: TabBar(controller: _tabs, isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
          Tab(text: l.adminPendingUsers), Tab(text: l.adminUsersList),
          Tab(text: l.navBoilerhouses), Tab(text: l.navInstructions), Tab(text: l.navDrawings),
          Tab(text: l.auditLogTab),
        ]),
      ),
      body: TabBarView(controller: _tabs, children: [
        _PendingTab(isAdmin: isAdmin), _UsersTab(currentUserId: user.id, isAdmin: isAdmin),
        const _BoilerhousesTab(), const _InstructionsTab(), const _DrawingsTab(),
        const _AuditLogTab(),
      ]),
      floatingActionButton: _buildFab(context, l),
    );
  }

  Widget? _buildFab(BuildContext context, dynamic l) {
    switch (_tabs.index) {
      case 2: return FloatingActionButton.extended(heroTag: 'bh', shape: const StadiumBorder(), onPressed: () => _showBoilerForm(context), icon: const Icon(Icons.add), label: Text(l.navBoilerhouses));
      case 3: return FloatingActionButton.extended(heroTag: 'ins', shape: const StadiumBorder(), onPressed: () => _showInstructionForm(context), icon: const Icon(Icons.add), label: Text(l.navInstructions));
      case 4: return FloatingActionButton.extended(heroTag: 'drw', shape: const StadiumBorder(), onPressed: () => _showDrawingForm(context), icon: const Icon(Icons.add), label: Text(l.navDrawings));
      default: return null;
    }
  }

  // ── Boiler form (add/edit) ───────────────────────────────────────

  void _showBoilerForm(BuildContext ctx, [BoilerHouse? existing]) {
    final isEdit = existing != null;
    final nameC = TextEditingController(text: existing?.name ?? '');
    final addrC = TextEditingController(text: existing?.address ?? '');
    final yearC = TextEditingController(text: isEdit && existing.yearBuilt != 0 ? '${existing.yearBuilt}' : '');
    final modYearC = TextEditingController(text: isEdit && existing.modernizationYear != 0 ? '${existing.modernizationYear}' : '');
    final areaC = TextEditingController(text: isEdit && existing.totalArea != 0 ? '${existing.totalArea}' : '');
    final workersC = TextEditingController(text: isEdit && existing.workersCount != 0 ? '${existing.workersCount}' : '');
    final capC = TextEditingController(text: isEdit && existing.installedCapacity != 0 ? '${existing.installedCapacity}' : '');
    final loadC = TextEditingController(text: isEdit && existing.connectedLoad != 0 ? '${existing.connectedLoad}' : '');
    final consumersC = TextEditingController(text: existing?.consumers ?? '');
    final pipeC = TextEditingController(text: isEdit && existing.pipelineLength != 0 ? '${existing.pipelineLength}' : '');
    final phoneC = TextEditingController(text: existing?.dispatchPhone ?? '');
    final elecC = TextEditingController(text: isEdit && existing.annualElectricity != 0 ? '${existing.annualElectricity.toInt()}' : '');
    final gasC = TextEditingController(text: isEdit && existing.annualGas != 0 ? '${existing.annualGas.toInt()}' : '');
    final heatC = TextEditingController(text: isEdit && existing.annualHeatProduction != 0 ? '${existing.annualHeatProduction.toInt()}' : '');
    final locationC = TextEditingController(text: existing?.locationUrl ?? '');
    String selectedDistrict = existing?.district ?? 'Урганч шаҳар';

    const districts = ['Урганч шаҳар', 'Шовот', 'Хонка', 'Қўшкўпир', 'Хазорасп', 'Тупроккала', 'Янгиариқ', 'Урганч туман', 'Боғот', 'Янгибозор', 'Гурлан', 'Хива'];

    final l = ref.read(l10nProvider);
    _showSheet(ctx, isEdit ? l.formEdit : l.formNewBoilerhouse, [
      // ignore: deprecated_member_use
      StatefulBuilder(builder: (_, setSt) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: selectedDistrict,
          decoration: InputDecoration(labelText: '${l.formDistrict} *'),
          items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: (v) => setSt(() => selectedDistrict = v ?? selectedDistrict),
        ),
      )),
      _field(nameC, '${l.formName} *'),
      _field(addrC, l.formAddress),
      ResponsiveWrap(minChildWidth: 200, children: [_field(yearC, l.fieldYearBuiltDetail, num: true), _field(modYearC, l.fieldModernization, num: true)]),
      ResponsiveWrap(minChildWidth: 200, children: [_field(areaC, l.formArea, num: true), _field(workersC, l.fieldWorkers, num: true)]),
      ResponsiveWrap(minChildWidth: 200, children: [_field(capC, l.formCapacity, num: true), _field(loadC, l.formLoad, num: true)]),
      _field(consumersC, l.fieldConsumers),
      ResponsiveWrap(minChildWidth: 200, children: [_field(pipeC, l.formPipeline, num: true), _field(phoneC, l.formPhone)]),
      ResponsiveWrap(minChildWidth: 200, children: [_field(elecC, l.formElectricity, num: true), _field(gasC, l.formGas, num: true)]),
      _field(heatC, l.formHeat, num: true),
      _field(locationC, l.formLocationUrl),
    ], () async {
      if (nameC.text.trim().isEmpty) return;
      final bh = BoilerHouse(
        id: existing?.id ?? 'bh-${DateTime.now().millisecondsSinceEpoch}',
        name: nameC.text.trim(),
        district: selectedDistrict,
        address: addrC.text.trim(),
        yearBuilt: int.tryParse(yearC.text) ?? 0,
        modernizationYear: int.tryParse(modYearC.text) ?? 0,
        totalArea: double.tryParse(areaC.text) ?? 0,
        workersCount: int.tryParse(workersC.text) ?? 0,
        installedCapacity: double.tryParse(capC.text) ?? 0,
        connectedLoad: double.tryParse(loadC.text) ?? 0,
        consumers: consumersC.text.trim(),
        pipelineLength: double.tryParse(pipeC.text) ?? 0,
        dispatchPhone: phoneC.text.trim(),
        annualElectricity: double.tryParse(elecC.text) ?? 0,
        annualGas: double.tryParse(gasC.text) ?? 0,
        annualHeatProduction: double.tryParse(heatC.text) ?? 0,
        locationUrl: locationC.text.trim(),
        operatorsCount: existing?.operatorsCount ?? 0,
        annualWater: existing?.annualWater ?? 0,
        aboveGroundPipeline: existing?.aboveGroundPipeline ?? 0,
        belowGroundPipeline: existing?.belowGroundPipeline ?? 0,
        defects: existing?.defects ?? '',
        status: existing?.status ?? BoilerHouseStatus.operating,
      );
      final saved = await runUiAction(ctx, ref, () => isEdit ? _fb.updateBoilerhouse(bh) : _fb.addBoilerhouse(bh));
      if (saved && ctx.mounted) Navigator.pop(ctx);
    });
  }

  // ── Instruction form ─────────────────────────────────────────────

  void _showInstructionForm(BuildContext ctx, [Instruction? existing]) {
    final isEdit = existing != null;
    final titleC = TextEditingController(text: existing?.title ?? '');
    final catC = TextEditingController(text: existing?.category ?? '');
    final bodyC = TextEditingController(text: existing?.body ?? '');

    final l = ref.read(l10nProvider);
    _showSheet(ctx, isEdit ? l.formEdit : l.formNewInstruction, [
      _field(titleC, '${l.changeLogHeading} *'),
      _field(catC, l.formCategory),
      _field(bodyC, l.formText, lines: 5),
    ], () async {
      if (titleC.text.trim().isEmpty) return;
      final i = Instruction(
        id: existing?.id ?? 'instr-${DateTime.now().millisecondsSinceEpoch}',
        title: titleC.text.trim(),
        category: catC.text.trim(),
        body: bodyC.text.trim(),
        version: existing?.version ?? '1.0',
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        authorId: existing?.authorId ?? '',
        urgency: existing?.urgency ?? InstructionUrgency.normal,
        boilerHouseIds: existing?.boilerHouseIds ?? const [],
        equipmentTypes: existing?.equipmentTypes ?? const [],
      );
      final saved = await runUiAction(ctx, ref, () => isEdit ? _fb.updateInstruction(i) : _fb.addInstruction(i));
      if (saved && ctx.mounted) Navigator.pop(ctx);
    });
  }

  // ── Drawing form ─────────────────────────────────────────────────

  void _showDrawingForm(BuildContext ctx, [Drawing? existing]) {
    final isEdit = existing != null;
    final titleC = TextEditingController(text: existing?.title ?? '');
    final numC = TextEditingController(text: existing?.number ?? '');
    final catC = TextEditingController(text: existing?.category ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    String? houseId = existing?.boilerHouseId;

    final l = ref.read(l10nProvider);
    _showSheet(ctx, isEdit ? l.formEdit : l.formNewDrawing, [
      StatefulBuilder(builder: (_, update) => DropdownButtonFormField<String>(
        initialValue: ref.read(boilerHouseListProvider).any((h) => h.id == houseId) ? houseId : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.navBoilerhouses),
        items: ref.read(boilerHouseListProvider).map((h) => DropdownMenuItem(value: h.id, child: Text(h.name, maxLines: 2, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (value) => update(() => houseId = value),
      )),
      _field(titleC, '${l.changeLogHeading} *'),
      _field(numC, l.formNumber),
      _field(catC, l.formCategory),
      _field(descC, l.changeLogDescription, lines: 3),
    ], () async {
      if (titleC.text.trim().isEmpty || houseId == null || houseId!.isEmpty) return;
      final d = Drawing(
        id: existing?.id ?? 'draw-${DateTime.now().millisecondsSinceEpoch}',
        title: titleC.text.trim(),
        number: numC.text.trim(),
        category: catC.text.trim(),
        description: descC.text.trim(),
        boilerHouseId: houseId!,
        filePath: existing?.filePath ?? '',
        authorId: existing?.authorId ?? '',
        addedAt: existing?.addedAt ?? DateTime.now(),
      );
      final saved = await runUiAction(ctx, ref, () => isEdit ? _fb.updateDrawing(d) : _fb.addDrawing(d));
      if (saved && ctx.mounted) Navigator.pop(ctx);
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Widget _field(TextEditingController c, String label, {bool num = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: num ? TextInputType.number : (lines > 1 ? TextInputType.multiline : TextInputType.text),
        maxLines: lines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  void _showSheet(BuildContext ctx, String title, List<Widget> fields, VoidCallback onSave) {
    showModalBottomSheet(context: ctx, isScrollControlled: true, useSafeArea: true, builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppTheme.inkFaint.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)))),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.ink)),
            const SizedBox(height: 16),
            Expanded(child: ListView(controller: scrollCtrl, children: fields)),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onSave, child: Text(ref.read(l10nProvider).save))),
          ]),
        ),
        ),
      );
    });
  }
}



// ═══════════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════
class _PendingTab extends ConsumerWidget {
  final bool isAdmin;
  const _PendingTab({required this.isAdmin});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingUsersProvider);
    final l = ref.watch(l10nProvider);
    if (pending.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success),
        const SizedBox(height: 12),
        Text(l.adminNoPending, style: const TextStyle(fontSize: 16, color: AppTheme.inkSoft)),
      ]));
    }
    return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), itemCount: pending.length, itemBuilder: (_, i) {
      final u = pending[i];
      return GlassCard(
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              _InitialsAvatar(initials: u.initials, color: AppTheme.warning),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.fullName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('${u.login} • ${u.phone}', style: Theme.of(context).textTheme.bodySmall),
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
                  onPressed: () => runUiAction(context, ref, () => _fb.approveUser(u.id)),
                )),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: AppTheme.error,
                    side: BorderSide(color: AppTheme.error.withValues(alpha: 0.45), width: 1.2),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(l.adminDecline),
                  onPressed: () => runUiAction(context, ref, () => _fb.declineUser(u.id)),
                )),
              ]),
            ],
          ],
        ),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════
class _UsersTab extends ConsumerWidget {
  final String currentUserId; final bool isAdmin;
  const _UsersTab({required this.currentUserId, required this.isAdmin});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allUsers = ref.watch(userStoreProvider);
    final l = ref.watch(l10nProvider);
    final users = allUsers.where((u) => u.status != UserStatus.pending).toList();
    return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), itemCount: users.length, itemBuilder: (_, i) {
      final u = users[i]; final isSelf = u.id == currentUserId; final isBanned = u.status == UserStatus.blocked;
      return GlassCard(
        margin: const EdgeInsets.only(bottom: 10),
        tint: isBanned ? AppTheme.error : null,
        child: Row(children: [
          _InitialsAvatar(initials: u.initials, color: isBanned ? AppTheme.inkFaint : _rc(u.role)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              u.fullName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                decoration: isBanned ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 2),
            Text('${u.login} • ${u.phone}', style: Theme.of(context).textTheme.bodySmall),
          ])),
          const SizedBox(width: 8),
          isAdmin && !isSelf && u.role != UserRole.admin ? PopupMenuButton<String>(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.inkSoft),
            itemBuilder: (_) => [
              if (!isBanned) ...[
                PopupMenuItem(value: 'houses', child: Text(l.navBoilerhouses)),
                PopupMenuItem(value: 'role', child: Row(children: [const Icon(Icons.swap_horiz, size: 18, color: AppTheme.primary), const SizedBox(width: 8), Text(l.adminChangeRole)])),
                PopupMenuItem(value: 'resetpw', child: Row(children: [const Icon(Icons.lock_reset, size: 18, color: AppTheme.warning), const SizedBox(width: 8), Text(l.resetPassword, style: const TextStyle(color: AppTheme.warning))])),
                PopupMenuItem(value: 'ban', child: Row(children: [const Icon(Icons.block, size: 18, color: AppTheme.error), const SizedBox(width: 8), Text(l.ban, style: const TextStyle(color: AppTheme.error))])),
              ] else
                PopupMenuItem(value: 'unban', child: Row(children: [const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.success), const SizedBox(width: 8), Text(l.unban, style: const TextStyle(color: AppTheme.success))])),
            ],
            onSelected: (v) {
              if (v == 'houses') _showHousePicker(context, ref, u);
              if (v == 'role') _showRolePicker(context, ref, u, l);
              if (v == 'resetpw') _showResetPassword(context, u, l);
              if (v == 'ban') runUiAction(context, ref, () => _fb.banUser(u.id));
              if (v == 'unban') runUiAction(context, ref, () => _fb.unbanUser(u.id));
            },
          ) : StatusChip(
            label: isBanned ? 'Banned' : _rl(u.role, l),
            color: isBanned ? AppTheme.error : _rc(u.role),
          ),
        ]),
      );
    });
  }
  void _showHousePicker(BuildContext ctx, WidgetRef ref, AppUser user) {
    final selected = user.boilerhouseIds.toSet();
    final houses = ref.read(boilerHouseListProvider);
    final l = ref.read(l10nProvider);
    showDialog(context: ctx, builder: (dialogContext) => StatefulBuilder(builder: (_, update) => AlertDialog(
      title: Text('${l.navBoilerhouses} (${selected.length}/30)'),
      content: SizedBox(width: 480, height: 360, child: ListView.builder(
        itemCount: houses.length,
        itemBuilder: (_, index) {
          final h = houses[index];
          return CheckboxListTile(
            title: Text(h.name), value: selected.contains(h.id),
            onChanged: selected.length >= 30 && !selected.contains(h.id) ? null : (value) => update(() {
              if (value == true) { selected.add(h.id); } else { selected.remove(h.id); }
            }),
          );
        },
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l.cancel)),
        TextButton(onPressed: () async {
          if (await runUiAction(ctx, ref, () => _fb.assignBoilerhouses(user.id, selected.toList())) && dialogContext.mounted) {
            Navigator.pop(dialogContext);
          }
        }, child: Text(l.save)),
      ],
    )));
  }

  void _showRolePicker(BuildContext ctx, WidgetRef ref, AppUser user, dynamic l) {
    showDialog(context: ctx, builder: (_) => AlertDialog(title: Text(l.adminChangeRole), content: Column(mainAxisSize: MainAxisSize.min, children: UserRole.values.where((r) => r != UserRole.admin).map((r) => ListTile(dense: true, leading: Icon(user.role == r ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: user.role == r ? AppTheme.primary : AppTheme.inkFaint), title: Text(_rl(r, l)), onTap: () async { if (await runUiAction(ctx, ref, () => _fb.changeRole(user.id, r)) && ctx.mounted) Navigator.pop(ctx); })).toList())));
  }
  void _showResetPassword(BuildContext ctx, AppUser user, dynamic l) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      title: Text(user.fullName),
      content: Text(l.operatorAssistance),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel))],
    ));
  }
  Color _rc(UserRole r) { switch (r) { case UserRole.admin: return AppTheme.primary; case UserRole.coAdmin: return AppTheme.accent; case UserRole.member: return AppTheme.inkFaint; } }
  String _rl(UserRole r, dynamic l) { switch (r) { case UserRole.admin: return l.roleAdmin; case UserRole.coAdmin: return l.roleCoAdmin; case UserRole.member: return l.roleMember; } }
}

/// Circular tinted avatar with user initials.
class _InitialsAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  const _InitialsAvatar({required this.initials, required this.color});
  @override
  Widget build(BuildContext context) {
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


// ═══════════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════
class _BoilerhousesTab extends ConsumerWidget {
  const _BoilerhousesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houses = ref.watch(boilerHouseListProvider);
    final l = ref.watch(l10nProvider);
    if (houses.isEmpty) return const Center(child: Text('—'));
    return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), itemCount: houses.length, itemBuilder: (_, i) {
      final h = houses[i];
      return GlassCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          const GlassIconTile(icon: Icons.local_fire_department_outlined, color: AppTheme.accent, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text('${h.installedCapacity} ${l.unitGcalShort} • ${h.address}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ])),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary), onPressed: () {
            final state = context.findAncestorStateOfType<_AdminPanelScreenState>();
            state?._showBoilerForm(context, h);
          }),
          IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20), onPressed: () => _confirmDelete(context, ref, h.id, h.name)),
        ]),
      );
    });
  }
  void _confirmDelete(BuildContext ctx, WidgetRef ref, String id, String name) {
    final l = ref.read(l10nProvider);
    showDialog(context: ctx, builder: (_) => AlertDialog(
      title: Text(l.deleteConfirm), content: Text(name),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.no)), ElevatedButton(onPressed: () async { if (await runUiAction(ctx, ref, () => _fb.deleteBoilerhouse(id)) && ctx.mounted) Navigator.pop(ctx); }, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error), child: Text(l.yes))],
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════
class _InstructionsTab extends ConsumerWidget {
  const _InstructionsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(instructionsProvider);
    if (items.isEmpty) return const Center(child: Text('—'));
    return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), itemCount: items.length, itemBuilder: (_, i) {
      final instr = items[i];
      return GlassCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          const GlassIconTile(icon: Icons.menu_book_outlined, color: AppTheme.success, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(instr.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(instr.category, style: Theme.of(context).textTheme.bodySmall),
          ])),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary), onPressed: () {
            final state = context.findAncestorStateOfType<_AdminPanelScreenState>();
            state?._showInstructionForm(context, instr);
          }),
          IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20), onPressed: () => _confirmDelete(context, ref, instr.id, instr.title)),
        ]),
      );
    });
  }
  void _confirmDelete(BuildContext ctx, WidgetRef ref, String id, String name) {
    final l = ref.read(l10nProvider);
    showDialog(context: ctx, builder: (_) => AlertDialog(
      title: Text(l.deleteConfirm), content: Text(name),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.no)), ElevatedButton(onPressed: () async { if (await runUiAction(ctx, ref, () => _fb.deleteInstruction(id)) && ctx.mounted) Navigator.pop(ctx); }, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error), child: Text(l.yes))],
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════
class _DrawingsTab extends ConsumerWidget {
  const _DrawingsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(drawingsProvider);
    if (items.isEmpty) return const Center(child: Text('—'));
    return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), itemCount: items.length, itemBuilder: (_, i) {
      final d = items[i];
      return GlassCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          const GlassIconTile(icon: Icons.architecture_outlined, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text('${d.number} • ${d.category}', style: Theme.of(context).textTheme.bodySmall),
          ])),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary), onPressed: () {
            final state = context.findAncestorStateOfType<_AdminPanelScreenState>();
            state?._showDrawingForm(context, d);
          }),
          IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20), onPressed: () => _confirmDelete(context, ref, d.id, d.title)),
        ]),
      );
    });
  }
  void _confirmDelete(BuildContext ctx, WidgetRef ref, String id, String name) {
    final l = ref.read(l10nProvider);
    showDialog(context: ctx, builder: (_) => AlertDialog(
      title: Text(l.deleteConfirm), content: Text(name),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.no)), ElevatedButton(onPressed: () async { if (await runUiAction(ctx, ref, () => _fb.deleteDrawing(id)) && ctx.mounted) Navigator.pop(ctx); }, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error), child: Text(l.yes))],
    ));
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// AUDIT LOG TAB
// ═══════════════════════════════════════════════════════════════════════════════
final _auditProvider = StreamProvider<List<AuditEntry>>((ref) => _fb.auditLogStream());

class _AuditLogTab extends ConsumerWidget {
  const _AuditLogTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audit = ref.watch(_auditProvider);
    return audit.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (entries) {
        if (entries.isEmpty) return const Center(child: Text('—'));
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: entries.length,
          itemBuilder: (_, i) {
            final e = entries[i];
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                GlassIconTile(icon: _actionIcon(e.action), color: _actionColor(e.action), size: 40),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${e.userName} • ${e.action.name}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.ink)),
                  const SizedBox(height: 2),
                  Text('${e.targetType}: ${e.targetName}', style: Theme.of(context).textTheme.bodySmall),
                ])),
                const SizedBox(width: 8),
                Text(
                  '${e.createdAt.day.toString().padLeft(2, '0')}.${e.createdAt.month.toString().padLeft(2, '0')} ${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.inkFaint),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  static Color _actionColor(AuditAction a) {
    switch (a) {
      case AuditAction.add: return AppTheme.success;
      case AuditAction.edit: return AppTheme.primary;
      case AuditAction.delete: return AppTheme.error;
      case AuditAction.ban: return AppTheme.error;
      case AuditAction.unban: return AppTheme.success;
      case AuditAction.approve: return AppTheme.success;
      case AuditAction.decline: return AppTheme.warning;
      case AuditAction.changeRole: return AppTheme.accent;
    }
  }

  static IconData _actionIcon(AuditAction a) {
    switch (a) {
      case AuditAction.add: return Icons.add_circle_outline;
      case AuditAction.edit: return Icons.edit_outlined;
      case AuditAction.delete: return Icons.delete_outline;
      case AuditAction.ban: return Icons.block;
      case AuditAction.unban: return Icons.check_circle_outline;
      case AuditAction.approve: return Icons.how_to_reg;
      case AuditAction.decline: return Icons.person_off_outlined;
      case AuditAction.changeRole: return Icons.swap_horiz;
    }
  }
}
