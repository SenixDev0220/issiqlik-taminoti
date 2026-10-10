import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'l10n.dart';
import 'firestore_sync_tracker.dart';

/// Extra scroll padding so content is not hidden behind [GlassBottomNav].
const double kBottomNavSpace = 110;

/// Mint gradient backdrop with soft teal glow blobs. Wrap every screen in it
/// (via [GlassScaffold]) so translucent surfaces read as glass.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF1FAF7), Color(0xFFDCEFE9), Color(0xFFC3E3DA)],
              ),
            ),
          ),
        ),
        Positioned(top: -90, right: -70, child: _blob(260, const Color(0xFF5EC6B4))),
        Positioned(top: 190, left: -110, child: _blob(240, const Color(0xFF8FD8CA))),
        Positioned(bottom: -60, right: -40, child: _blob(220, const Color(0xFF5EC6B4))),
        child,
      ],
    );
  }

  static Widget _blob(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Frosted glass card. The backdrop is a static gradient, so real blur is
/// unnecessary for cards — translucent white + hairline border reads the same
/// and stays cheap in long lists.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 22,
    this.onTap,
    this.onLongPress,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Optional wash of color over the glass (e.g. warning cards).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: AppTheme.glassBorder, width: 1),
    );
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x141B5E55), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Material(
        color: tint == null ? AppTheme.glassFill : Color.alphaBlend(tint!.withValues(alpha: 0.10), AppTheme.glassFill),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Rounded-square tinted icon plate used at the start of list cards.
class GlassIconTile extends StatelessWidget {
  const GlassIconTile({super.key, required this.icon, this.color = AppTheme.primary, this.size = 46});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Pill status chip (Faol / Ogohlantirish / Nosoz...). Pass a dark-enough
/// color: it is used for text, icon, and (faded) fill.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Glass search pill.
class GlassSearchField extends StatelessWidget {
  const GlassSearchField({super.key, this.controller, this.hint, this.onChanged});

  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }
}

/// Top-level tabs shown in the floating bottom bar.
enum AppTab { home, boilerhouses, journal, profile }

/// Floating glass bottom navigation with a springy active-tab indicator.
class GlassBottomNav extends ConsumerWidget {
  const GlassBottomNav({super.key, required this.current, this.onFab});

  final AppTab current;

  /// Center "+" action. Defaults to opening the journal.
  final VoidCallback? onFab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(ref.watch(selectedLanguageProvider));
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.72),
                    Colors.white.withValues(alpha: 0.48),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const fabWidth = 68.0;
                  const indicatorWidth = 54.0;
                  final itemWidth = (constraints.maxWidth - fabWidth) / 4;
                  final selectedIndex = switch (current) {
                    AppTab.home => 0,
                    AppTab.boilerhouses => 1,
                    AppTab.journal => 2,
                    AppTab.profile => 3,
                  };
                  final selectedLeft = selectedIndex < 2
                      ? selectedIndex * itemWidth
                      : 2 * itemWidth + fabWidth + (selectedIndex - 2) * itemWidth;

                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.elasticOut,
                        left: selectedLeft + (itemWidth - indicatorWidth) / 2,
                        top: 10,
                        width: indicatorWidth,
                        height: 50,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.accent.withValues(alpha: 0.22),
                                  AppTheme.primary.withValues(alpha: 0.10),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _item(context, Icons.home_rounded, l.navHome, '/home', AppTab.home),
                          _item(context, Icons.factory_outlined, l.navBoilerhouses, '/boilerhouses', AppTab.boilerhouses),
                          _fab(context),
                          _item(context, Icons.menu_book_rounded, l.navJournal, '/journal', AppTab.journal),
                          _item(context, Icons.person_rounded, l.navProfile, '/profile', AppTab.profile),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, String route, AppTab tab) {
    final selected = tab == current;
    final color = selected ? AppTheme.primary : const Color(0xFF5E7F7A);
    return Expanded(
      child: InkResponse(
        onTap: selected ? null : () => context.go(route),
        radius: 34,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fab(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Center(
        child: GestureDetector(
          onTap: onFab ?? () => context.go('/journal'),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.accent, AppTheme.primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

/// Standard screen shell: gradient backdrop, transparent scaffold, optional
/// glass app bar and bottom navigation. Screens should use this instead of a
/// bare [Scaffold].
class GlassScaffold extends ConsumerWidget {
  const GlassScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.appBar,
    this.tab,
    this.onFab,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;

  /// Escape hatch for fully custom app bars.
  final PreferredSizeWidget? appBar;

  /// When set, shows the floating [GlassBottomNav] with this tab active.
  final AppTab? tab;
  final VoidCallback? onFab;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(firestoreSyncStateProvider).valueOrNull;
    final language = AppL10n.of(ref.watch(selectedLanguageProvider));
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: appBar ??
            ((title != null || titleWidget != null)
                ? AppBar(title: titleWidget ?? Text(title!), actions: actions, leading: leading)
                : null),
        body: Column(
          children: [
            if (syncState != null &&
                syncState.status != FirestoreSyncStatus.checking &&
                syncState.status != FirestoreSyncStatus.synced)
              _FirestoreSyncBanner(state: syncState, l10n: language),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: tab == null ? null : GlassBottomNav(current: tab!, onFab: onFab),
      ),
    );
  }
}

class _FirestoreSyncBanner extends StatelessWidget {
  const _FirestoreSyncBanner({required this.state, required this.l10n});

  final FirestoreSyncState state;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    final (message, color, icon) = switch (state.status) {
      FirestoreSyncStatus.checking => (
          l10n.syncChecking,
          AppTheme.inkSoft,
          Icons.sync,
        ),
      FirestoreSyncStatus.offline => (
          l10n.syncOffline(state.pendingWrites),
          AppTheme.warning,
          Icons.cloud_off,
        ),
      FirestoreSyncStatus.syncing => (
          l10n.syncPending(state.pendingWrites),
          AppTheme.primary,
          Icons.cloud_sync,
        ),
      FirestoreSyncStatus.synced => (
          '',
          AppTheme.success,
          Icons.cloud_done,
        ),
      FirestoreSyncStatus.error => (
          l10n.syncError,
          AppTheme.error,
          Icons.error_outline,
        ),
    };

    return Material(
      color: color.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (state.status == FirestoreSyncStatus.error)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: l10n.cancel,
                onPressed: FirestoreSyncTracker.instance.clearError,
                icon: Icon(Icons.close, size: 16, color: color),
              ),
          ],
        ),
      ),
    );
  }
}
