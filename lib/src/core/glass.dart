import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'l10n.dart';
import 'firestore_sync_tracker.dart';

/// Extra scroll padding so content is not hidden behind [GlassBottomNav].
const double kBottomNavSpace = 110;
const double kMaxScreenContentWidth = 760;

/// Keep controls readable rather than shrinking the user's chosen text size.
/// The children retain their natural height; unlike aspect-ratio grids this
/// also works with translated labels, validation errors and large text.
class ResponsiveWrap extends StatelessWidget {
  const ResponsiveWrap({
    super.key,
    required this.children,
    this.minChildWidth = 200,
    this.maxColumns = 2,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double minChildWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = ((constraints.maxWidth + spacing) /
              (minChildWidth * textScale.clamp(1.0, 2.0) + spacing))
          .floor()
          .clamp(1, maxColumns);
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

bool _reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.accessibleNavigationOf(context) ||
    !TickerMode.valuesOf(context).enabled;

/// Await the server before closing forms or reporting success. Duplicate taps
/// on the same mounted surface are ignored; backend errors are never displayed
/// verbatim (they may contain identifiers or transport details).
final _pendingUiActions = <BuildContext>{};

Future<bool> runUiAction(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  if (!_pendingUiActions.add(context)) return false;
  try {
    await action();
    return context.mounted;
  } catch (error) {
    if (context.mounted) {
      final l = AppL10n.of(ref.read(selectedLanguageProvider));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is UnsupportedError ? l.operatorAssistance : l.syncError),
      ));
    }
    return false;
  } finally {
    // Removing an identity key does not access a disposed context.
    // ignore: use_build_context_synchronously
    _pendingUiActions.remove(context);
  }
}

/// Cool aurora backdrop; static gradients keep glass surfaces cheap to paint.
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
                colors: [
                  Color(0xFFF7F8FE),
                  Color(0xFFE9EDFC),
                  Color(0xFFDCE8F8),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -70,
          child: _blob(280, const Color(0xFF7B8DF0)),
        ),
        Positioned(
          top: 190,
          left: -110,
          child: _blob(250, const Color(0xFF72D7E8)),
        ),
        Positioned(
          bottom: -60,
          right: -40,
          child: _blob(240, const Color(0xFF9C9AF2)),
        ),
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
            colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Frosted glass card with a lightweight highlight instead of per-frame blur.
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 24,
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
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(widget.radius),
      side: const BorderSide(color: AppTheme.glassBorder, width: 1),
    );
    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x104658D8),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: RepaintBoundary(
        child: AnimatedScale(
          scale:
              !_reduceMotion(context) &&
                  _pressed && (widget.onTap != null || widget.onLongPress != null)
              ? 0.985
              : 1,
          duration: _reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 240),
          curve: Curves.elasticOut,
          child: Material(
            color: widget.tint == null
                ? AppTheme.glassFill
                : Color.alphaBlend(
                    widget.tint!.withValues(alpha: 0.10),
                    AppTheme.glassFill,
                  ),
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onHighlightChanged: (pressed) {
                if (_pressed != pressed) setState(() => _pressed = pressed);
              },
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.24),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
                ),
                child: Padding(padding: widget.padding, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded-square tinted icon plate used at the start of list cards.
class GlassIconTile extends StatelessWidget {
  const GlassIconTile({
    super.key,
    required this.icon,
    this.color = AppTheme.primary,
    this.size = 46,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Pill status chip (Faol / Ogohlantirish / Nosoz...). Pass a dark-enough
/// color: it is used for text, icon, and (faded) fill.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

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
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glass search pill.
class GlassSearchField extends StatelessWidget {
  const GlassSearchField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
  });

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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      ),
    );
  }
}

/// Top-level tabs shown in the floating bottom bar.
enum AppTab { home, boilerhouses, journal, profile }

AppTab? _pendingNavTransitionFrom;

/// Floating translucent navigation with a glass-inspired active-tab indicator.
class GlassBottomNav extends ConsumerStatefulWidget {
  const GlassBottomNav({super.key, required this.current, this.onFab});

  final AppTab current;

  /// Center "+" action. Defaults to opening the journal.
  final VoidCallback? onFab;

  @override
  ConsumerState<GlassBottomNav> createState() => _GlassBottomNavState();
}

