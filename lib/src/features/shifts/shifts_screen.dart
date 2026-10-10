import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../core/l10n.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/boiler_house.dart';
import '../../domain/models/shift.dart';
import '../../services/firebase_service.dart';
import '../auth/auth_providers.dart';
import '../boilerhouse/boilerhouse_providers.dart';
import 'shifts_providers.dart';

// -- Shared helpers -----------------------------------------------------------

Color _shiftColor(ShiftType t) => t == ShiftType.day ? AppTheme.warning : AppTheme.primary;

IconData _shiftIcon(ShiftType t) =>
    t == ShiftType.day ? Icons.wb_sunny_outlined : Icons.nightlight_outlined;

String _shiftLabel(AppL10n l, ShiftType t) => t == ShiftType.day ? l.shiftDay : l.shiftNight;

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _ddMm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

/// Uzbek weekday + date, both scripts (same approach as home_screen.dart).
String _dayLabelUz(AppL10n l, DateTime d) {
  const monthsCyrl = ['январ', 'феврал', 'март', 'апрел', 'май', 'июн', 'июл', 'август', 'сентябр', 'октябр', 'ноябр', 'декабр'];
  const monthsLatn = ['yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun', 'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr'];
  const daysCyrl = ['Душанба', 'Сешанба', 'Чоршанба', 'Пайшанба', 'Жума', 'Шанба', 'Якшанба'];
  const daysLatn = ['Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba'];
  final months = l.isCyrl ? monthsCyrl : monthsLatn;
  final days = l.isCyrl ? daysCyrl : daysLatn;
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
}

// -- Screen -------------------------------------------------------------------

class ShiftsScreen extends ConsumerStatefulWidget {
  const ShiftsScreen({super.key});

  @override
  ConsumerState<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends ConsumerState<ShiftsScreen> {
  /// Monday (date-only) of the currently shown week.
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = weekStartOf(DateTime.now());
  }

  void _moveWeek(int deltaDays) {
    setState(() {
      _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + deltaDays);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final user = ref.watch(currentUserProvider);
    final canManage = user?.role == UserRole.admin || user?.role == UserRole.coAdmin;
    final shiftsAsync = ref.watch(weekShiftsProvider(_weekStart));
    final weekEnd = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 6);

    return GlassScaffold(
      title: l.shiftsTitle,
      floatingActionButton: canManage
          ? FloatingActionButton(
              tooltip: l.shiftAdd,
              onPressed: () => _showAddSheet(context),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.primary),
                    onPressed: () => _moveWeek(-7),
                  ),
                  Expanded(
                    child: Text(
                      '${_ddMm(_weekStart)} – ${_ddMm(weekEnd)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.ink),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
                    onPressed: () => _moveWeek(7),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildWeekBody(l, shiftsAsync, user, canManage)),
        ],
      ),
    );
  }

  Widget _buildWeekBody(AppL10n l, AsyncValue<List<Shift>> shiftsAsync, AppUser? user, bool canManage) {
    if (shiftsAsync.isLoading && !shiftsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final shifts = shiftsAsync.valueOrNull ?? const <Shift>[];
    if (shifts.isEmpty) return _EmptyWeek(l: l);

    final children = <Widget>[];
    final today = DateTime.now();
    for (var i = 0; i < 7; i++) {
      final day = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + i);
      final dayShifts = shifts.where((s) => _sameDay(s.date, day)).toList()
        ..sort((a, b) => a.type.index.compareTo(b.type.index));
      if (dayShifts.isEmpty) continue;

      final isToday = _sameDay(day, today);
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(
          _dayLabelUz(l, day),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isToday ? AppTheme.primary : AppTheme.inkSoft,
          ),
        ),
      ));
      children.addAll(dayShifts.map((s) => _ShiftCard(
            shift: s,
            l: l,
            isMine: user != null && s.operatorId == user.id,
            canDelete: canManage,
          )));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: children,
    );
  }

  void _showAddSheet(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEndExclusive = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7);
    final inWeek = !today.isBefore(_weekStart) && today.isBefore(weekEndExclusive);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ShiftSheet(initialDate: inWeek ? today : _weekStart),
    );
  }
}

// -- Empty state --------------------------------------------------------------

class _EmptyWeek extends StatelessWidget {
  final AppL10n l;
  const _EmptyWeek({required this.l});

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
            child: const Icon(Icons.calendar_month_outlined, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(l.shiftEmpty, style: const TextStyle(fontSize: 16, color: AppTheme.inkSoft)),
        ],
      ),
    );
  }
}

