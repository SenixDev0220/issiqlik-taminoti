import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../core/firestore_sync_tracker.dart';
import '../data/boiler_seed.dart';
import '../data/sample_data.dart' as seed;
import '../domain/models/app_user.dart';
import '../domain/models/audit_entry.dart';
import '../domain/models/boiler_house.dart';
import '../domain/models/change_log.dart';
import '../domain/models/drawing.dart';
import '../domain/models/equipment.dart';
import '../domain/models/instruction.dart';
import '../domain/models/journal_entry.dart';
import '../domain/models/notification_model.dart';
import '../domain/models/shift.dart';

/// Central Firebase service вЂ” all Firestore reads/writes go through here.
class FirebaseService {
  FirebaseService._();
  static final instance = FirebaseService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<T> _trackWrite<T>(Future<T> write) =>
      FirestoreSyncTracker.instance.trackWrite(write);

  Future<T> _observeOperation<T>(Future<T> operation) {
    FirestoreSyncTracker.instance.observeOperation(operation);
    return operation;
  }

  void _reportSync(
    String source, {
    required bool isFromCache,
    required bool hasPendingWrites,
  }) {
    FirestoreSyncTracker.instance.reportSnapshot(
      source: source,
      isFromCache: isFromCache,
      hasPendingWrites: hasPendingWrites,
    );
  }

  // в”Ђв”Ђ Collections в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _journal => _db.collection('journal');
  CollectionReference<Map<String, dynamic>> get _notifications => _db.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _boilerhouses => _db.collection('boilerhouses');
  CollectionReference<Map<String, dynamic>> get _equipment => _db.collection('equipment');
  CollectionReference<Map<String, dynamic>> get _instructions => _db.collection('instructions');
  CollectionReference<Map<String, dynamic>> get _drawings => _db.collection('drawings');
  CollectionReference<Map<String, dynamic>> get _changeLogs => _db.collection('changeLogs');

  /// Returns IDs of all admin and co-admin users.
  Future<List<String>> _getAdminIds() async {
    final snap = await _users.where('role', whereIn: ['admin', 'coAdmin']).get();
    return snap.docs.map((d) => d.id).toList();
  }



  // в”Ђв”Ђ Init / seed в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  /// Seeds default data on first run if collections are empty.
  Future<void> seedIfEmpty() async {
    final bhExists = await _boilerhouses.limit(1).get();
    if (bhExists.docs.isEmpty) {
      await _seedBoilerhousesFromPassports();
    }
    await Future.wait([
      _seedCollection(_equipment, seed.sampleEquipment, _equipmentToMap),
      _seedCollection(_instructions, seed.sampleInstructions, _instructionToMap),
      _seedCollection(_drawings, seed.sampleDrawings, _drawingToMap),
    ]);
  }

  Future<void> _seedBoilerhousesFromPassports() async {
    final batch = _db.batch();
    for (final data in boilerhouseSeedData) {
      final id = data['id'] as String;
      batch.set(_boilerhouses.doc(id), data);
    }
    await _trackWrite(batch.commit());
  }

  Future<void> _seedCollection<T>(
    CollectionReference<Map<String, dynamic>> col,
    List<T> items,
    Map<String, dynamic> Function(T) toMap,
  ) async {
    final existing = await col.limit(1).get();
    if (existing.docs.isNotEmpty) return;
    final batch = _db.batch();
    for (final item in items) {
      final map = toMap(item);
      final id = map['id'] as String;
      batch.set(col.doc(id), map);
    }
    await _trackWrite(batch.commit());
  }

  // в”Ђв”Ђ Auth в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  String? get currentUid => _auth.currentUser?.uid;

