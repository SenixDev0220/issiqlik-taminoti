import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:khorazm_issiklik_manbai_app/src/core/glass.dart';

void main() {
  testWidgets('direct mounts place the lens at the current tab immediately', (
    tester,
  ) async {
    for (final tab in AppTab.values) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _TabPage(key: ValueKey(tab), tab: tab),
          ),
        ),
      );
      final center = _lensBounds(tester).center.dx;
      final navRect = tester.getRect(_lens);
      expect(center + navRect.left,
          closeTo(tester.getCenter(_tab(tab)).dx, .01));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('route remount preserves presentation position then springs home', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    final oldNav = tester.state(find.byType(GlassBottomNav));
    final initial = _lensBounds(tester);
    await tester.tap(_tab(AppTab.boilerhouses));
    expect(router.routeInformationProvider.value.uri.path, '/boilerhouses');
    await tester.pump();
    expect(tester.state(find.byType(GlassBottomNav)), isNot(same(oldNav)));
    expect(_lensBounds(tester).center.dx, closeTo(initial.center.dx, .01));
    await tester.pump(const Duration(milliseconds: 80));
    final moving = _lensBounds(tester);
    expect(moving.center.dx, greaterThan(initial.center.dx));
    expect(moving.width, greaterThan(initial.width));
    expect(moving.height, lessThan(initial.height));
    await tester.pumpAndSettle();
    _expectLensAt(tester, AppTab.boilerhouses);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('press flattens the droplet and cancellation restores selection', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    final initial = _lensBounds(tester);
    final gesture = await tester.startGesture(
        tester.getCenter(_tab(AppTab.home)));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
    final pressed = _lensBounds(tester);
    expect(pressed.width, greaterThan(initial.width));
    expect(pressed.height, lessThan(initial.height));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_lensBounds(tester).width, closeTo(initial.width, .01));
    expect(_lensBounds(tester).height, closeTo(initial.height, .01));
    expect(router.routeInformationProvider.value.uri.path, '/home');

    final canceled = await tester.startGesture(
        tester.getCenter(_tab(AppTab.profile)));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 80));
    expect(_lensBounds(tester).center.dx, greaterThan(initial.center.dx));
    expect(router.routeInformationProvider.value.uri.path, '/home');
    await canceled.cancel();
    await tester.pumpAndSettle();
    _expectLensAt(tester, AppTab.home);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('fast taps preserve moving lens and only navigate once per target', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    var requests = 0;
    router.routeInformationProvider.addListener(() => requests++);
    await tester.tap(_tab(AppTab.profile));
    await tester.tap(_tab(AppTab.profile));
    expect(requests, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 65));
    final beforeRetarget = _lensBounds(tester);
    await tester.tap(_tab(AppTab.boilerhouses));
    await tester.pump();
    final afterRetarget = _lensBounds(tester);
    expect(afterRetarget.center.dx, closeTo(beforeRetarget.center.dx, .01));
    expect(afterRetarget.width, closeTo(beforeRetarget.width, .01));
    await tester.pumpAndSettle();
    _expectLensAt(tester, AppTab.boilerhouses);
    expect(requests, 2);
    expect(router.routeInformationProvider.value.uri.path, '/boilerhouses');
    expect(tester.takeException(), isNull);

    // Two different destinations requested before the next frame: latest wins.
    await tester.tap(_tab(AppTab.profile));
    await tester.tap(_tab(AppTab.home));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
    _expectLensAt(tester, AppTab.home);
    expect(requests, 4);
  });

  testWidgets('same-state updates retarget without resetting the lens', (
    tester,
  ) async {
    final selected = ValueNotifier(AppTab.home);
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ValueListenableBuilder<AppTab>(
            valueListenable: selected,
            builder: (_, tab, _) => _TabPage(tab: tab),
          ),
        ),
      ),
    );
    selected.value = AppTab.profile;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final before = _lensBounds(tester);
    selected.value = AppTab.boilerhouses;
    await tester.pump();
    expect(_lensBounds(tester).center.dx, closeTo(before.center.dx, .01));
    await tester.pumpAndSettle();
    _expectLensAt(tester, AppTab.boilerhouses);
  });

  for (final mode in ['disableAnimations', 'accessibleNavigation', 'ticker']) {
    testWidgets('$mode stops travel and press deformation', (tester) async {
      final router = _router();
      addTearDown(router.dispose);
      final disabled = ValueNotifier(false);
      addTearDown(disabled.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => ValueListenableBuilder<bool>(
              valueListenable: disabled,
              builder: (_, value, _) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: value && mode == 'disableAnimations',
                  accessibleNavigation: value && mode == 'accessibleNavigation',
                ),
                child: TickerMode(
                  enabled: !(value && mode == 'ticker'),
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_tab(AppTab.profile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      disabled.value = true;
      await tester.pump();
      _expectLensAt(tester, AppTab.profile);
      final resting = _lensBounds(tester);
      final gesture = await tester.startGesture(
          tester.getCenter(_tab(AppTab.profile)));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_lensBounds(tester), resting);
      await gesture.up();
      await tester.tap(_tab(AppTab.home));
      await tester.pumpAndSettle();
      _expectLensAt(tester, AppTab.home);
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets('redirect does not leave a stale transition for a later mount', (
    tester,
  ) async {
    var redirectProfile = true;
    final router = _router(
      redirect: (_, state) =>
          redirectProfile && state.uri.path == '/profile' ? '/home' : null,
    );
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    await tester.tap(_tab(AppTab.profile));
    await tester.pumpAndSettle();
    redirectProfile = false;
    router.go('/profile');
    await tester.pump();
    _expectLensAt(tester, AppTab.profile);
    expect(tester.takeException(), isNull);
  });

  testWidgets('default add goes to journal and custom add stays on its route', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pumpRouter(tester, router);
    await tester.tap(find.byKey(const ValueKey('glass-nav-add')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/journal');
    _expectLensAt(tester, AppTab.journal);
    var actions = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: _TabPage(tab: AppTab.home, onFab: () => actions++),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('glass-nav-add')));
    expect(actions, 1);
    _expectLensAt(tester, AppTab.home);
  });

  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1200, 900),
  ]) {
    testWidgets('72px bar fits $size with large text, safe insets and semantics', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
      final insets = size.width == 844
          ? const EdgeInsets.fromLTRB(44, 0, 44, 21)
          : const EdgeInsets.only(bottom: 34);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: insets,
                textScaler: TextScaler.linear(2),
              ),
              child: const _TabPage(tab: AppTab.home),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(_lens);
      expect(rect.width, lessThanOrEqualTo(600));
      expect(rect.height, 72);
      expect(rect.bottom, lessThanOrEqualTo(size.height - insets.bottom));
      expect(rect.left, greaterThanOrEqualTo(insets.left));
      expect(rect.right, lessThanOrEqualTo(size.width - insets.right));
      for (final tab in AppTab.values) {
        final target = tester.getSize(_tab(tab));
        expect(target.width, greaterThanOrEqualTo(48));
        expect(target.height, greaterThanOrEqualTo(48));
        final data = tester.getSemantics(_tab(tab)).getSemanticsData();
        expect(data.label, isNotEmpty);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isSelected, tab == AppTab.home ? Tristate.isTrue : Tristate.isFalse);
      }
      expect(tester.getSize(find.byKey(const ValueKey('glass-nav-add'))).width,
          greaterThanOrEqualTo(48));
      expect(find.descendant(of: find.byType(GlassBottomNav),
          matching: find.byType(Text)), findsNothing);
      final blur = find.descendant(of: find.byType(GlassBottomNav),
          matching: find.byType(BackdropFilter));
      expect(blur, findsOneWidget);
      expect(tester.getSize(blur), rect.size);
      expect(find.ancestor(of: blur, matching: find.byType(ClipRRect)),
          findsOneWidget);
      _expectLensAt(tester, AppTab.home);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('RTL mirrors the lens with the tab order', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: _TabPage(tab: AppTab.profile),
          ),
        ),
      ),
    );
    _expectLensAt(tester, AppTab.profile);
    expect(tester.getCenter(_tab(AppTab.profile)).dx,
        lessThan(tester.getCenter(_tab(AppTab.home)).dx));
  });
}

