import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khorazm_issiklik_manbai_app/src/core/glass.dart';

void main() {
  testWidgets('interactive glass card gives a spring press response', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassCard(
              onTap: () => tapped = true,
              child: const Text('Open section'),
            ),
          ),
        ),
      ),
    );

    final card = find.byType(GlassCard);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump();

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      .985,
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });
}
