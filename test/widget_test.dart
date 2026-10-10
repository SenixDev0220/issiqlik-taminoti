import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:khorazm_issiklik_manbai_app/src/core/glass.dart';
import 'package:khorazm_issiklik_manbai_app/src/core/l10n.dart';
import 'package:khorazm_issiklik_manbai_app/src/domain/models/shift.dart';

void main() {
  group('AppL10n', () {
    test('both scripts provide non-empty strings for key getters', () {
      for (final lang in ['uz_cyrl', 'uz_latn']) {
        final l = AppL10n.of(lang);
        final samples = [
          l.loginTitle,
          l.loginButton,
          l.startupLoading,
          l.startupError,
          l.retryButton,
          l.syncChecking,
          l.syncOffline(1),
          l.syncPending(1),
          l.syncError,
          l.requestSent,
          l.navHome,
          l.navBoilerhouses,
          l.navJournal,
          l.navProfile,
          l.shiftsTitle,
          l.shiftDay,
          l.shiftNight,
          l.analyticsTitle,
          l.analyticsTotals,
          l.analyticsByDistrict,
        ];
        for (final s in samples) {
          expect(s.trim(), isNotEmpty, reason: 'empty l10n string for $lang');
        }
      }
    });

    test('scripts actually differ (Cyrillic vs Latin)', () {
      expect(AppL10n.of('uz_cyrl').loginTitle,
          isNot(AppL10n.of('uz_latn').loginTitle));
    });
  });

  group('Shift model', () {
    test('defaults and fields', () {
      final s = Shift(
        id: 'sh-1',
        boilerHouseId: 'bh-01',
        boilerHouseName: '19-даха',
        operatorId: 'u1',
        operatorName: 'Test User',
        date: DateTime(2026, 7, 27),
        type: ShiftType.night,
        createdBy: 'admin',
        createdAt: DateTime(2026, 7, 26),
      );
      expect(s.note, isEmpty);
      expect(s.type, ShiftType.night);
    });
  });

  group('Glass widgets', () {
    testWidgets('GlassCard renders child and handles tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GlassCard(
            onTap: () => tapped = true,
            child: const Text('inside'),
          ),
        ),
      ));
      expect(find.text('inside'), findsOneWidget);
      await tester.tap(find.text('inside'));
      expect(tapped, isTrue);
    });

    testWidgets('StatusChip shows label', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: StatusChip(label: 'Faol', color: Colors.teal),
        ),
      ));
      expect(find.text('Faol'), findsOneWidget);
    });
  });
}
