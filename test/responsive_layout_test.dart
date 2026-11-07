import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khorazm_issiklik_manbai_app/src/core/app_state.dart';
import 'package:khorazm_issiklik_manbai_app/src/core/app_theme.dart';
import 'package:khorazm_issiklik_manbai_app/src/core/glass.dart';
import 'package:khorazm_issiklik_manbai_app/src/features/home/home_screen.dart';
import 'package:khorazm_issiklik_manbai_app/src/features/login/register_screen.dart';

void main() {
  for (final (width, height, textScale) in <(double, double, double)>[
    (320, 568, 1),
    (360, 740, 1.3),
    (412, 915, 1.5),
    (844, 390, 1.2),
    (320, 568, 2.0),
    (360, 740, 2.0),
    (844, 390, 2.0),
    (1200, 900, 2.0),
  ]) {
    testWidgets(
      'home and registration fit ${width.toInt()}x${height.toInt()} at text scale $textScale',
      (tester) async {
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);

        final mediaData = MediaQueryData(
          size: Size(width, height),
          devicePixelRatio: 1,
          textScaler: TextScaler.linear(textScale),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              selectedLanguageProvider.overrideWith((ref) => 'uz_latin'),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: MediaQuery(data: mediaData, child: const HomeScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (
          var i = 0;
          i < 5 && find.text('Barcha bo\'limlar').evaluate().isEmpty;
          i++
        ) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -700));
          await tester.pumpAndSettle();
        }

        expect(find.text('Barcha bo\'limlar'), findsOneWidget);
        await tester.ensureVisible(find.text('Barcha bo\'limlar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              selectedLanguageProvider.overrideWith((ref) => 'uz_latin'),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: MediaQuery(data: mediaData, child: const RegisterScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNWidgets(6));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('shared screen content stays centered and readable on tablets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    double? availableWidth;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: GlassScaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                availableWidth = constraints.maxWidth;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(availableWidth, kMaxScreenContentWidth);
    expect(tester.takeException(), isNull);
  });
}