  /// Persistent stream вЂ” emits user state across app restarts.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser?> signIn(String login, String password) async {
    try {
      final email = _toEmail(login);
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final uid = cred.user?.uid;
      if (uid == null) return null;
      return await _fetchUser(uid);
    } on FirebaseAuthException {
      return null;
    } on FirebaseException {
      // Firestore denied/failed the profile fetch — treat as failed login
      // instead of hanging the UI with an uncaught error.
      return null;
    }
  }

  Future<String?> register({
    required String login,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) =>
      _observeOperation(_register(
        login: login,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      ));

  Future<String?> _register({
    required String login,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    // Security rules only allow Firestore reads to authenticated users, so
    // uniqueness checks must happen AFTER the auth account is created.
    // Login uniqueness is guaranteed by Firebase Auth (email-already-in-use).
    final User authUser;
    try {
      final email = _toEmail(login);
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      authUser = cred.user!;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') return 'Bu login band';
      return e.message ?? 'Xatolik yuz berdi';
    }

    try {
      final uid = authUser.uid;

      final phoneCheck = await _users.where('phone', isEqualTo: phone).limit(1).get();
      if (phoneCheck.docs.isNotEmpty) {
        await authUser.delete();
        return 'Bu telefon raqami ro\'yxatdan o\'tgan';
      }

      final allUsers = await _users.limit(1).get();
      final isFirstUser = allUsers.docs.isEmpty;

      await _trackWrite(_users.doc(uid).set({
        'id': uid,
        'login': login,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'position': '',
        'photoUrl': '',
        'role': isFirstUser ? 'admin' : 'member',
        'status': isFirstUser ? 'active' : 'pending',
        'boilerhouseIds': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      }));

      if (!isFirstUser) {
        try {
          final adminIds = await _getAdminIds();
          await _trackWrite(_notifications.add({
            'type': 'system',
            'title': 'Yangi ro\'yxatdan o\'tish',
            'message': '$firstName $lastName ro\'yxatdan o\'tish so\'rovi yubordi',
            'recipientIds': adminIds,
            'isRead': false,
            'relatedUserId': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'sentAt': FieldValue.serverTimestamp(),
          }));
        } on FirebaseException {
          // Best-effort: registration itself succeeded, admins will still
          // see the user in the pending list.
        }
      }

      return null;
    } on FirebaseException {
      // Firestore step failed — roll back the auth account so the login is
      // not left half-registered.
      try {
        await authUser.delete();
      } catch (_) {}
      return 'Xatolik yuz berdi. Qayta urinib ko\'ring';
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> waitForPendingWrites() =>
      _trackWrite(_db.waitForPendingWrites());

  /// Request password reset вЂ” notifies admins.
  // Runs unauthenticated (forgot-password screen), so it cannot look the
  // user up in Firestore; it just files a system notification with the
  // login for admins to act on.
  Future<String?> requestPasswordReset(String login) async {
    try {
      _trackWrite(_notifications.add({
        'type': 'system',
        'title': 'Parol tiklash so\'rovi',
        'message': '${login.trim()} parolni tiklashni so\'radi',
        'recipientIds': <String>[],
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'sentAt': FieldValue.serverTimestamp(),
      }));
      return null;
    } on FirebaseException {
      return 'Xatolik yuz berdi. Qayta urinib ko\'ring';
    }
  }

  /// Change password вЂ” requires current password for re-authentication.
  /// Returns null on success, error string on failure.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return 'Tizimga kirilmagan';

    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);

      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Joriy parol noto\'g\'ri';
      }
      if (e.code == 'weak-password') return 'Parol juda zaif';
      return e.message ?? 'Xatolik yuz berdi';
    }
  }

  // в”Ђв”Ђ Users в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  Future<AppUser?> _fetchUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return _userFromDoc(doc);
  }

  /// Public вЂ” used by auth_providers.restoreSession.
  Future<AppUser?> fetchUser(String uid) => _fetchUser(uid);

  Stream<AppUser?> currentUserStream(String uid) {
    return _users.doc(uid).snapshots(includeMetadataChanges: true).map((doc) {
      _reportSync(
        'current-user-$uid',
        isFromCache: doc.metadata.isFromCache,
        hasPendingWrites: doc.metadata.hasPendingWrites,
      );
      return doc.exists ? _userFromDoc(doc) : null;
    }).distinct(_sameAppUser);
  }

  bool _sameAppUser(AppUser? previous, AppUser? current) {
    if (previous == null || current == null) return previous == current;
    return previous.id == current.id &&
        previous.login == current.login &&
        previous.firstName == current.firstName &&
        previous.lastName == current.lastName &&
        previous.phone == current.phone &&
        previous.position == current.position &&
        previous.photoUrl == current.photoUrl &&
        previous.role == current.role &&
        previous.status == current.status &&
        listEquals(previous.boilerhouseIds, current.boilerhouseIds);
  }

  Stream<List<AppUser>> allUsersStream() {
    return _users.orderBy('createdAt').snapshots().map(
          (snap) => snap.docs.map(_userFromDoc).toList(),
        );
  }

  Future<void> approveUser(String uid) =>
      _observeOperation(_approveUser(uid));

  Future<void> _approveUser(String uid) async {
    await _trackWrite(_users.doc(uid).update({'status': 'active'}));
    final doc = await _users.doc(uid).get();
    final data = doc.data()!;
    final name = '${data['firstName']} ${data['lastName']}';
    await _trackWrite(_notifications.add({
      'type': 'informational',
      'title': 'Ro\'yxatdan o\'tish tasdiqlandi',
      'message': '$name, sizning so\'rovingiz tasdiqlandi.',
      'recipientIds': [uid],
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'sentAt': FieldValue.serverTimestamp(),
    }));
  }

  Future<void> declineUser(String uid) =>
      _trackWrite(_users.doc(uid).update({'status': 'blocked'}));

  /// Block / unblock вЂ” same as declineUser but more clearly named
  Future<void> banUser(String uid) =>
      _trackWrite(_users.doc(uid).update({'status': 'blocked'}));
  Future<void> unbanUser(String uid) =>
      _trackWrite(_users.doc(uid).update({'status': 'active'}));

  Future<void> changeRole(String uid, UserRole role) =>
      _trackWrite(_users.doc(uid).update({'role': _roleToStr(role)}));

  Future<void> updateUserPosition(String uid, String position) =>
      _trackWrite(_users.doc(uid).update({'position': position}));

  Future<void> updateUserPhoto(String uid, String photoUrl) =>
      _trackWrite(_users.doc(uid).update({'photoUrl': photoUrl}));

  /// Stores this device's FCM token on the user's profile (merge write, so
  /// it works regardless of which other fields exist).
  Future<void> saveFcmToken(String uid, String token) =>
      _trackWrite(_users.doc(uid).set({'fcmToken': token}, SetOptions(merge: true)));

  Future<void> clearFcmToken(String uid) =>
      _trackWrite(_users.doc(uid).update({'fcmToken': FieldValue.delete()}));

  /// Deletes the user's profile doc, then the auth account. If the auth
  /// delete is rejected (e.g. requires recent login), the profile doc is
  /// restored so the account is not left half-deleted.
  /// Returns null on success, error text on failure.
  Future<String?> deleteAccount(String uid) =>
      _observeOperation(_deleteAccount(uid));

  Future<String?> _deleteAccount(String uid) async {
    final doc = await _users.doc(uid).get();
    final backup = doc.data();
    await _trackWrite(_users.doc(uid).delete());
    try {
      await _auth.currentUser?.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      if (backup != null) {
        await _trackWrite(_users.doc(uid).set(backup)).catchError((_) {});
      }
      if (e.code == 'requires-recent-login') {
        return 'Qayta kirib, so\'ng qayta urinib ko\'ring';
      }
      return e.message ?? 'Xatolik yuz berdi';
    }
  }

  /// Admin resets a user's password by re-creating their Firebase Auth account.
  /// Note: This signs out the admin temporarily.
  Future<void> adminResetPassword(String login, String newPassword) =>
      _observeOperation(_adminResetPassword(login, newPassword));

  Future<void> _adminResetPassword(String login, String newPassword) async {
    final snap = await _users.where('login', isEqualTo: login).limit(1).get();
    if (snap.docs.isEmpty) return;

    final uid = snap.docs.first.id;

    await _trackWrite(_db.collection('passwordResets').doc(uid).set({
      'login': login,
      'newPassword': newPassword,
      'createdAt': FieldValue.serverTimestamp(),
    }));

    await _trackWrite(_notifications.add({
      'type': 'informational',
      'title': 'Parol yangilandi',
      'message': 'Admin parolingizni yangiladi. Tizimga qayta kiring.',
      'recipientIds': [uid],
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'sentAt': FieldValue.serverTimestamp(),
    }));
  }

  // в”Ђв”Ђ Journal в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  Stream<List<JournalEntry>> journalStream() {
    return _journal.orderBy('eventDateTime', descending: true).limit(100)
        .snapshots().map((snap) => snap.docs.map(_entryFromDoc).toList());
  }

  Future<void> addJournalEntry(JournalEntry entry) =>
      _observeOperation(_addJournalEntry(entry));

  Future<void> _addJournalEntry(JournalEntry entry) async {
    await _trackWrite(_journal.doc(entry.id).set(_entryToMap(entry)));
    try {
      await _trackWrite(_notifications.add({
        'type': 'informational',
        'title': 'Yangi jurnal yozuvi',
        'message': '${entry.authorName}: ${entry.title}',
        'recipientIds': <String>[],
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'sentAt': FieldValue.serverTimestamp(),
      }));
    } on FirebaseException {
      // The broadcast is best-effort; the journal entry itself is saved.
    }
  }

  Future<void> updateJournalEntry(JournalEntry entry) =>
      _trackWrite(_journal.doc(entry.id).update(_entryToMap(entry)));

  Future<void> deleteJournalEntry(String id) =>
      _trackWrite(_journal.doc(id).delete());

  // в”Ђв”Ђ Notifications в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  Stream<List<AppNotification>> notificationsStream(String userId) {
    return _notifications.orderBy('sentAt', descending: true).limit(50)
        .snapshots().map((snap) => snap.docs.map(_notifFromDoc).where((n) {
              return n.recipientIds.isEmpty || n.recipientIds.contains(userId);
            }).toList());
  }

  Future<void> markNotificationRead(String id) =>
      _trackWrite(_notifications.doc(id).update({'isRead': true}));

  Future<void> markAllNotificationsRead(String userId) =>
      _observeOperation(_markAllNotificationsRead(userId));

  Future<void> _markAllNotificationsRead(String userId) async {
    final snap = await _notifications.where('isRead', isEqualTo: false).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      final recipients = List<String>.from(doc.data()['recipientIds'] ?? []);
      if (recipients.isEmpty || recipients.contains(userId)) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await _trackWrite(batch.commit());
  }

  Future<void> broadcastNotification({
    required String title,
    required String message,
  }) =>
      _observeOperation(_broadcastNotification(title: title, message: message));

  Future<void> _broadcastNotification({
    required String title,
    required String message,
  }) async {
    await _trackWrite(_notifications.add({
      'type': 'important',
      'title': title,
      'message': message,
      'recipientIds': <String>[],
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'sentAt': FieldValue.serverTimestamp(),
    }));
  }

  // в”Ђв”Ђ Boilerhouses в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  Stream<List<BoilerHouse>> boilerhousesStream() {
    return _boilerhouses.orderBy('name').snapshots().map(
          (snap) => snap.docs.map(_boilerhouseFromDoc).toList(),
        );
  }

  // в”Ђв”Ђ Equipment в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  Stream<List<Equipment>> equipmentStream() {
    return _equipment.orderBy('name').snapshots().map(
          (snap) => snap.docs.map(_equipmentFromDoc).toList(),
        );
  }

  // в”Ђв”Ђ Instructions в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  Stream<List<Instruction>> instructionsStream() {
    return _instructions.snapshots().map(
          (snap) => snap.docs.map(_instructionFromDoc).toList(),
        );
  }

  // в”Ђв”Ђ Drawings в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  Stream<List<Drawing>> drawingsStream() {
    return _drawings.snapshots().map(
          (snap) => snap.docs.map(_drawingFromDoc).toList(),
        );
  }

  // в”Ђв”Ђ CRUD: Boilerhouses / Instructions / Drawings в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  Future<void> addBoilerhouse(BoilerHouse b) =>
      _trackWrite(_boilerhouses.doc(b.id).set(_boilerhouseToMap(b)));
  Future<void> updateBoilerhouse(BoilerHouse b) =>
      _trackWrite(_boilerhouses.doc(b.id).update(_boilerhouseToMap(b)));
  Future<void> deleteBoilerhouse(String id) =>
      _trackWrite(_boilerhouses.doc(id).delete());

  Future<void> addInstruction(Instruction i) =>
      _trackWrite(_instructions.doc(i.id).set(_instructionToMap(i)));
  Future<void> updateInstruction(Instruction i) =>
      _trackWrite(_instructions.doc(i.id).update(_instructionToMap(i)));
  Future<void> deleteInstruction(String id) =>
      _trackWrite(_instructions.doc(id).delete());

  Future<void> addDrawing(Drawing d) =>
      _trackWrite(_drawings.doc(d.id).set(_drawingToMap(d)));
  Future<void> updateDrawing(Drawing d) =>
      _trackWrite(_drawings.doc(d.id).update(_drawingToMap(d)));
  Future<void> deleteDrawing(String id) =>
      _trackWrite(_drawings.doc(id).delete());

  // в”Ђв”Ђ ChangeLog в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  Stream<List<ChangeLogEntry>> changeLogsStream(String boilerHouseId) {
    return _changeLogs
        .where('boilerHouseId', isEqualTo: boilerHouseId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(_changeLogFromDoc).toList());
  }

  Future<void> addChangeLog(ChangeLogEntry entry) =>
      _trackWrite(_changeLogs.doc(entry.id).set(_changeLogToMap(entry)));

  Future<void> deleteChangeLog(String id) =>
      _observeOperation(_deleteChangeLog(id));

  Future<void> _deleteChangeLog(String id) async {
    await _trackWrite(_changeLogs.doc(id).delete());
    final reactions = await _changeLogs.doc(id).collection('reactions').get();
    if (reactions.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in reactions.docs) {
        batch.delete(doc.reference);
      }
      await _trackWrite(batch.commit());
    }
  }

  Stream<List<ChangeLogReaction>> reactionsStream(String changeLogId) {
    return _changeLogs
        .doc(changeLogId)
        .collection('reactions')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(_reactionFromDoc).toList());
  }

  Future<void> addReaction(ChangeLogReaction reaction) =>
      _trackWrite(_changeLogs
          .doc(reaction.changeLogId)
          .collection('reactions')
          .doc(reaction.id)
          .set(_reactionToMap(reaction)));

  Future<void> deleteReaction(String changeLogId, String reactionId) =>
      _trackWrite(
        _changeLogs.doc(changeLogId).collection('reactions').doc(reactionId).delete(),
      );

  // в”Ђв”Ђ Storage uploads в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  /// Upload a file (photo/video) and return its download URL.
  Future<String> uploadFile({
    required File file,
    required String folder,
  }) async {
    final ext = file.path.split('.').last;
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child(folder).child(name);
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  Future<List<String>> uploadFiles({
    required List<File> files,
    required String folder,
  }) async {
    return Future.wait(files.map((f) => uploadFile(file: f, folder: folder)));
  }

  // в”Ђв”Ђ Helpers / mappers в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ

  String _toEmail(String login) => '$login@khorazm-issiklik.app';

  AppUser _userFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return AppUser(
      id: doc.id,
      login: d['login'] ?? '',
      firstName: d['firstName'] ?? '',
      lastName: d['lastName'] ?? '',
      phone: d['phone'] ?? '',
      position: d['position'] ?? '',
      photoUrl: d['photoUrl'] ?? '',
      role: _roleFromStr(d['role'] ?? 'member'),
      status: _statusFromStr(d['status'] ?? 'pending'),
      boilerhouseIds: List<String>.from(d['boilerhouseIds'] ?? []),
    );
  }

  JournalEntry _entryFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return JournalEntry(
      id: doc.id,
      boilerHouseId: d['boilerHouseId'] ?? '',
      equipmentId: d['equipmentId'],
      eventDateTime: (d['eventDateTime'] as Timestamp).toDate(),
      category: d['category'] ?? '',
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      importance: _importanceFromStr(d['importance'] ?? 'normal'),
      status: _jStatusFromStr(d['status'] ?? 'open'),
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _entryToMap(JournalEntry e) => {
        'boilerHouseId': e.boilerHouseId,
        'equipmentId': e.equipmentId,
        'eventDateTime': Timestamp.fromDate(e.eventDateTime),
        'category': e.category,
        'title': e.title,
        'description': e.description,
        'importance': _importanceToStr(e.importance),
        'status': _jStatusToStr(e.status),
        'authorId': e.authorId,
        'authorName': e.authorName,
        'createdAt': Timestamp.fromDate(e.createdAt),
        'updatedAt': Timestamp.fromDate(e.updatedAt),
      };

  AppNotification _notifFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return AppNotification(
      id: doc.id,
      type: _notifTypeFromStr(d['type'] ?? 'informational'),
      title: d['title'] ?? '',
      message: d['message'] ?? '',
      recipientIds: List<String>.from(d['recipientIds'] ?? []),
      isRead: d['isRead'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sentAt: (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  BoilerHouse _boilerhouseFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return BoilerHouse(
      id: doc.id,
      name: d['name'] ?? '',
      district: d['district'] ?? '',
      address: d['address'] ?? '',
      yearBuilt: d['yearBuilt'] ?? 0,
      modernizationYear: d['modernizationYear'] ?? 0,
      totalArea: (d['totalArea'] ?? 0).toDouble(),
      workersCount: d['workersCount'] ?? 0,
      operatorsCount: d['operatorsCount'] ?? 0,
      installedCapacity: (d['installedCapacity'] ?? 0).toDouble(),
      connectedLoad: (d['connectedLoad'] ?? 0).toDouble(),
      consumers: d['consumers'] ?? '',
      pipelineLength: (d['pipelineLength'] ?? 0).toDouble(),
      dispatchPhone: d['dispatchPhone'] ?? '',
      annualElectricity: (d['annualElectricity'] ?? 0).toDouble(),
      annualWater: (d['annualWater'] ?? 0).toDouble(),
      annualGas: (d['annualGas'] ?? 0).toDouble(),
      annualHeatProduction: (d['annualHeatProduction'] ?? 0).toDouble(),
      aboveGroundPipeline: (d['aboveGroundPipeline'] ?? 0).toDouble(),
      belowGroundPipeline: (d['belowGroundPipeline'] ?? 0).toDouble(),
      defects: d['defects'] ?? '',
      locationUrl: d['locationUrl'] ?? '',
      status: _bhStatusFromStr(d['status'] ?? 'operating'),
    );
  }

  Map<String, dynamic> _boilerhouseToMap(BoilerHouse b) => {
        'id': b.id,
        'name': b.name,
        'district': b.district,
        'address': b.address,
        'yearBuilt': b.yearBuilt,
        'modernizationYear': b.modernizationYear,
        'totalArea': b.totalArea,
        'workersCount': b.workersCount,
        'operatorsCount': b.operatorsCount,
        'installedCapacity': b.installedCapacity,
        'connectedLoad': b.connectedLoad,
        'consumers': b.consumers,
        'pipelineLength': b.pipelineLength,
        'dispatchPhone': b.dispatchPhone,
        'annualElectricity': b.annualElectricity,
        'annualWater': b.annualWater,
        'annualGas': b.annualGas,
        'annualHeatProduction': b.annualHeatProduction,
        'aboveGroundPipeline': b.aboveGroundPipeline,
        'belowGroundPipeline': b.belowGroundPipeline,
        'defects': b.defects,
        'locationUrl': b.locationUrl,
        'status': _bhStatusToStr(b.status),
      };

  Equipment _equipmentFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Equipment(
      id: doc.id,
      boilerHouseId: d['boilerHouseId'] ?? '',
      type: _eqTypeFromStr(d['type'] ?? 'other'),
      name: d['name'] ?? '',
      model: d['model'] ?? '',
      manufacturer: d['manufacturer'] ?? '',
      serialNumber: d['serialNumber'] ?? '',
      inventoryNumber: d['inventoryNumber'] ?? '',
      productionDate: (d['productionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      installedDate: (d['installedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _eqStatusFromStr(d['status'] ?? 'operating'),
      lastServiceDate: (d['lastServiceDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nextServiceDate: (d['nextServiceDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      responsiblePersonId: d['responsiblePersonId'] ?? '',
      notes: d['notes'] ?? '',
    );
  }

  Map<String, dynamic> _equipmentToMap(Equipment e) => {
        'id': e.id,
        'boilerHouseId': e.boilerHouseId,
        'type': _eqTypeToStr(e.type),
        'name': e.name,
        'model': e.model,
        'manufacturer': e.manufacturer,
        'serialNumber': e.serialNumber,
        'inventoryNumber': e.inventoryNumber,
        'productionDate': Timestamp.fromDate(e.productionDate),
        'installedDate': Timestamp.fromDate(e.installedDate),
        'status': _eqStatusToStr(e.status),
        'lastServiceDate': Timestamp.fromDate(e.lastServiceDate),
        'nextServiceDate': Timestamp.fromDate(e.nextServiceDate),
        'responsiblePersonId': e.responsiblePersonId,
        'notes': e.notes,
      };

  Instruction _instructionFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Instruction(
      id: doc.id,
      title: d['title'] ?? '',
      category: d['category'] ?? '',
      body: d['body'] ?? '',
      version: d['version'] ?? '1.0',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      authorId: d['authorId'] ?? '',
      urgency: (d['urgency'] == 'mandatory') ? InstructionUrgency.mandatory : InstructionUrgency.normal,
    );
  }

  Map<String, dynamic> _instructionToMap(Instruction i) => {
        'id': i.id,
        'title': i.title,
        'category': i.category,
        'body': i.body,
        'version': i.version,
        'createdAt': Timestamp.fromDate(i.createdAt),
        'updatedAt': Timestamp.fromDate(i.updatedAt),
        'authorId': i.authorId,
        'urgency': i.urgency == InstructionUrgency.mandatory ? 'mandatory' : 'normal',
      };

  Drawing _drawingFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Drawing(
      id: doc.id,
      title: d['title'] ?? '',
      number: d['number'] ?? '',
      category: d['category'] ?? '',
      description: d['description'] ?? '',
      boilerHouseId: d['boilerHouseId'] ?? '',
      filePath: d['filePath'] ?? '',
      authorId: d['authorId'] ?? '',
      addedAt: (d['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _drawingToMap(Drawing d) => {
        'id': d.id,
        'title': d.title,
        'number': d.number,
        'category': d.category,
        'description': d.description,
        'boilerHouseId': d.boilerHouseId,
        'filePath': d.filePath,
        'authorId': d.authorId,
        'addedAt': Timestamp.fromDate(d.addedAt),
      };

  // ChangeLog mappers
  ChangeLogEntry _changeLogFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ChangeLogEntry(
      id: doc.id,
      boilerHouseId: d['boilerHouseId'] ?? '',
      title: d['title'] ?? '',
      text: d['text'] ?? '',
      photoUrls: List<String>.from(d['photoUrls'] ?? []),
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _changeLogToMap(ChangeLogEntry e) => {
        'boilerHouseId': e.boilerHouseId,
        'title': e.title,
        'text': e.text,
        'photoUrls': e.photoUrls,
        'authorId': e.authorId,
        'authorName': e.authorName,
        'createdAt': Timestamp.fromDate(e.createdAt),
      };

  ChangeLogReaction _reactionFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ChangeLogReaction(
      id: doc.id,
      changeLogId: d['changeLogId'] ?? '',
      text: d['text'] ?? '',
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _reactionToMap(ChangeLogReaction r) => {
        'changeLogId': r.changeLogId,
        'text': r.text,
        'authorId': r.authorId,
        'authorName': r.authorName,
        'createdAt': Timestamp.fromDate(r.createdAt),
      };

  // Enum string conversions
  UserRole _roleFromStr(String s) {
    switch (s) {
      case 'admin': return UserRole.admin;
      case 'coAdmin': return UserRole.coAdmin;
      default: return UserRole.member;
    }
  }

  String _roleToStr(UserRole r) {
    switch (r) {
      case UserRole.admin: return 'admin';
      case UserRole.coAdmin: return 'coAdmin';
      case UserRole.member: return 'member';
    }
  }

  UserStatus _statusFromStr(String s) {
    switch (s) {
      case 'active': return UserStatus.active;
      case 'blocked': return UserStatus.blocked;
      default: return UserStatus.pending;
    }
  }

  JournalEntryImportance _importanceFromStr(String s) {
    switch (s) {
      case 'important': return JournalEntryImportance.important;
      case 'critical': return JournalEntryImportance.critical;
      default: return JournalEntryImportance.normal;
    }
  }

  String _importanceToStr(JournalEntryImportance i) {
    switch (i) {
      case JournalEntryImportance.normal: return 'normal';
      case JournalEntryImportance.important: return 'important';
      case JournalEntryImportance.critical: return 'critical';
    }
  }

  JournalEntryStatus _jStatusFromStr(String s) {
    switch (s) {
      case 'inProgress': return JournalEntryStatus.inProgress;
      case 'closed': return JournalEntryStatus.closed;
      default: return JournalEntryStatus.open;
    }
  }

  String _jStatusToStr(JournalEntryStatus s) {
    switch (s) {
      case JournalEntryStatus.open: return 'open';
      case JournalEntryStatus.inProgress: return 'inProgress';
      case JournalEntryStatus.closed: return 'closed';
    }
  }

  AppNotificationType _notifTypeFromStr(String s) {
    switch (s) {
      case 'emergency': return AppNotificationType.emergency;
      case 'important': return AppNotificationType.important;
      case 'system': return AppNotificationType.system;
      default: return AppNotificationType.informational;
    }
  }

  BoilerHouseStatus _bhStatusFromStr(String s) {
    switch (s) {
      case 'maintenance': return BoilerHouseStatus.maintenance;
      case 'emergencyShutdown': return BoilerHouseStatus.emergencyShutdown;
      case 'mothballed': return BoilerHouseStatus.mothballed;
      default: return BoilerHouseStatus.operating;
    }
  }

  String _bhStatusToStr(BoilerHouseStatus s) {
    switch (s) {
      case BoilerHouseStatus.operating: return 'operating';
      case BoilerHouseStatus.maintenance: return 'maintenance';
      case BoilerHouseStatus.emergencyShutdown: return 'emergencyShutdown';
      case BoilerHouseStatus.mothballed: return 'mothballed';
    }
  }

  EquipmentType _eqTypeFromStr(String s) {
    switch (s) {
      case 'boiler': return EquipmentType.boiler;
      case 'pump': return EquipmentType.pump;
      case 'heatExchanger': return EquipmentType.heatExchanger;
      case 'burner': return EquipmentType.burner;
      case 'expansionTank': return EquipmentType.expansionTank;
      default: return EquipmentType.other;
    }
  }

  String _eqTypeToStr(EquipmentType t) {
    switch (t) {
      case EquipmentType.boiler: return 'boiler';
      case EquipmentType.pump: return 'pump';
      case EquipmentType.heatExchanger: return 'heatExchanger';
      case EquipmentType.burner: return 'burner';
      case EquipmentType.expansionTank: return 'expansionTank';
      case EquipmentType.other: return 'other';
    }
  }

  EquipmentStatus _eqStatusFromStr(String s) {
    switch (s) {
      case 'standby': return EquipmentStatus.standby;
      case 'maintenance': return EquipmentStatus.maintenance;
      case 'decommissioned': return EquipmentStatus.decommissioned;
      default: return EquipmentStatus.operating;
    }
  }

  String _eqStatusToStr(EquipmentStatus s) {
    switch (s) {
      case EquipmentStatus.operating: return 'operating';
      case EquipmentStatus.standby: return 'standby';
      case EquipmentStatus.maintenance: return 'maintenance';
      case EquipmentStatus.decommissioned: return 'decommissioned';
    }
  }

  // ═══ Shifts ══════════════════════════════════════════════════════════════
  CollectionReference<Map<String, dynamic>> get _shifts => _db.collection('shifts');

  /// Shifts whose day falls in [from, to). Single-field range — no composite
  /// index needed.
  Stream<List<Shift>> shiftsStream({required DateTime from, required DateTime to}) {
    return _shifts
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThan: Timestamp.fromDate(to))
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs.map(_shiftFromDoc).toList());
  }

  Future<void> addShift(Shift s) =>
      _trackWrite(_shifts.doc(s.id).set(_shiftToMap(s)));
  Future<void> updateShift(Shift s) =>
      _trackWrite(_shifts.doc(s.id).update(_shiftToMap(s)));
  Future<void> deleteShift(String id) =>
      _trackWrite(_shifts.doc(id).delete());

  Shift _shiftFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Shift(
      id: doc.id,
      boilerHouseId: d['boilerHouseId'] ?? '',
      boilerHouseName: d['boilerHouseName'] ?? '',
      operatorId: d['operatorId'] ?? '',
      operatorName: d['operatorName'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: d['type'] == 'night' ? ShiftType.night : ShiftType.day,
      note: d['note'] ?? '',
      createdBy: d['createdBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _shiftToMap(Shift s) => {
        'boilerHouseId': s.boilerHouseId,
        'boilerHouseName': s.boilerHouseName,
        'operatorId': s.operatorId,
        'operatorName': s.operatorName,
        'date': Timestamp.fromDate(DateTime(s.date.year, s.date.month, s.date.day)),
        'type': s.type == ShiftType.night ? 'night' : 'day',
        'note': s.note,
        'createdBy': s.createdBy,
        'createdAt': Timestamp.fromDate(s.createdAt),
      };

  // ═══ Audit Log ═══════════════════════════════════════════════════════════
  CollectionReference<Map<String, dynamic>> get _auditLog => _db.collection('audit_log');

  Future<void> logAudit(AuditEntry e) => _trackWrite(_auditLog.doc(e.id).set({
    'userId': e.userId,
    'userName': e.userName,
    'action': e.action.name,
    'targetType': e.targetType,
    'targetId': e.targetId,
    'targetName': e.targetName,
    'createdAt': Timestamp.fromDate(e.createdAt),
  }));

  Stream<List<AuditEntry>> auditLogStream() {
    return _auditLog.orderBy('createdAt', descending: true).limit(200)
        .snapshots().map((s) => s.docs.map(_auditFromDoc).toList());
  }

  AuditEntry _auditFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return AuditEntry(
      id: doc.id,
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? '',
      action: AuditAction.values.firstWhere((a) => a.name == d['action'], orElse: () => AuditAction.edit),
      targetType: d['targetType'] ?? '',
      targetId: d['targetId'] ?? '',
      targetName: d['targetName'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
