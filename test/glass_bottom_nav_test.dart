import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:khorazm_issiklik_manbai_app/src/core/glass.dart';

void main() {
  testWidgets('tab indicator slides to the selected route', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => _TabPage(tab: AppTab.home, title: 'Home'),
        ),
        GoRoute(
          path: '/boilerhouses',
          builder: (_, _) =>
              _TabPage(tab: AppTab.boilerhouses, title: 'Boilerhouses'),
        ),
        GoRoute(
          path: '/journal',
          builder: (_, _) => _TabPage(tab: AppTab.journal, title: 'Journal'),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, _) => _TabPage(tab: AppTab.profile, title: 'Profile'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    final initialX = _indicatorX(tester);
    await tester.tap(find.byIcon(Icons.factory_outlined));
    expect(router.routeInformationProvider.value.uri.path, '/boilerhouses');
    await tester.pumpAndSettle();

    expect(find.text('Boilerhouses'), findsOneWidget);
    expect(_indicatorX(tester), greaterThan(initialX));

  });
}

double _indicatorX(WidgetTester tester) {
  final indicator = tester.widget<Transform>(
    find.descendant(
      of: find.byType(GlassBottomNav),
      matching: find.byType(Transform),
    ),
  );
  return indicator.transform.storage[12];
}

class _TabPage extends StatelessWidget {
  const _TabPage({required this.tab, required this.title});

  final AppTab tab;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(title)),
      bottomNavigationBar: GlassBottomNav(current: tab),
    );
  }
}