final _lens = find.byKey(const ValueKey('glass-nav-lens'));
Finder _tab(AppTab tab) => find.byKey(ValueKey('glass-nav-${tab.name}'));

// Inspect the actual painted outline, not private controller implementation.
Rect _lensBounds(WidgetTester tester) {
  final painter = tester.widget<CustomPaint>(_lens).painter!;
  Rect? bounds;
  expect(
    (Canvas canvas) => painter.paint(canvas, tester.getSize(_lens)),
    paints..something((method, arguments) {
      if (method != #drawPath) return false;
      final paint = arguments[1] as Paint;
      if (paint.style != PaintingStyle.fill || paint.shader == null) return false;
      bounds = (arguments[0] as Path).getBounds();
      return true;
    }),
  );
  return bounds!;
}

void _expectLensAt(WidgetTester tester, AppTab tab) {
  final lensRect = tester.getRect(_lens);
  expect(_lensBounds(tester).center.dx + lensRect.left,
      closeTo(tester.getCenter(_tab(tab)).dx, .1));
}

GoRouter _router({GoRouterRedirect? redirect}) => GoRouter(
  initialLocation: '/home',
  redirect: redirect,
  routes: [
    for (final tab in AppTab.values)
      GoRoute(
        path: '/${tab.name}',
        pageBuilder: (_, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: _TabPage(tab: tab),
        ),
      ),
  ],
);

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
}

class _TabPage extends StatelessWidget {
  const _TabPage({super.key, required this.tab, this.onFab});

  final AppTab tab;
  final VoidCallback? onFab;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: Center(child: Text(tab.name)),
    bottomNavigationBar: GlassBottomNav(current: tab, onFab: onFab),
  );
}
