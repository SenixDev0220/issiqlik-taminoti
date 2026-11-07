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
  final uid = ref.watch(currentUserProvider.select((u) => u?.id));
  if (uid == null) return Stream.value(null);
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    FirestoreSyncTracker.instance.removeSnapshot('current-user-$uid');
  });
  return _fb.currentUserStream(uid).map((updated) {
    if (!disposed && ref.read(currentUserProvider)?.id == uid) {
      ref.read(currentUserProvider.notifier).state =
          updated?.status == UserStatus.active ? updated : null;
    }
    return updated;
  }).handleError((Object error, StackTrace stack) {
    if (!disposed && ref.read(currentUserProvider)?.id == uid) {
      ref.read(currentUserProvider.notifier).state = null;
    }
    FirestoreSyncTracker.instance.reportFailure(error, stack);
  });
});

final selectedLanguageProvider = StateProvider<String>((ref) => 'uz_cyrl');
final darkModeProvider = StateProvider<bool>((ref) => false);

final allUsersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return _fb.allUsersStream(user: ref.watch(currentUserProvider));
});

/// All users list (for stats / admin).
final userStoreProvider = Provider<List<AppUser>>((ref) {
  return ref.watch(allUsersStreamProvider).asData?.value ?? [];
});

final activeUsersProvider = Provider<List<AppUser>>((ref) {
  return ref.watch(userStoreProvider).where((u) => u.status == UserStatus.active).toList();
});

final pendingUsersProvider = Provider<List<AppUser>>((ref) {
  return ref.watch(userStoreProvider).where((u) => u.status == UserStatus.pending).toList();
});

class _UserActions {
  Future<void> approveUser(String uid) => _fb.approveUser(uid);
  Future<void> declineUser(String uid) => _fb.declineUser(uid);
  Future<void> changeRole(String uid, UserRole role) => _fb.changeRole(uid, role);
}

final _userActionsInstance = _UserActions();

final userStoreNotifierProvider = Provider<_UserActions>((_) => _userActionsInstance);

final journalStreamProvider = StreamProvider<List<JournalEntry>>((ref) {
  return _fb.journalStream(user: ref.watch(currentUserProvider));
});

/// Flat list — used by journal_providers.dart and journal_screen.dart.
final journalStoreProvider = Provider<List<JournalEntry>>((ref) {
  return ref.watch(journalStreamProvider).asData?.value ?? [];
});

class _JournalActions {
  Future<void> addEntry(JournalEntry e) => _fb.addJournalEntry(e);
  Future<void> updateEntry(JournalEntry e) => _fb.updateJournalEntry(e);
  Future<void> deleteEntry(String id) => _fb.deleteJournalEntry(id);
}

final _journalActionsInstance = _JournalActions();
final journalStoreNotifierProvider = Provider<_JournalActions>((_) => _journalActionsInstance);

final notificationsStreamProvider = StreamProvider.family<List<AppNotification>, String>((ref, userId) {
  final user = ref.watch(currentUserProvider);
  if (user?.id != userId || user?.status != UserStatus.active) return Stream.value([]);
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
  Future<void> markRead(String id) => _fb.markNotificationRead(id);
  Future<void> markAllRead(String userId) => _fb.markAllNotificationsRead(userId);
}

final _notifActionsInstance = _NotifActions();
final notificationsNotifierProvider = Provider.family<_NotifActions, String>(
  (_, _) => _notifActionsInstance,
);

final appStateInitProvider = Provider<void>((_) {});