class _GlassBottomNavState extends ConsumerState<GlassBottomNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _indicatorController;
  late final CurvedAnimation _indicatorAnimation;
  late int _fromIndex;
  late int _toIndex;

  @override
  void initState() {
    super.initState();
    _toIndex = _tabIndex(widget.current);
    _fromIndex = _tabIndex(_pendingNavTransitionFrom ?? widget.current);
    _pendingNavTransitionFrom = null;
    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _indicatorAnimation = CurvedAnimation(
      parent: _indicatorController,
      curve: Curves.elasticOut,
    );
    if (_fromIndex == _toIndex) {
      _indicatorController.value = 1;
    } else {
      _indicatorController.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) _indicatorController.value = 1;
  }

  @override
  void didUpdateWidget(covariant GlassBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _tabIndex(widget.current);
    if (nextIndex == _toIndex) return;
    _fromIndex = _toIndex;
    _toIndex = nextIndex;
    if (_reduceMotion(context)) {
      _indicatorController.value = 1;
    } else {
      _indicatorController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _indicatorAnimation.dispose();
    _indicatorController.dispose();
    super.dispose();
  }

  int _tabIndex(AppTab tab) => switch (tab) {
    AppTab.home => 0,
    AppTab.boilerhouses => 1,
    AppTab.journal => 2,
    AppTab.profile => 3,
  };

  void _navigate(BuildContext context, String route) {
    _pendingNavTransitionFrom = widget.current;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(ref.watch(selectedLanguageProvider));
    return Align(
      heightFactor: 1,
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxScreenContentWidth),
        child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: RepaintBoundary(
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xEBFFFFFF), Color(0xCFFFFFFF)],
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

                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 10,
                        width: indicatorWidth,
                        height: 50,
                        child: AnimatedBuilder(
                          animation: _indicatorAnimation,
                          child: const IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(22),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0x5C20B8D2),
                                    Color(0x384658D8),
                                  ],
                                ),
                                border: Border.fromBorderSide(
                                  BorderSide(color: Color(0xB8FFFFFF)),
                                ),
                              ),
                            ),
                          ),
                          builder: (context, child) {
                            final fromLeft = _tabLeft(
                              _fromIndex,
                              itemWidth,
                              fabWidth,
                            );
                            final toLeft = _tabLeft(
                              _toIndex,
                              itemWidth,
                              fabWidth,
                            );
                            final left =
                                fromLeft +
                                (toLeft - fromLeft) *
                                    _indicatorAnimation.value +
                                (itemWidth - indicatorWidth) / 2;
                            return Transform.translate(
                              offset: Offset(left, 0),
                              child: RepaintBoundary(child: child),
                            );
                          },
                        ),
                      ),
                      Row(
                        children: [
                          _item(
                            context,
                            Icons.home_rounded,
                            l.navHome,
                            '/home',
                            AppTab.home,
                          ),
                          _item(
                            context,
                            Icons.factory_outlined,
                            l.navBoilerhouses,
                            '/boilerhouses',
                            AppTab.boilerhouses,
                          ),
                          _fab(context),
                          _item(
                            context,
                            Icons.menu_book_rounded,
                            l.navJournal,
                            '/journal',
                            AppTab.journal,
                          ),
                          _item(
                            context,
                            Icons.person_rounded,
                            l.navProfile,
                            '/profile',
                            AppTab.profile,
                          ),
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
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    String route,
    AppTab tab,
  ) {
    final selected = tab == widget.current;
    final color = selected ? AppTheme.primary : AppTheme.inkFaint;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Tooltip(
          message: label,
          child: InkResponse(
            onTap: selected ? null : () => _navigate(context, route),
            radius: 34,
            child: SizedBox.expand(
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 24, color: color),
                    if (MediaQuery.textScalerOf(context).scale(10.5) <= 14) ...[
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _tabLeft(int index, double itemWidth, double fabWidth) {
    if (index < 2) return index * itemWidth;
    return 2 * itemWidth + fabWidth + (index - 2) * itemWidth;
  }

  Widget _fab(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Center(
        child: Semantics(
          button: true,
          label: AppL10n.of(ref.watch(selectedLanguageProvider)).navJournal,
          child: GestureDetector(
          onTap: widget.onFab ?? () => _navigate(context, '/journal'),
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
        appBar:
            appBar ??
            ((title != null || titleWidget != null)
                ? AppBar(
                    toolbarHeight: 56 +
                        (MediaQuery.textScalerOf(context).scale(20) - 20)
                            .clamp(0.0, 24.0),
                    title: titleWidget ?? Text(title!, maxLines: 2, overflow: TextOverflow.ellipsis),
                    actions: actions,
                    leading: leading,
                  )
                : null),
        body: Column(
          children: [
            if (syncState != null &&
                syncState.status != FirestoreSyncStatus.checking &&
                syncState.status != FirestoreSyncStatus.synced)
              _FirestoreSyncBanner(state: syncState, l10n: language),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kMaxScreenContentWidth,
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: tab == null,
                    child: body,
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: tab == null
            ? null
            : GlassBottomNav(current: tab!, onFab: onFab),
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
      FirestoreSyncStatus.synced => ('', AppTheme.success, Icons.cloud_done),
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
