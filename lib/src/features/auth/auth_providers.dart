import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/l10n.dart';
import '../../domain/models/app_user.dart';
import '../../services/firebase_service.dart';
import '../../services/push_service.dart';

export '../../core/app_state.dart' show currentUserProvider, selectedLanguageProvider, darkModeProvider;

final _fb = FirebaseService.instance;

/// Convenience l10n provider.
final l10nProvider = Provider<AppL10n>((ref) {
  final lang = ref.watch(selectedLanguageProvider);
  return AppL10n.of(lang);
});

Future<String?> attemptLogin(WidgetRef ref, String login, String password) async {
  final l = ref.read(l10nProvider);
  final user = await _fb.signIn(login, password);
  if (user == null) return l.loginWrongError;
  if (user.status == UserStatus.pending) {
    await _fb.signOut();
    return l.loginPendingError;
  }
  if (user.status == UserStatus.blocked) {
    await _fb.signOut();
    return l.loginWrongError;
  }
  ref.read(currentUserProvider.notifier).state = user;
  _fb.waitForPendingWrites();
  _fb.seedIfEmpty().catchError((_) {});
  PushService.instance.init();
  PushService.instance.registerToken(user.id);
  return null;
}

Future<void> signOut(WidgetRef ref) async {
  final uid = ref.read(currentUserProvider)?.id;
  ref.read(currentUserProvider.notifier).state = null;
  try {
    if (uid != null) {
      // Must run before Firebase sign-out: clearing the token writes to the
      // user's own profile, which requires an authenticated request.
      await PushService.instance.unregister(uid);
    }
    await _fb.signOut();
  } finally {
    // The local session must end even if the network calls above failed.
    ref.read(currentUserProvider.notifier).state = null;
  }
}

Future<String?> registerUser(WidgetRef ref, {
  required String login,
  required String password,
  required String firstName,
  required String lastName,
  required String phone,
}) async {
  return _fb.register(
    login: login, password: password, firstName: firstName,
    lastName: lastName, phone: phone,
  );
}

Future<String?> changePassword({
  required String currentPassword,
  required String newPassword,
}) async {
  return _fb.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );
}

/// Firebase Auth persists session by default. We just need to fetch the user doc.
Future<AppUser?> restoreSession() async {
  final uid = _fb.currentUid;
  if (uid == null) return null;
  return _fb.fetchUser(uid);
}
