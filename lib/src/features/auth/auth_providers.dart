import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/l10n.dart';
import '../../domain/models/app_user.dart';
import '../../services/auth_result.dart';
import '../../services/firebase_service.dart';
import '../../services/push_service.dart';

export '../../core/app_state.dart' show currentUserProvider, selectedLanguageProvider, darkModeProvider;

final _fb = FirebaseService.instance;
final l10nProvider = Provider<AppL10n>((ref) => AppL10n.of(ref.watch(selectedLanguageProvider)));

Future<SignInResult> attemptLogin(WidgetRef ref, String login, String password) async {
  final result = await _fb.signIn(login, password);
  if (!result.succeeded) return result;
  ref.read(currentUserProvider.notifier).state = result.user;
  unawaited(PushService.instance.init());
  return result;
}

Future<void> signOut(WidgetRef ref) async {
  final uid = ref.read(currentUserProvider)?.id;
  ref.read(currentUserProvider.notifier).state = null;
  if (uid != null) unawaited(PushService.instance.unregister(uid));
  await _fb.signOut();
}

Future<RegistrationResult> registerUser(WidgetRef ref, {
  required String login,
  required String password,
  required String firstName,
  required String lastName,
  required String phone,
}) => _fb.register(login: login, password: password, firstName: firstName, lastName: lastName, phone: phone);

Future<String?> changePassword({required String currentPassword, required String newPassword}) =>
    _fb.changePassword(currentPassword: currentPassword, newPassword: newPassword);

Future<AppUser?> restoreSession() async {
  final uid = _fb.currentUid;
  if (uid == null) return null;
  try {
    final user = await _fb.fetchUser(uid);
    if (user?.status == UserStatus.active) return user;
  } catch (_) {
    // Server verification is mandatory; restoration never trusts cached roles.
  }
  try {
    await _fb.signOut();
  } catch (_) {
    // No user is exposed to providers even if native cleanup fails.
  }
  return null;
}
