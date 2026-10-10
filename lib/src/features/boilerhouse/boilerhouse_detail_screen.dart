import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../domain/models/boiler_house.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/change_log.dart';
import '../../services/firebase_service.dart';
import '../auth/auth_providers.dart';
import 'boilerhouse_providers.dart';

final _fb = FirebaseService.instance;

final _changeLogsProvider = StreamProvider.family<List<ChangeLogEntry>, String>((ref, bhId) {
  return _fb.changeLogsStream(bhId);
});

final _reactionsProvider = StreamProvider.family<List<ChangeLogReaction>, String>((ref, changeLogId) {
  return _fb.reactionsStream(changeLogId);
});

Color _statusColor(BoilerHouseStatus status) {
  switch (status) {
    case BoilerHouseStatus.operating:
      return AppTheme.success;
    case BoilerHouseStatus.maintenance:
      return AppTheme.warning;
    case BoilerHouseStatus.emergencyShutdown:
      return AppTheme.error;
    case BoilerHouseStatus.mothballed:
      return AppTheme.inkFaint;
  }
}

class BoilerHouseDetailScreen extends ConsumerWidget {
  const BoilerHouseDetailScreen({super.key, required this.boilerHouseId});
  final String boilerHouseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bh = ref.watch(selectedBoilerHouseProvider(boilerHouseId));
    final l = ref.watch(l10nProvider);

    if (bh == null) {
      return GlassScaffold(
        title: l.boilerhouseDetailTitle,
        leading: BackButton(onPressed: () => context.pop()),
        body: Center(child: Text(l.boilerhouseNotFound)),
      );
    }

