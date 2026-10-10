import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../domain/models/instruction.dart';
import '../auth/auth_providers.dart';
import 'instructions_providers.dart';

class InstructionsScreen extends ConsumerWidget {
  const InstructionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instructions = ref.watch(instructionsProvider);
    final l = ref.watch(l10nProvider);
    final categories = instructions.map((i) => i.category).toSet().toList();

    return GlassScaffold(
      title: l.instructionsTitle,
      leading: BackButton(onPressed: () => context.go('/home')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: categories.length,
        itemBuilder: (context, catIndex) {
          final category = categories[catIndex];
          final catItems = instructions.where((i) => i.category == category).toList();
          return GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              iconColor: AppTheme.primary,
              collapsedIconColor: AppTheme.inkFaint,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              leading: const GlassIconTile(icon: Icons.folder_outlined, size: 40),
              title: Text(category, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(
                '${catItems.length} ${l.instructionsCount}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              children: catItems.map((instr) => ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const GlassIconTile(icon: Icons.description_outlined, size: 40),
                title: Text(instr.title, style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(
                  '${l.instructionsVersion} ${instr.version}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: instr.urgency == InstructionUrgency.mandatory
                    ? StatusChip(label: l.instructionsMandatory, color: AppTheme.error)
                    : const Icon(Icons.chevron_right_rounded, color: AppTheme.inkFaint),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => InstructionDetailScreen(instruction: instr)),
                ),
              )).toList(),
            ),
          );
        },
      ),
    );
  }
}

class InstructionDetailScreen extends ConsumerWidget {
  final Instruction instruction;
  const InstructionDetailScreen({super.key, required this.instruction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final textTheme = Theme.of(context).textTheme;
    return GlassScaffold(
      titleWidget: Text(instruction.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          icon: const Icon(Icons.bookmark_border, color: AppTheme.primary),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.instructionsFavorite)),
          ),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatusChip(
                label: '${l.instructionsVersion} ${instruction.version}',
                color: AppTheme.primary,
              ),
              if (instruction.urgency == InstructionUrgency.mandatory)
                StatusChip(
                  label: l.instructionsMandatory,
                  color: AppTheme.error,
                  icon: Icons.priority_high_rounded,
                ),
            ]),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.category_outlined, size: 16, color: AppTheme.inkFaint),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l.instructionsCategory}: ${instruction.category}',
                          style: textTheme.bodyMedium?.copyWith(color: AppTheme.inkSoft),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.update_rounded, size: 16, color: AppTheme.inkFaint),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l.instructionsUpdated}: ${instruction.updatedAt.day.toString().padLeft(2, '0')}.${instruction.updatedAt.month.toString().padLeft(2, '0')}.${instruction.updatedAt.year}',
                          style: textTheme.bodyMedium?.copyWith(color: AppTheme.inkSoft),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Text(
                instruction.body,
                style: textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
