import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _DrawingViewScreen extends ConsumerStatefulWidget {
  final Drawing drawing;
  const _DrawingViewScreen({required this.drawing});

  @override
  ConsumerState<_DrawingViewScreen> createState() => _DrawingViewScreenState();
}

class _DrawingViewScreenState extends ConsumerState<_DrawingViewScreen> {
  bool _hasImage = false;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _checkImage();
  }

  Future<void> _checkImage() async {
    final baseName = widget.drawing.filePath.split('/').last.replaceAll('.xlsx', '');
    for (final ext in ['jpg', 'png']) {
      final p = 'assets/schemas/$baseName.$ext';
      try {
        await rootBundle.load(p);
        setState(() { _hasImage = true; _imagePath = p; });
        return;
      } catch (_) {}
    }
    setState(() => _hasImage = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      titleWidget: Text(widget.drawing.title, style: const TextStyle(fontSize: 15)),
      body: _hasImage && _imagePath != null
          ? InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(child: Image.asset(_imagePath!, fit: BoxFit.contain)),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const GlassIconTile(icon: Icons.architecture, size: 84, color: AppTheme.inkFaint),
                    const SizedBox(height: 16),
                    Text(
                      widget.drawing.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    GlassCard(
                      tint: AppTheme.warning,
                      child: Text(
                        ref.watch(l10nProvider).drawingComingSoon,
                        style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
