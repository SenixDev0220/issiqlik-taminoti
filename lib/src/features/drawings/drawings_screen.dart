import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../domain/models/drawing.dart';
import '../auth/auth_providers.dart';
import 'drawings_providers.dart';

class DrawingsScreen extends ConsumerWidget {
  const DrawingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawings = ref.watch(drawingsProvider);
    final l = ref.watch(l10nProvider);

    return GlassScaffold(
      title: l.drawingsTitle,
      leading: BackButton(onPressed: () => context.go('/home')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: drawings.length,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, i) {
          final d = drawings[i];
          return GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _DrawingViewScreen(drawing: d))),
            child: Row(
              children: [
                const GlassIconTile(icon: Icons.architecture),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        d.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.inkFaint),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DrawingViewScreen extends ConsumerWidget {
  final Drawing drawing;
  const _DrawingViewScreen({required this.drawing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassScaffold(
      title: drawing.title,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GlassIconTile(icon: Icons.lock_outline, size: 72),
              const SizedBox(height: 16),
              Text(drawing.title, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              if (drawing.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(drawing.description, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              GlassCard(
                tint: AppTheme.warning,
                child: Text(ref.watch(l10nProvider).secureMediaUnavailable),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
