import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-only appearance preferences. Never store account or session data here.
class AppSettingsStore {
  AppSettingsStore({Future<SharedPreferences> Function()? openPreferences})
    : _openPreferences = openPreferences ?? SharedPreferences.getInstance;

  static const languageKey = 'language';
  static const darkModeKey = 'darkMode';

  final Future<SharedPreferences> Function() _openPreferences;
  Future<SharedPreferences>? _preferences;
  Future<void> _pendingSave = Future<void>.value();

  Future<SharedPreferences> _open() async {
    try {
      return await (_preferences ??= _openPreferences());
    } catch (_) {
      // A failed plugin initialization must not poison every later save.
      _preferences = null;
      rethrow;
    }
  }

  static String normalizeLanguage(String language) =>
      language == 'uz_latin' || language == 'uz_latn' ? 'uz_latin' : 'uz_cyrl';

  Future<String?> readLanguage() async {
    final value = (await _open()).get(languageKey);
    if (value is! String ||
        !const {'uz_cyrl', 'uz_latin', 'uz_latn'}.contains(value)) {
      return null;
    }
    return normalizeLanguage(value);
  }

  Future<bool?> readDarkMode() async {
    final value = (await _open()).get(darkModeKey);
    return value is bool ? value : null;
  }

  Future<bool> saveLanguage(String language) => _save(
    (preferences) => preferences.setString(languageKey, normalizeLanguage(language)),
  );

  Future<bool> saveDarkMode(bool darkMode) =>
      _save((preferences) => preferences.setBool(darkModeKey, darkMode));

  Future<bool> _save(Future<bool> Function(SharedPreferences) write) {
    // Serialize writes across both settings, including while initialization is
    // pending. A rejected write does not prevent the next queued write.
    final result = _pendingSave.then((_) async {
      try {
        return await write(await _open());
      } catch (_) {
        return false;
      }
    });
    _pendingSave = result.then<void>((_) {});
    return result;
  }
}

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) => AppSettingsStore());

/// Immediate UI updates with asynchronous restoration and awaitable persistence.
class PersistedSetting<T> extends StateNotifier<T> {
  PersistedSetting({
    required T initialValue,
    required Future<T?> Function() load,
    required Future<bool> Function(T) save,
    T Function(T)? normalize,
  }) : _save = save,
       _normalize = normalize,
       super(initialValue) {
    ready = _restore(load);
  }

  final Future<bool> Function(T) _save;
  final T Function(T)? _normalize;
  bool _changedByUser = false;
  late final Future<void> ready;
  Future<bool> _saved = Future<bool>.value(true);

  /// Completion of the latest save, also available to legacy `.state =` users.
  Future<bool> get saved => _saved;

  @override
  T get state => super.state;

  @override
  set state(T value) => unawaited(setValue(value));

  Future<bool> setValue(T value) {
    _changedByUser = true;
    final normalized = _normalize?.call(value) ?? value;
    super.state = normalized;
    return _saved = _persist(normalized);
  }

  Future<bool> _persist(T value) async {
    try {
      return await _save(value);
    } catch (_) {
      // Keep the chosen appearance for this session even if storage fails.
      return false;
    }
  }

  Future<void> _restore(Future<T?> Function() load) async {
    try {
      final value = await load();
      // An explicit choice, even one equal to the default, wins over late I/O.
      if (mounted && !_changedByUser && value != null) {
        super.state = _normalize?.call(value) ?? value;
      }
    } catch (_) {
      // Defaults remain usable when preferences are unavailable or malformed.
    }
  }
}