    return GlassScaffold(
      title: bh.name,
      leading: BackButton(onPressed: () => context.pop()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Header ──
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bh.name, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                Row(
                  children: [
                    StatusChip(label: bh.status.label(l), color: _statusColor(bh.status)),
                  ],
                ),
                if (bh.address.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.inkSoft),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(bh.address, style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          _Section(title: l.sectionMainInfo, children: [
            _Row(label: l.fieldAddress, value: bh.address),
            _Row(label: l.fieldYearBuiltDetail, value: bh.yearBuilt > 0 ? '${bh.yearBuilt}' : '—'),
            if (bh.modernizationYear > 0) _Row(label: l.fieldModernization, value: '${bh.modernizationYear}'),
            _Row(label: l.fieldTotalArea, value: '${bh.totalArea} ${l.unitM2}'),
            _Row(label: l.fieldWorkers, value: '${bh.workersCount} ${l.unitPcs}'),
            if (bh.operatorsCount > 0) _Row(label: l.fieldOperators, value: '${bh.operatorsCount} ${l.unitPcs}'),
          ]),

          _Section(title: l.sectionCapacity, children: [
            _Row(label: l.fieldInstalledCapacity, value: '${bh.installedCapacity} ${l.unitGcal}'),
            _Row(label: l.fieldConnectedLoad, value: '${bh.connectedLoad} ${l.unitGcal}'),
            if (bh.consumers.isNotEmpty) _Row(label: l.fieldConsumers, value: bh.consumers),
          ]),

          _Section(title: l.sectionPipelines, children: [
            _Row(label: l.fieldTotalLength, value: '${bh.pipelineLength} ${l.unitKm}'),
            if (bh.aboveGroundPipeline > 0) _Row(label: l.fieldAboveGround, value: '${bh.aboveGroundPipeline} ${l.unitKm}'),
            if (bh.belowGroundPipeline > 0) _Row(label: l.fieldBelowGround, value: '${bh.belowGroundPipeline} ${l.unitKm}'),
          ]),

          _Section(title: l.sectionAnnualConsumption, children: [
            if (bh.annualElectricity > 0) _Row(label: l.fieldElectricity, value: '${bh.annualElectricity.toInt()} ${l.unitKw}'),
            if (bh.annualWater > 0) _Row(label: l.fieldColdWater, value: '${bh.annualWater.toInt()} ${l.unitM3}'),
            if (bh.annualGas > 0) _Row(label: l.fieldNaturalGas, value: '${bh.annualGas.toInt()} ${l.unitM3}'),
            if (bh.annualHeatProduction > 0) _Row(label: l.fieldHeatProduction, value: '${bh.annualHeatProduction.toInt()} Гкал'),
          ]),

          if (bh.dispatchPhone.isNotEmpty || bh.defects.isNotEmpty)
            _Section(title: l.sectionAdditional, children: [
              if (bh.dispatchPhone.isNotEmpty) _Row(label: l.fieldDispatchPhone, value: bh.dispatchPhone),
              if (bh.defects.isNotEmpty) _Row(label: l.fieldDefects, value: bh.defects),
            ]),

          if (bh.locationUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(bh.locationUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(l.openOnMap),
                ),
              ),
            ),

          const Divider(height: 32),

          // ── Changes Log Section ──
          _ChangeLogSection(boilerHouseId: boilerHouseId),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════
class _ChangeLogSection extends ConsumerStatefulWidget {
  final String boilerHouseId;
  const _ChangeLogSection({required this.boilerHouseId});
  @override
  ConsumerState<_ChangeLogSection> createState() => _ChangeLogSectionState();
}

class _ChangeLogSectionState extends ConsumerState<_ChangeLogSection> {
  bool _showForm = false;
  final _titleC = TextEditingController();
  final _textC = TextEditingController();

  @override
  void dispose() { _titleC.dispose(); _textC.dispose(); super.dispose(); }

  void _submit() {
    final user = ref.read(currentUserProvider);
    if (_titleC.text.trim().isEmpty || user == null) return;
    _fb.addChangeLog(ChangeLogEntry(
      id: 'cl-${DateTime.now().millisecondsSinceEpoch}',
      boilerHouseId: widget.boilerHouseId,
      title: _titleC.text.trim(),
      text: _textC.text.trim(),
      authorId: user.id,
      authorName: user.fullName,
      createdAt: DateTime.now(),
    ));
    _titleC.clear(); _textC.clear();
    setState(() => _showForm = false);
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(_changeLogsProvider(widget.boilerHouseId));
    final user = ref.watch(currentUserProvider);
    final l = ref.watch(l10nProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              l.changeLogTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink),
            ),
          ),
          if (user != null)
            IconButton(
              icon: Icon(_showForm ? Icons.close : Icons.add_circle_outline, color: AppTheme.primary),
              onPressed: () => setState(() => _showForm = !_showForm),
            ),
        ]),
        const SizedBox(height: 8),

        if (_showForm) ...[
          GlassCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(controller: _titleC, decoration: InputDecoration(labelText: '${l.changeLogHeading} *', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: _textC, maxLines: 3, decoration: InputDecoration(labelText: l.changeLogDescription, isDense: true, alignLabelWithHint: true)),
                const SizedBox(height: 8),
                // Photo upload disabled
                ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send, size: 18),
                  label: Text(l.changeLogSubmit),
                ),
              ],
            ),
          ),
        ],

        // Log entries
        logs.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          error: (e, _) => Text('${l.changeLogError}: $e', style: const TextStyle(color: AppTheme.error)),
          data: (entries) {
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l.changeLogEmpty, style: const TextStyle(color: AppTheme.inkFaint)),
              );
            }
            return Column(children: entries.map((e) => _ChangeLogCard(entry: e)).toList());
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHANGE LOG CARD with reactions
// ═══════════════════════════════════════════════════════════════════════════════
class _ChangeLogCard extends ConsumerStatefulWidget {
  final ChangeLogEntry entry;
  const _ChangeLogCard({required this.entry});
  @override
  ConsumerState<_ChangeLogCard> createState() => _ChangeLogCardState();
}

class _ChangeLogCardState extends ConsumerState<_ChangeLogCard> {
  bool _showReactions = false;
  bool _showReplyField = false;
  final _replyC = TextEditingController();

  @override
  void dispose() { _replyC.dispose(); super.dispose(); }

