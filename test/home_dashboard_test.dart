import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khorazm_issiklik_manbai_app/src/core/app_settings.dart';
import 'package:khorazm_issiklik_manbai_app/src/core/app_state.dart';
import 'package:khorazm_issiklik_manbai_app/src/core/app_theme.dart';
import 'package:khorazm_issiklik_manbai_app/src/features/boilerhouse/boilerhouse_providers.dart';
import 'package:khorazm_issiklik_manbai_app/src/features/home/home_screen.dart';
import 'package:khorazm_issiklik_manbai_app/src/domain/models/boiler_house.dart';

void main() {
  testWidgets(
    'home presents an operations dashboard and grouped section menu',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            boilerHouseListProvider.overrideWithValue([
              const BoilerHouse(
                id: 'operating',
                name: 'House A',
                address: 'Address A',
                status: BoilerHouseStatus.operating,
              ),
              const BoilerHouse(
                id: 'emergency',
                name: 'House B',
                address: 'Address B',
                status: BoilerHouseStatus.emergencyShutdown,
              ),
            ]),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Бошқарув маркази'), findsOneWidget);
      expect(find.text('Авария тўхтатиш · 1'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);

      await tester.ensureVisible(find.text('Барча бўлимлар'));
      await tester.pumpAndSettle();
      expect(find.text('Иш жараёнлари'), findsOneWidget);
      expect(find.text('Маълумот ва таҳлил'), findsOneWidget);
      expect(find.text('Жамоа ва шахсий'), findsOneWidget);
      expect(find.text('Навбатчилик жадвали'), findsOneWidget);
    },
  );

  testWidgets('home dashboard respects Uzbek Latin localization', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedLanguageProvider.overrideWith((ref) => PersistedSetting<String>(
            initialValue: 'uz_latin',
            load: () async => null,
            save: (_) async => true,
          )),
          boilerHouseListProvider.overrideWithValue(const []),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Boshqaruv markazi'), findsOneWidget);
    await tester.ensureVisible(find.text('Barcha bo\'limlar'));
    await tester.pumpAndSettle();
    expect(find.text('Ish jarayonlari'), findsOneWidget);
    expect(find.text('Ma\'lumot va tahlil'), findsOneWidget);
  });
}
