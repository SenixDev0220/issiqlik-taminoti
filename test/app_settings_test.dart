import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:khorazm_issiklik_manbai_app/src/core/app_settings.dart';
import 'package:khorazm_issiklik_manbai_app/src/core/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restores appearance only and persists changes across containers', () async {
    SharedPreferences.setMockInitialValues({'language': 'uz_latin', 'darkMode': true});
    final first = ProviderContainer();
    final language = first.read(selectedLanguageProvider.notifier);
    final darkMode = first.read(darkModeProvider.notifier);
    await Future.wait([language.ready, darkMode.ready]);
    expect(first.read(selectedLanguageProvider), 'uz_latin');
    expect(first.read(darkModeProvider), isTrue);

    language.state = 'uz_cyrl';
    expect(await language.saved, isTrue);
    expect(await darkMode.setValue(false), isTrue);
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    await Future.wait([
      second.read(selectedLanguageProvider.notifier).ready,
      second.read(darkModeProvider.notifier).ready,
    ]);
    expect(second.read(selectedLanguageProvider), 'uz_cyrl');
    expect(second.read(darkModeProvider), isFalse);
    expect((await SharedPreferences.getInstance()).getKeys(), {'language', 'darkMode'});
  });

  test('late initialization cannot overwrite an explicit default choice', () async {
    SharedPreferences.setMockInitialValues({'language': 'uz_latin', 'darkMode': true});
    final opened = Completer<SharedPreferences>();
    final container = ProviderContainer(overrides: [
      appSettingsStoreProvider.overrideWithValue(AppSettingsStore(openPreferences: () => opened.future)),
    ]);
    addTearDown(container.dispose);
    final language = container.read(selectedLanguageProvider.notifier);
    final darkMode = container.read(darkModeProvider.notifier);
    final languageSave = language.setValue('uz_cyrl');
    final themeSave = darkMode.setValue(false);
    opened.complete(await SharedPreferences.getInstance());
    await Future.wait([language.ready, darkMode.ready, languageSave, themeSave]);
    expect(container.read(selectedLanguageProvider), 'uz_cyrl');
    expect(container.read(darkModeProvider), isFalse);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString('language'), 'uz_cyrl');
    expect(stored.getBool('darkMode'), isFalse);
  });

  test('invalid stored values use defaults and legacy Latin code is normalized', () async {
    SharedPreferences.setMockInitialValues({'language': 42, 'darkMode': 'yes'});
    final store = AppSettingsStore();
    expect(await store.readLanguage(), isNull);
    expect(await store.readDarkMode(), isNull);
    expect(await store.saveLanguage('uz_latn'), isTrue);
    expect(await store.readLanguage(), 'uz_latin');
  });

  test('failed initialization and writes remain safe and can be retried', () async {
    var attempts = 0;
    final store = AppSettingsStore(openPreferences: () async {
      if (++attempts <= 2) throw PlatformException(code: 'unavailable');
      return SharedPreferences.getInstance();
    });
    final setting = PersistedSetting<bool>(
      initialValue: false,
      load: store.readDarkMode,
      save: store.saveDarkMode,
    );
    addTearDown(setting.dispose);
    await setting.ready;
    expect(setting.state, isFalse);
    expect(await setting.setValue(true), isFalse);
    expect(setting.state, isTrue);
    expect(await setting.setValue(true), isTrue);
    expect((await SharedPreferences.getInstance()).getBool('darkMode'), isTrue);
  });

  test('serialized writes wait for earlier saves, even when a save fails', () async {
    final preferences = _ControlledPreferences();
    final store = AppSettingsStore(openPreferences: () async => preferences);
    final first = store.saveDarkMode(true);
    final second = store.saveLanguage('uz_latin');
    final third = store.saveDarkMode(false);
    await Future<void>.delayed(Duration.zero);
    expect(preferences.started, ['darkMode=true']);

    preferences.firstWrite.complete(false);
    expect(await first, isFalse);
    expect(await second, isTrue);
    expect(await third, isTrue);
    expect(preferences.started, ['darkMode=true', 'language=uz_latin', 'darkMode=false']);
    expect(preferences.values, {'language': 'uz_latin', 'darkMode': false});
  });

  test('disposing before asynchronous load completes is safe', () async {
    final loaded = Completer<String?>();
    final setting = PersistedSetting<String>(
      initialValue: 'uz_cyrl',
      load: () => loaded.future,
      save: (_) async => true,
    );
    setting.dispose();
    loaded.complete('uz_latin');
    await setting.ready;
  });
}

class _ControlledPreferences implements SharedPreferences {
  final firstWrite = Completer<bool>();
  final started = <String>[];
  final values = <String, Object>{};

  Future<bool> _write(String key, Object value) async {
    started.add('$key=$value');
    if (started.length == 1 && !await firstWrite.future) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) => _write(key, value);

  @override
  Future<bool> setString(String key, String value) => _write(key, value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
