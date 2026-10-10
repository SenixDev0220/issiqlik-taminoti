import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/app_user.dart';
import '../domain/models/journal_entry.dart';
import '../domain/models/notification_model.dart';
import '../services/firebase_service.dart';
import 'firestore_sync_tracker.dart';

final _fb = FirebaseService.instance;

final firestoreSyncStateProvider = StreamProvider<FirestoreSyncState>((ref) {
  return FirestoreSyncTracker.instance.stream;
});

final currentUserProvider = StateProvider<AppUser?>((ref) => null);

/// Keeps currentUserProvider in sync when Firestore role/status changes.
final currentUserSyncProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  ref.onDispose(() {
    FirestoreSyncTracker.instance.removeSnapshot('current-user-${user.id}');
  });
  return _fb.currentUserStream(user.id).map((updated) {
    if (updated != null) {
      ref.read(currentUserProvider.notifier).state = updated;
    }
    return updated;
  });
});

final selectedLanguageProvider = StateProvider<String>((ref) => 'uz_cyrl');
final darkModeProvider = StateProvider<bool>((ref) => false);

final allUsersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return _fb.allUsersStream();
});

/// All users list (for stats / admin).
final userStoreProvider = Provider<List<AppUser>>((ref) {
  return ref.watch(allUsersStreamProvider).valueOrNull ?? [];
});

final activeUsersProvider = Provider<List<AppUser>>((ref) {
  return ref.watch(userStoreProvider).where((u) => u.status == UserStatus.active).toList();
});

final pendingUsersProvider = Provider<List<AppUser>>((ref) {
  return ref.watch(userStoreProvider).where((u) => u.status == UserStatus.pending).toList();
});

class _UserActions {
  void approveUser(String uid) => _fb.approveUser(uid);
  void declineUser(String uid) => _fb.declineUser(uid);
  void changeRole(String uid, UserRole role) => _fb.changeRole(uid, role);
}

final _userActionsInstance = _UserActions();

final userStoreNotifierProvider = Provider<_UserActions>((_) => _userActionsInstance);

final journalStreamProvider = StreamProvider<List<JournalEntry>>((ref) {
  return _fb.journalStream();
});

/// Flat list — used by journal_providers.dart and journal_screen.dart.
final journalStoreProvider = Provider<List<JournalEntry>>((ref) {
  return ref.watch(journalStreamProvider).valueOrNull ?? [];
});

class _JournalActions {
  void addEntry(JournalEntry e) => _fb.addJournalEntry(e);
  void updateEntry(JournalEntry e) => _fb.updateJournalEntry(e);
  void deleteEntry(String id) => _fb.deleteJournalEntry(id);
}

final _journalActionsInstance = _JournalActions();
final journalStoreNotifierProvider = Provider<_JournalActions>((_) => _journalActionsInstance);

final notificationsStreamProvider = StreamProvider.family<List<AppNotification>, String>((ref, userId) {
  return _fb.notificationsStream(userId);
});

/// Alias used by notifications_screen.dart
final userNotificationsProvider = notificationsStreamProvider;

final unreadCountProvider = Provider.family<int, String>((ref, userId) {
  return ref.watch(notificationsStreamProvider(userId)).valueOrNull
      ?.where((n) => !n.isRead)
      .length ?? 0;
});

class _NotifActions {
  void markRead(String id) => _fb.markNotificationRead(id);
  void markAllRead(String userId) => _fb.markAllNotificationsRead(userId);
}

final _notifActionsInstance = _NotifActions();
final notificationsNotifierProvider = Provider.family<_NotifActions, String>(
  (_, _) => _notifActionsInstance,
);

final appStateInitProvider = Provider<void>((_) {});