// -- Shift card ---------------------------------------------------------------

class _ShiftCard extends StatelessWidget {
  final Shift shift;
  final AppL10n l;
  final bool isMine;
  final bool canDelete;

  const _ShiftCard({
    required this.shift,
    required this.l,
    required this.isMine,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _shiftColor(shift.type);
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      onLongPress: canDelete ? () => _confirmDelete(context) : null,
      child: Row(
        children: [
          GlassIconTile(icon: _shiftIcon(shift.type), color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.operatorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(color: AppTheme.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  shift.boilerHouseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: AppTheme.inkSoft),
                ),
                if (shift.note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    shift.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: AppTheme.inkFaint, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(label: _shiftLabel(l, shift.type), color: color),
              if (isMine) ...[
                const SizedBox(height: 5),
                StatusChip(label: l.shiftMineBadge, color: AppTheme.accent, icon: Icons.person_rounded),
              ],
            ],
          ),
          if (canDelete)
            SizedBox(
              width: 32,
              height: 32,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.inkFaint),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                itemBuilder: (_) => [
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
                  if (value == 'delete') _confirmDelete(context);
                },
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        content: Text(l.shiftDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () {
              // Firestore's offline queue handles delivery; rules violations
              // can't happen here because the delete UI is admin-only.
              FirebaseService.instance.deleteShift(shift.id).catchError((_) {});
              Navigator.pop(dialogCtx);
            },
            child: Text(l.journalDelete),
          ),
        ],
      ),
    );
  }
}

// -- Add shift sheet ----------------------------------------------------------

class _ShiftSheet extends ConsumerStatefulWidget {
  final DateTime initialDate;
  const _ShiftSheet({required this.initialDate});

  @override
  ConsumerState<_ShiftSheet> createState() => _ShiftSheetState();
}

class _ShiftSheetState extends ConsumerState<_ShiftSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  ShiftType _type = ShiftType.day;
  String? _boilerHouseId;
  String? _operatorId;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    BoilerHouse? house;
    for (final h in ref.read(boilerHouseListProvider)) {
      if (h.id == _boilerHouseId) {
        house = h;
        break;
      }
    }
    AppUser? op;
    for (final u in ref.read(activeUsersProvider)) {
      if (u.id == _operatorId) {
        op = u;
        break;
      }
    }
    if (house == null || op == null) return;

    setState(() => _saving = true);
    final shift = Shift(
      id: 'sh-${DateTime.now().millisecondsSinceEpoch}',
      boilerHouseId: house.id,
      boilerHouseName: house.name,
      operatorId: op.id,
      operatorName: '${op.firstName} ${op.lastName}',
      date: DateTime(_date.year, _date.month, _date.day),
      type: _type,
      note: _noteCtrl.text.trim(),
      createdBy: user.id,
      createdAt: DateTime.now(),
    );
    FirebaseService.instance.addShift(shift);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final houses = ref.watch(boilerHouseListProvider);
    final operators = ref.watch(activeUsersProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.inkFaint.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(l.shiftAdd, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),

              // Date
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    '${_dayLabelUz(l, _date)} ${_date.year}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.ink),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Day / night
              SegmentedButton<ShiftType>(
                segments: [
                  ButtonSegment(
                    value: ShiftType.day,
                    label: Text(l.shiftDay),
                    icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: ShiftType.night,
                    label: Text(l.shiftNight),
                    icon: const Icon(Icons.nightlight_outlined, size: 18),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),

              // Boiler house
              DropdownButtonFormField<String>(
                initialValue: _boilerHouseId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l.navBoilerhouses,
                  prefixIcon: const Icon(Icons.factory_outlined),
                ),
                items: houses
                    .map((h) => DropdownMenuItem(
                          value: h.id,
                          child: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _boilerHouseId = v),
                validator: (v) => v == null ? l.fieldRequired : null,
              ),
              const SizedBox(height: 12),

              // Operator
              DropdownButtonFormField<String>(
                initialValue: _operatorId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l.shiftOperator,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                items: operators
                    .map((u) => DropdownMenuItem(
                          value: u.id,
                          child: Text('${u.firstName} ${u.lastName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _operatorId = v),
                validator: (v) => v == null ? l.fieldRequired : null,
              ),
              const SizedBox(height: 12),

              // Note (optional)
              TextFormField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l.shiftNote,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Icon(Icons.notes),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(l.save),
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