  void _sendReaction() {
    final user = ref.read(currentUserProvider);
    if (_replyC.text.trim().isEmpty || user == null) return;
    _fb.addReaction(ChangeLogReaction(
      id: 'r-${DateTime.now().millisecondsSinceEpoch}',
      changeLogId: widget.entry.id,
      text: _replyC.text.trim(),
      authorId: user.id,
      authorName: user.fullName,
      createdAt: DateTime.now(),
    ));
    _replyC.clear();
    setState(() => _showReplyField = false);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final user = ref.watch(currentUserProvider);
    final isOwner = user?.id == e.authorId;
    final isAdmin = user?.role == UserRole.admin || user?.role == UserRole.coAdmin;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.14),
            child: Text(
              e.authorName.isNotEmpty ? e.authorName[0] : '?',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.authorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.ink)),
            Text(_formatDate(e.createdAt), style: const TextStyle(fontSize: 11, color: AppTheme.inkFaint)),
          ])),
          if (isOwner || isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
              onPressed: () => _fb.deleteChangeLog(e.id),
            ),
        ]),
        const SizedBox(height: 8),
        Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.ink)),
        if (e.text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(e.text, style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.inkSoft)),
        ],

        // Actions row
        const SizedBox(height: 8),
        Row(children: [
          InkWell(
            onTap: () => setState(() { _showReactions = !_showReactions; }),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.chat_bubble_outline, size: 16, color: AppTheme.inkSoft),
              const SizedBox(width: 4),
              Text(ref.watch(l10nProvider).comments, style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft)),
            ]),
          ),
          const SizedBox(width: 16),
          if (user != null)
            InkWell(
              onTap: () => setState(() => _showReplyField = !_showReplyField),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.reply, size: 16, color: AppTheme.inkSoft),
                const SizedBox(width: 4),
                Text(ref.watch(l10nProvider).reply, style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft)),
              ]),
            ),
        ]),

        // Reply field
        if (_showReplyField) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _replyC,
                decoration: InputDecoration(
                  hintText: ref.watch(l10nProvider).commentHint,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.send, size: 18, color: AppTheme.primary), onPressed: _sendReaction),
          ]),
        ],

        // Reactions list
        if (_showReactions) _ReactionsList(changeLogId: e.id),
      ]),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ═══════════════════════════════════════════════════════════════════════════════
// REACTIONS LIST
// ═══════════════════════════════════════════════════════════════════════════════
class _ReactionsList extends ConsumerWidget {
  final String changeLogId;
  const _ReactionsList({required this.changeLogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactions = ref.watch(_reactionsProvider(changeLogId));
    return reactions.when(
      loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
      error: (e, _) => Text('$e', style: const TextStyle(color: AppTheme.error, fontSize: 12)),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(ref.watch(l10nProvider).noComments, style: const TextStyle(fontSize: 12, color: AppTheme.inkFaint)),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(children: items.map((r) => _ReactionTile(reaction: r, changeLogId: changeLogId)).toList()),
        );
      },
    );
  }
}

class _ReactionTile extends ConsumerWidget {
  final ChangeLogReaction reaction;
  final String changeLogId;
  const _ReactionTile({required this.reaction, required this.changeLogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final canDelete = user?.id == reaction.authorId ||
        user?.role == UserRole.admin ||
        user?.role == UserRole.coAdmin;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.subdirectory_arrow_right, size: 14, color: AppTheme.inkFaint),
        const SizedBox(width: 4),
        Expanded(child: RichText(text: TextSpan(style: const TextStyle(fontSize: 12, color: AppTheme.ink), children: [
          TextSpan(text: '${reaction.authorName}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: reaction.text),
        ]))),
        if (canDelete)
          GestureDetector(
            onTap: () => _fb.deleteReaction(changeLogId, reaction.id),
            child: const Icon(Icons.close, size: 14, color: AppTheme.inkFaint),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.ink)),
          const SizedBox(height: 8),
          ...children,
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 2, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.inkSoft, fontSize: 13))),
      Expanded(flex: 3, child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.ink))),
    ]));
  }
}
