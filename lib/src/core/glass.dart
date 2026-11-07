import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_messages.dart';
import '../services/auth_result.dart';
import '../services/bounded_operations.dart';
import 'app_state.dart';
import 'app_theme.dart';
import 'data_quality.dart';
import 'l10n.dart';
import 'firestore_sync_tracker.dart';

final dataQualityProvider = StreamProvider<int>((ref) => DataQualityTracker.instance.stream);

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
      final message = error is AuthFlowException
          ? l.authFailure(error.failure)
          : error is PartialOperationException
          ? (l.isCyrl
              ? 'Амал қисман бажарилди ёки натижа ҳали номаълум. Рўйхатни янгиланг; хабарни кўр-кўрона қайта юборманг.'
              : 'Amal qisman bajarildi yoki natija hali noma’lum. Ro‘yxatni yangilang; xabarni ko‘r-ko‘rona qayta yubormang.')
          : error is UnsupportedError ? l.operatorAssistance : l.syncError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    final dark = AppTheme.isDark(context);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [Color(0xFF14182A), Color(0xFF1C2440), Color(0xFF142D3B)]
                    : const [Color(0xFFF7F8FE), Color(0xFFE9EDFC), Color(0xFFDCE8F8)],
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
    final dark = AppTheme.isDark(context);
    final fill = AppTheme.glassFillFor(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(widget.radius),
      side: BorderSide(color: AppTheme.glassBorderFor(context), width: 1),
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
                ? fill
                : Color.alphaBlend(
                    widget.tint!.withValues(alpha: 0.10),
                    fill,
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
                      Colors.white.withValues(alpha: dark ? 0.04 : 0.24),
                      Colors.white.withValues(alpha: dark ? 0 : 0.02),
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
    final color = AppTheme.adaptiveColor(context, this.color);
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
    final color = AppTheme.adaptiveColor(context, this.color);
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

// Scoped to a router, consumed only by the requested destination, and expired
// after its first frame. Redirects and unrelated navbars cannot inherit a lens.
final _navTransitions = Expando<_NavTransition>();

class _NavTransition {
  const _NavTransition({
    required this.fromRoute,
    required this.toRoute,
    required this.position,
    required this.velocity,
    required this.pressure,
    required this.pressureVelocity,
  });

  final String fromRoute;
  final String toRoute;
  final double position;
  final double velocity;
  final double pressure;
  final double pressureVelocity;
}

/// Floating glass navigation with a spring-driven, deformable liquid lens.
class GlassBottomNav extends ConsumerStatefulWidget {
  const GlassBottomNav({super.key, required this.current, this.onFab});

  final AppTab current;

  /// Center "+" action. Defaults to opening the journal.
  final VoidCallback? onFab;

  @override
  ConsumerState<GlassBottomNav> createState() => _GlassBottomNavState();
}

class _GlassBottomNavState extends ConsumerState<GlassBottomNav>
    with TickerProviderStateMixin {
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 330,
    damping: 30,
  );
  static const _pressSpring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 24,
  );
  static final _blur = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10);
  late final AnimationController _position;
  late final AnimationController _pressure;
  late double _target;
  bool _initialized = false;
  bool _motionDisabled = false;

  static double _slot(AppTab tab) =>
      (tab.index < 2 ? tab.index : tab.index + 1).toDouble();

  static String _route(AppTab tab) => switch (tab) {
    AppTab.home => '/home',
    AppTab.boilerhouses => '/boilerhouses',
    AppTab.journal => '/journal',
    AppTab.profile => '/profile',
  };

  @override
  void initState() {
    super.initState();
    _target = _slot(widget.current);
    // A direct route mount must start at its own tab, not the first tab.
    _position = AnimationController.unbounded(vsync: this, value: _target);
    _pressure = AnimationController.unbounded(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionDisabled = _reduceMotion(context);
    if (!_initialized) {
      _initialized = true;
      final router = GoRouter.maybeOf(context);
      final transition = router == null ? null : _navTransitions[router];
      if (transition != null &&
          transition.toRoute == _route(widget.current) &&
          router!.routeInformationProvider.value.uri.path == transition.toRoute) {
        _navTransitions[router] = null;
        if (!_motionDisabled) {
          _position.value = transition.position;
          _pressure.value = transition.pressure;
          _moveTo(_target, velocity: transition.velocity);
          _release(velocity: transition.pressureVelocity);
        }
      }
    }
    if (_motionDisabled) {
      _position.value = _target;
      _pressure.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant GlassBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      final router = GoRouter.maybeOf(context);
      if (router != null &&
          _navTransitions[router]?.toRoute == _route(widget.current)) {
        _navTransitions[router] = null;
      }
      _moveTo(_slot(widget.current));
      _release();
    }
  }

  void _moveTo(double target, {double? velocity}) {
    _target = target;
    if (_motionDisabled) {
      _position.value = target;
      return;
    }
    final speed = velocity ?? _position.velocity;
    if ((_position.value - target).abs() < .001 && speed.abs() < .01) {
      _position.value = target;
      return;
    }
    // Retarget from the actual presentation position AND velocity. Repeated
    // taps never restart a tween at the previous destination.
    _position.animateWith(SpringSimulation(
      _spring,
      _position.value,
      target,
      speed,
    ));
  }

  void _press(AppTab tab) {
    if (_motionDisabled) return;
    _moveTo(_slot(tab));
    _pressure.animateTo(
      1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
    );
  }

  void _release({double? velocity}) {
    if (_motionDisabled) {
      _pressure.value = 0;
      return;
    }
    final speed = velocity ?? _pressure.velocity;
    if (_pressure.value.abs() < .001 && speed.abs() < .01) {
      _pressure.value = 0;
      return;
    }
    _pressure.animateWith(SpringSimulation(
      _pressSpring,
      _pressure.value,
      0,
      speed,
    ));
  }

  void _cancelPress() {
    _moveTo(_slot(widget.current));
    _release();
  }

  void _navigate(AppTab tab) {
    final router = GoRouter.of(context);
    final route = _route(tab);
    final currentRoute = router.routeInformationProvider.value.uri.path;
    final pending = _navTransitions[router];
    // Ignore stale outgoing pages, but allow the latest tap to replace a
    // request made by this page before the destination has mounted.
    if (currentRoute != _route(widget.current) &&
        !(pending?.fromRoute == _route(widget.current) &&
            pending?.toRoute == currentRoute)) {
      return;
    }
    _release();
    _moveTo(_slot(tab));
    if (currentRoute == route) return;
    final transition = _NavTransition(
      fromRoute: _route(widget.current),
      toRoute: route,
      position: _position.value,
      velocity: _position.velocity,
      pressure: _pressure.value,
      pressureVelocity: _pressure.velocity,
    );
    _navTransitions[router] = transition;
    router.go(route);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_navTransitions[router], transition)) {
        _navTransitions[router] = null;
      }
    });
  }

  @override
  void dispose() {
    _position.dispose();
    _pressure.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(ref.watch(selectedLanguageProvider));
    final dark = AppTheme.isDark(context);
    return Align(
      heightFactor: 1,
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: SafeArea(
            top: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x194658D8),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                // One bounded backdrop for the entire bar; the moving lens is
                // paint-only, with no nested filters or animated saveLayers.
                child: BackdropFilter(
                  filter: _blur,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: dark
                            ? const [Color(0xE620253A), Color(0xCC1C3045)]
                            : const [Color(0xCFFFFFFF), Color(0x99EDF3FF)],
                      ),
                      border: Border.all(color: dark ? AppTheme.darkGlassBorder : const Color(0xCFFFFFFF)),
                    ),
                    child: SizedBox(
                      height: 72,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          IgnorePointer(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                key: const ValueKey('glass-nav-lens'),
                                painter: _LiquidLensPainter(
                                  position: _position,
                                  pressure: _pressure,
                                  textDirection: Directionality.of(context),
                                  dark: dark,
                                ),
                              ),
                            ),
                          ),
                          Material(
                            type: MaterialType.transparency,
                            child: Row(
                              children: [
                                _item(Icons.home_rounded, l.navHome, AppTab.home),
                                _item(Icons.factory_outlined, l.navBoilerhouses,
                                    AppTab.boilerhouses),
                                _fab(l.navJournal),
                                _item(Icons.menu_book_rounded, l.navJournal,
                                    AppTab.journal),
                                _item(Icons.person_rounded, l.navProfile,
                                    AppTab.profile),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, AppTab tab) {
    final selected = tab == widget.current;
    final color = AppTheme.adaptiveColor(context, selected ? AppTheme.primary : AppTheme.inkSoft);
    void activate() => _navigate(tab);
    return Expanded(
      child: Semantics(
        key: ValueKey('glass-nav-${tab.name}'),
        button: true,
        selected: selected,
        label: label,
        onTap: activate,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: InkResponse(
            onTap: activate,
            onTapDown: (_) => _press(tab),
            onTapUp: (_) => _release(),
            onTapCancel: _cancelPress,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            radius: 30,
            child: SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24, color: color),
                  // Large text uses icon-only tabs, retaining full spoken
                  // labels and tooltips rather than shrinking the user's text.
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
    );
  }

  Widget _fab(String label) {
    void activate() {
      if (widget.onFab != null) {
        widget.onFab!();
      } else {
        _navigate(AppTab.journal);
      }
    }
    return Expanded(
      child: Semantics(
        key: const ValueKey('glass-nav-add'),
        button: true,
        label: label,
        onTap: activate,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: InkResponse(
            onTap: activate,
            radius: 30,
            child: SizedBox.expand(
              child: Center(
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
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidLensPainter extends CustomPainter {
  _LiquidLensPainter({
    required this.position,
    required this.pressure,
    required this.textDirection,
    required this.dark,
  }) : super(repaint: Listenable.merge([position, pressure]));

  final AnimationController position;
  final AnimationController pressure;
  final TextDirection textDirection;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final slotWidth = size.width / 5;
    final direction = textDirection == TextDirection.ltr ? 1.0 : -1.0;
    final speed = (position.velocity / 12).clamp(-1.0, 1.0) * direction;
    final press = pressure.value.clamp(-.15, 1.0);
    final rx = (slotWidth - 8).clamp(46.0, 82.0) / 2 *
        (1 + speed.abs() * .24 + press * .12);
    final ry = 26 * (1 - speed.abs() * .14 - press * .16);
    final logicalX = (position.value + .5) * slotWidth;
    final x = (direction > 0 ? logicalX : size.width - logicalX)
        .clamp(rx + 3, size.width - rx - 3);
    final y = size.height / 2 + press * 1.5;
    final lean = speed * rx * .18;
    final rect = Rect.fromCenter(
      center: Offset(x, y), width: rx * 2, height: ry * 2,
    );
    // The leading shoulder swells while the trailing shoulder narrows. Press
    // pressure flattens the droplet; the release spring briefly rounds it out.
    final lens = Path()
      ..moveTo(x + lean, y - ry)
      ..cubicTo(x + rx * .72, y - ry, x + rx, y - ry * .62, x + rx, y)
      ..cubicTo(x + rx, y + ry * .64, x + rx * .62, y + ry,
          x - lean * .5, y + ry)
      ..cubicTo(x - rx * .72, y + ry, x - rx, y + ry * .56, x - rx, y)
      ..cubicTo(x - rx, y - ry * .64, x - rx * .62, y - ry,
          x + lean, y - ry)
      ..close();
    canvas.drawPath(lens.shift(const Offset(0, 2)),
        Paint()..color = const Color(0x124658D8));
    canvas.drawPath(lens, Paint()..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0x337B8DF0), Color(0x4420B8D2), Color(0x484658D8)]
          : const [Color(0x8AFFFFFF), Color(0x5920B8D2), Color(0x484658D8)],
      stops: const [0, .48, 1],
    ).createShader(rect));
    canvas.drawPath(lens, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0x807B8DF0), Color(0x40FFFFFF), Color(0x704658D8)]
            : const [Color(0xF5FFFFFF), Color(0x66FFFFFF), Color(0x704658D8)],
      ).createShader(rect));
    final glint = Path()
      ..moveTo(x - rx * .72, y - ry * .48)
      ..cubicTo(x - rx * .54, y - ry * .88, x + lean - rx * .2,
          y - ry * .92, x + lean + rx * .25, y - ry * .86);
    canvas.drawPath(glint, Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5
      ..color = dark ? const Color(0x80FFFFFF) : const Color(0xCCFFFFFF));
  }

  @override
  bool shouldRepaint(covariant _LiquidLensPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.pressure != pressure ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.dark != dark;
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
    final unavailableRecords = ref.watch(dataQualityProvider).valueOrNull ?? 0;
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
            if (unavailableRecords > 0)
              Semantics(
                liveRegion: true,
                child: Material(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: AppTheme.adaptiveColor(context, AppTheme.warning)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(language.dataQualityWarning, style: Theme.of(context).textTheme.bodySmall)),
                      ],
                    ),
                  ),
                ),
              ),
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
