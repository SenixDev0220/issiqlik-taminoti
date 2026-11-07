import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/firestore_sync_tracker.dart';
import '../core/security_policy.dart';
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

/// Spark-compatible operations. Firestore rules are authoritative.
class FirebaseService {
  FirebaseService._();
  static final instance = FirebaseService._();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  static const _server = GetOptions(source: Source.server);
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _access => _db.collection('access');
  CollectionReference<Map<String, dynamic>> get _directory => _db.collection('employeeDirectory');
  CollectionReference<Map<String, dynamic>> get _profiles => _db.collection('userProfiles');
  CollectionReference<Map<String, dynamic>> get _journal => _db.collection('journal');
  CollectionReference<Map<String, dynamic>> get _notifications => _db.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _boilerhouses => _db.collection('boilerhouses');
  CollectionReference<Map<String, dynamic>> get _equipment => _db.collection('equipment');
  CollectionReference<Map<String, dynamic>> get _instructions => _db.collection('instructions');
  CollectionReference<Map<String, dynamic>> get _drawings => _db.collection('drawings');
  CollectionReference<Map<String, dynamic>> get _changeLogs => _db.collection('changeLogs');
  CollectionReference<Map<String, dynamic>> get _shifts => _db.collection('shifts');
  CollectionReference<Map<String, dynamic>> get _auditLog => _db.collection('audit_log');
  Future<T> _trackWrite<T>(Future<T> write) => FirestoreSyncTracker.instance.trackWrite(write);
  String? get currentUid => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  String _toEmail(String login) => '${SecurityPolicy.normalizeLogin(login)}@khorazm-issiklik.app';

  /// Compatibility only: imports require a reviewed operator, never client seeding.
  Future<void> seedIfEmpty() async {}
  Future<AppUser?> signIn(String login, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: _toEmail(login), password: password);
      final user = await fetchUser(cred.user!.uid).timeout(const Duration(seconds: 20));
      if (user == null) await signOut();
      return user;
    } catch (_) { await signOut(); return null; }
  }
  Future<String?> register({required String login, required String password,
    required String firstName, required String lastName, required String phone}) async {
    login = SecurityPolicy.normalizeLogin(login); phone = SecurityPolicy.normalizePhone(phone);
    firstName = firstName.trim(); lastName = lastName.trim();
    if (!SecurityPolicy.validLogin(login) || !SecurityPolicy.validPhone(phone) ||
        firstName.isEmpty || firstName.length > 80 || lastName.isEmpty || lastName.length > 80) {
      return 'Login, ism yoki telefon formati noto‘g‘ri';
    }
    if (password.length < 12) return 'Parol kamida 12 belgidan iborat bo‘lsin';
    try {
      User user;
      try {
        user = (await _auth.createUserWithEmailAndPassword(email: _toEmail(login), password: password)).user!;
      } on FirebaseAuthException catch (error) {
        if (error.code != 'email-already-in-use') rethrow;
        user = (await _auth.signInWithEmailAndPassword(email: _toEmail(login), password: password)).user!;
      }
      final uid = user.uid;
      await _trackWrite(_db.runTransaction((transaction) async {
        final access = await transaction.get(_access.doc(uid));
        final profile = await transaction.get(_users.doc(uid));
        if (access.exists || profile.exists) {
          final a = access.data();
          final p = profile.data();
          if (a != null && p != null && a['role'] == 'member' && a['status'] == 'pending' &&
              p['role'] == 'member' && p['status'] == 'pending' && p['id'] == uid &&
              p['login'] == login && p['phone'] == phone && p['firstName'] == firstName && p['lastName'] == lastName &&
              (a['boilerhouseIds'] as List?)?.isEmpty == true &&
              a['sessionValidAfter'] == Timestamp.fromMillisecondsSinceEpoch(0)) {
            return;
          }
          throw StateError('Hisob administrator tekshiruvini talab qiladi');
        }
        final data = <String,dynamic>{'id':uid,'login':login,'firstName':firstName,'lastName':lastName,
          'phone':phone,'position':'','photoUrl':'','role':'member','status':'pending',
          'boilerhouseIds':<String>[],'sessionValidAfter':Timestamp.fromMillisecondsSinceEpoch(0),
          'createdAt':FieldValue.serverTimestamp()};
        transaction.set(_users.doc(uid),data); transaction.set(_directory.doc(uid),data);
        transaction.set(_access.doc(uid),_authority(data)); transaction.set(_profiles.doc(uid),_profile(data));
        transaction.set(_db.collection('phoneClaims').doc(phone),{'uid':uid,'createdAt':FieldValue.serverTimestamp()});
      }));
      return null;
    } on FirebaseAuthException {
      return 'Ro‘yxatdan o‘tish bajarilmadi. Mavjud login bo‘lsa, uning parolidan foydalaning.';
    } on FirebaseException {
      return 'Ro‘yxatdan o‘tish bajarilmadi. Telefon band yoki ruxsat/tarmoq mavjud emas. Administratorga murojaat qiling.';
    } on StateError {
      return 'Hisob ma’lumotlarini administrator tekshirishi kerak. Mavjud hisob o‘zgartirilmadi.';
    } finally {
      await signOut();
    }
  }
  Future<void> signOut() async {
    try { await _auth.signOut(); } finally { FirestoreSyncTracker.instance.reset(); }
  }
  Future<void> waitForPendingWrites() => _trackWrite(_db.waitForPendingWrites());
  Future<String?> requestPasswordReset(String login) async =>
    'Parolni tiklash uchun administratorga murojaat qiling. Login haqiqiy email emas; shaxsni tekshirib operator tiklaydi.';
  Future<void> adminResetPassword(String login, String newPassword) async => throw UnsupportedError(
    'Parol ilovadan tiklanmaydi. Shaxsni tasdiqlab, vakolatli Firebase Auth operatoriga murojaat qiling.');
  Future<String?> deleteAccount(String uid) async =>
    'Hisobni yopish uchun administratorga murojaat qiling. Operator kirishni bekor qiladi va jurnal tarixini saqlaydi.';
  Future<String?> changePassword({required String currentPassword,required String newPassword}) async {
    final u = _auth.currentUser;
    if (u == null || u.email == null) return 'Tizimga kirilmagan';
    if (newPassword.length < 12) return 'Parol kamida 12 belgidan iborat bo‘lsin';
    try {
      await u.reauthenticateWithCredential(EmailAuthProvider.credential(email:u.email!,password:currentPassword));
      await u.updatePassword(newPassword); return null;
    } on FirebaseAuthException { return 'Parol yangilanmadi. Joriy parol va tarmoqni tekshiring.'; }
  }
  /// Never authorize from cached grants or legacy users.role alone.
  Future<AppUser?> fetchUser(String uid) async {
    if (currentUid != uid) return null;
    return _validatedUser(uid, await _access.doc(uid).get(_server));
  }
  Future<AppUser?> _validatedUser(String uid, DocumentSnapshot<Map<String,dynamic>> a) async {
    final d = a.data(); final auth = _auth.currentUser;
    if (d == null || auth?.uid != uid || a.metadata.isFromCache || a.metadata.hasPendingWrites) return null;
    if (!['admin','coAdmin','member'].contains(d['role']) || !['active','pending','blocked'].contains(d['status'])) return null;
    final cutoff = d['sessionValidAfter']; final token = await auth!.getIdTokenResult(); final authTime = token.authTime;
    if (cutoff is! Timestamp || authTime == null || authTime.isBefore(cutoff.toDate())) return null;
    final doc = await _users.doc(uid).get(_server); final data = doc.data();
    if (data == null || data['role'] != d['role'] || data['status'] != d['status'] || data['sessionValidAfter'] != cutoff ||
        !listEquals(data['boilerhouseIds'] as List?,d['boilerhouseIds'] as List?)) return null;
    return _userFromDoc(doc);
  }
  Stream<AppUser?> currentUserStream(String uid) =>
    _access.doc(uid).snapshots(includeMetadataChanges:true).asyncMap((doc) async {
      FirestoreSyncTracker.instance.reportSnapshot(source:'current-user-$uid',isFromCache:doc.metadata.isFromCache,hasPendingWrites:doc.metadata.hasPendingWrites);
      if (doc.metadata.isFromCache || doc.metadata.hasPendingWrites) return fetchUser(uid);
      return _validatedUser(uid,doc);
    });
  Future<AppUser> _requireUser({bool manager=false,bool admin=false}) async {
    final uid = currentUid; final u = uid == null ? null : await fetchUser(uid);
    if (!SecurityPolicy.isActive(u) || (manager && !SecurityPolicy.isManager(u)) || (admin && u!.role != UserRole.admin)) {
      throw StateError('Ruxsat yo‘q. Qayta tizimga kiring.');
    }
    return u!;
  }
  Map<String,dynamic> _authority(Map<String,dynamic> d) => {'role':d['role'],'status':d['status'],'boilerhouseIds':d['boilerhouseIds'],'sessionValidAfter':d['sessionValidAfter']};
  Map<String,dynamic> _profile(Map<String,dynamic> d) => {for (final k in ['id','firstName','lastName','position','photoUrl','role','status']) k:d[k]};
  Stream<List<AppUser>> allUsersStream({AppUser? user}) {
    if (!SecurityPolicy.isActive(user)) return Stream.value([]);
    final Query<Map<String,dynamic>> q = SecurityPolicy.isManager(user) ? _directory.orderBy('createdAt') : _profiles.where('status',isEqualTo:'active');
    return q.snapshots().map((s)=>s.docs.map(_userFromDoc).toList());
  }
  Future<void> _editUser(String uid, Map<String,dynamic> changes,{bool selfPosition=false}) async {
    final actor = await _requireUser(admin:!selfPosition);
    if (uid == actor.id && !selfPosition) throw StateError('O‘z vakolatingizni o‘zgartirib bo‘lmaydi');
    await _trackWrite(_db.runTransaction((tx) async {
      final ref = selfPosition && uid == actor.id ? _users.doc(uid) : _directory.doc(uid);
      final snap = await tx.get(ref); if (!snap.exists) throw StateError('Foydalanuvchi topilmadi');
      final data = {...snap.data()!,...changes};
      if (!selfPosition && snap.data()!['role'] == 'admin') throw StateError('Admin vakolati faqat operator orqali o‘zgartiriladi');
      tx.set(_users.doc(uid),data); tx.set(_directory.doc(uid),data); tx.set(_profiles.doc(uid),_profile(data));
      if (!selfPosition) tx.set(_access.doc(uid),_authority(data));
    }));
  }
  Future<void> approveUser(String uid) => _editUser(uid,{'status':'active'});
  Future<void> declineUser(String uid) => banUser(uid);
  Future<void> banUser(String uid) => _editUser(uid,{'status':'blocked','sessionValidAfter':FieldValue.serverTimestamp()});
  Future<void> unbanUser(String uid) => _editUser(uid,{'status':'active'});
  Future<void> changeRole(String uid,UserRole role) async {
    if (role == UserRole.admin) throw UnsupportedError('Admin tayinlash faqat tekshirilgan operator orqali bajariladi');
    await _editUser(uid,{'role':_roleToStr(role)});
  }
  Future<void> assignBoilerhouses(String uid,List<String> ids) async {
    if (ids.length > 30 || ids.toSet().length != ids.length) throw ArgumentError('Ko‘pi bilan 30 ta takrorlanmas qozonxona');
    await _requireUser(admin:true);
    for (final id in ids) { if (!(await _boilerhouses.doc(id).get(_server)).exists) throw ArgumentError('Qozonxona topilmadi'); }
    await _editUser(uid,{'boilerhouseIds':ids});
  }
  Future<void> updateUserPosition(String uid,String position) => _editUser(uid,{'position':position.trim()},selfPosition:uid == currentUid);
  Future<void> updateUserPhoto(String uid,String photoUrl) async => throw UnsupportedError('Fayl yuklash o‘chirilgan');
  Future<void> saveFcmToken(String uid,String token) async => throw UnsupportedError('Spark rejimida server push mavjud emas');
  Future<void> clearFcmToken(String uid) async {} // No client token collection exists.
  Query<Map<String,dynamic>>? _scope(CollectionReference<Map<String,dynamic>> col,AppUser? user,{bool documentIds=false}) {
    if (!SecurityPolicy.isActive(user) || user!.id != currentUid) return null;
    if (SecurityPolicy.isManager(user)) return col;
    final ids = user.boilerhouseIds.toSet().toList();
    if (ids.isEmpty || ids.length > 30) return null;
    return col.where(documentIds ? FieldPath.documentId : 'boilerHouseId',whereIn:ids);
  }
  Stream<List<T>> _scopedStream<T>(CollectionReference<Map<String,dynamic>> col,AppUser? user,
      T Function(DocumentSnapshot<Map<String,dynamic>>) mapper,{bool documentIds=false}) {
    final q = _scope(col,user,documentIds:documentIds);
    return q == null ? Stream.value([]) : q.snapshots().map((s)=>s.docs.map(mapper).toList());
  }
  Stream<List<BoilerHouse>> boilerhousesStream({AppUser? user}) => _scopedStream(_boilerhouses,user,_boilerhouseFromDoc,documentIds:true);
  Stream<List<Equipment>> equipmentStream({AppUser? user}) => _scopedStream(_equipment,user,_equipmentFromDoc);
  Stream<List<Drawing>> drawingsStream({AppUser? user}) => _scopedStream(_drawings,user,_drawingFromDoc);
  Stream<List<Instruction>> instructionsStream({AppUser? user}) => !SecurityPolicy.isActive(user)
    ? Stream.value([]) : _instructions.snapshots().map((s)=>s.docs.map(_instructionFromDoc).toList());
  Stream<List<JournalEntry>> journalStream({AppUser? user}) {
    final q = _scope(_journal,user);
    return q == null ? Stream.value([]) : q.where('deleted',isEqualTo:false).orderBy('eventDateTime',descending:true).limit(100)
      .snapshots().map((s)=>s.docs.map(_entryFromDoc).toList());
  }
  Future<void> addJournalEntry(JournalEntry e) async {
    final u = await _requireUser();
    if (e.photoPaths.isNotEmpty) throw UnsupportedError('Fayl yuklash o‘chirilgan');
    await _trackWrite(_journal.doc(e.id).set({..._entryToMap(e),'authorId':u.id,'authorName':u.fullName,
      'createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp(),'version':1,'historyId':'','deleted':false}));
  }
  Future<void> updateJournalEntry(JournalEntry e) => _reviseJournal(e.id,entry:e);
  Future<void> deleteJournalEntry(String id) => _reviseJournal(id,deleted:true);
  Future<void> _reviseJournal(String id,{JournalEntry? entry,bool deleted=false}) async {
    final u = await _requireUser(); final ref = _journal.doc(id); final history = ref.collection('history').doc();
    await _trackWrite(_db.runTransaction((tx) async {
      final snap = await tx.get(ref); final before = snap.data();
      if (before == null || before['deleted'] != false) throw StateError('Yozuv mavjud emas');
      final version = (before['version'] as int) + 1;
      final changes = <String,dynamic>{'updatedAt':FieldValue.serverTimestamp(),'version':version,'historyId':history.id,'deleted':deleted};
      if (entry != null) {
        if (entry.photoPaths.isNotEmpty) throw UnsupportedError('Fayl yuklash o‘chirilgan');
        changes.addAll({'category':entry.category,'title':entry.title,'description':entry.description,
          'importance':_importanceToStr(entry.importance),'status':_jStatusToStr(entry.status)});
      }
      tx.update(ref,changes);
      tx.set(history,{'journalId':id,'boilerHouseId':before['boilerHouseId'],'actorId':u.id,'createdAt':FieldValue.serverTimestamp(),
        'operation':deleted?'delete':'update','before':before,'version':version});
    }));
  }
  Stream<List<AppNotification>> notificationsStream(String userId) {
    if (userId != currentUid) return Stream.value([]);
    return _notifications.where('recipientId',isEqualTo:userId).orderBy('sentAt',descending:true).limit(100)
      .snapshots().map((s)=>s.docs.map(_notifFromDoc).toList());
  }
  Future<void> markNotificationRead(String id) => _trackWrite(_notifications.doc(id).update({'isRead':true}));
  Future<void> markAllNotificationsRead(String userId) async {
    if (userId != currentUid) throw StateError('Ruxsat yo‘q');
    while (true) {
      final s = await _notifications.where('recipientId',isEqualTo:userId).where('isRead',isEqualTo:false).limit(100).get(_server);
      if (s.docs.isEmpty) return;
      final batch = _db.batch(); for (final d in s.docs) { batch.update(d.reference,{'isRead':true}); }
      await _trackWrite(batch.commit());
    }
  }
  Future<void> broadcastNotification({required String title,required String message}) async {
    await _requireUser(manager:true);
    final snap = await _access.where('status',isEqualTo:'active').limit(101).get(_server);
    if (snap.docs.length > 100) throw StateError('Bir yuborishda ko‘pi bilan 100 oluvchi. Alohida guruh tanlang.');
    if (snap.docs.isEmpty) throw StateError('Faol oluvchi topilmadi');
    await sendNotification(title:title,message:message,recipientIds:snap.docs.map((d)=>d.id).toList());
  }
  Future<void> sendNotification({required String title,required String message,required List<String> recipientIds}) async {
    final u = await _requireUser(manager:true);
    if (recipientIds.isEmpty || recipientIds.length > 100 || recipientIds.toSet().length != recipientIds.length) throw ArgumentError('1–100 ta takrorlanmas oluvchi talab qilinadi');
    if (title.trim().isEmpty || title.length > 200 || message.trim().isEmpty || message.length > 4000) throw ArgumentError('Xabar matni noto‘g‘ri');
    // One recipient per document; <=8 distinct recipient access lookups per batch.
    for (var i=0;i<recipientIds.length;i+=8) {
      final batch = _db.batch();
      for (final uid in recipientIds.skip(i).take(8)) {
        batch.set(_notifications.doc(),{'recipientId':uid,'senderId':u.id,'type':'important','title':title,'message':message,
          'isRead':false,'createdAt':FieldValue.serverTimestamp(),'sentAt':FieldValue.serverTimestamp()});
      }
      await _trackWrite(batch.commit());
    }
  }
  Future<void> addBoilerhouse(BoilerHouse b) => _trackWrite(_boilerhouses.doc(b.id).set(_boilerhouseToMap(b)));
  Future<void> updateBoilerhouse(BoilerHouse b) => _trackWrite(_boilerhouses.doc(b.id).update(_boilerhouseToMap(b)));
  Future<void> deleteBoilerhouse(String id) => _trackWrite(_boilerhouses.doc(id).delete());
  Future<void> addEquipment(Equipment e) => _trackWrite(_equipment.doc(e.id).set(_equipmentToMap(e)));
  Future<void> updateEquipment(Equipment e) => _trackWrite(_equipment.doc(e.id).update(_equipmentToMap(e)));
  Future<void> deleteEquipment(String id) => _trackWrite(_equipment.doc(id).delete());
  Future<void> addInstruction(Instruction i) async {
    final u = await _requireUser(manager:true);
    await _trackWrite(_instructions.doc(i.id).set({..._instructionToMap(i),'authorId':u.id,
      'createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()}));
  }
  Future<void> updateInstruction(Instruction i) => _trackWrite(_instructions.doc(i.id).update({..._instructionToMap(i),'updatedAt':FieldValue.serverTimestamp()}));
  Future<void> deleteInstruction(String id) => _trackWrite(_instructions.doc(id).delete());
  void _validateDrawing(Drawing d) {
    if (d.filePath.isNotEmpty && !SecurityPolicy.isBundledDrawing(d.filePath)) throw ArgumentError('Faqat tasdiqlangan ilova sxemalari ruxsat etilgan');
  }
  Future<void> addDrawing(Drawing d) async {
    _validateDrawing(d); final u = await _requireUser(manager:true);
    await _trackWrite(_drawings.doc(d.id).set({..._drawingToMap(d),'authorId':u.id,'addedAt':FieldValue.serverTimestamp()}));
  }
  Future<void> updateDrawing(Drawing d) async { _validateDrawing(d); await _trackWrite(_drawings.doc(d.id).update(_drawingToMap(d))); }
  Future<void> deleteDrawing(String id) => _trackWrite(_drawings.doc(id).delete());
  Stream<List<ChangeLogEntry>> changeLogsStream(String boilerHouseId) => _changeLogs.where('boilerHouseId',isEqualTo:boilerHouseId)
    .orderBy('createdAt',descending:true).limit(50).snapshots().map((s)=>s.docs.map(_changeLogFromDoc).toList());
  Future<void> addChangeLog(ChangeLogEntry e) async {
    final u = await _requireUser();
    if (e.photoUrls.isNotEmpty) throw UnsupportedError('Fayl yuklash o‘chirilgan');
    await _trackWrite(_changeLogs.doc(e.id).set({..._changeLogToMap(e),'authorId':u.id,'authorName':u.fullName,'createdAt':FieldValue.serverTimestamp()}));
  }
  Future<void> deleteChangeLog(String id) async => throw UnsupportedError('Tarix o‘chirilmaydi; tuzatish yozuvini qo‘shing');
  Stream<List<ChangeLogReaction>> reactionsStream(String id) => _changeLogs.doc(id).collection('reactions').orderBy('createdAt')
    .snapshots().map((s)=>s.docs.map(_reactionFromDoc).toList());
  Future<void> addReaction(ChangeLogReaction r) async {
    final u = await _requireUser();
    await _trackWrite(_changeLogs.doc(r.changeLogId).collection('reactions').doc(r.id).set({
      ..._reactionToMap(r),'authorId':u.id,'authorName':u.fullName,'createdAt':FieldValue.serverTimestamp()}));
  }
  Future<void> deleteReaction(String id,String reactionId) async => throw UnsupportedError('Tarix o‘chirilmaydi; tuzatish izohini qo‘shing');
  Future<String> uploadFile({required File file,required String folder}) async => throw UnsupportedError('Fayl yuklash o‘chirilgan. Maxfiy fayllar uchun operatorga murojaat qiling.');
  Future<List<String>> uploadFiles({required List<File> files,required String folder}) async => throw UnsupportedError('Fayl yuklash o‘chirilgan');
  Stream<List<Shift>> shiftsStream({required DateTime from,required DateTime to,AppUser? user}) {
    final q = _scope(_shifts,user);
    return q == null ? Stream.value([]) : q.where('date',isGreaterThanOrEqualTo:Timestamp.fromDate(from))
      .where('date',isLessThan:Timestamp.fromDate(to)).orderBy('date').snapshots().map((s)=>s.docs.map(_shiftFromDoc).toList());
  }
  Future<void> addShift(Shift s) async {
    final u = await _requireUser(manager:true);
    await _trackWrite(_shifts.doc(s.id).set({..._shiftToMap(s),'createdBy':u.id,'createdAt':FieldValue.serverTimestamp()}));
  }
  Future<void> updateShift(Shift s) => _trackWrite(_shifts.doc(s.id).update(_shiftToMap(s)));
  Future<void> deleteShift(String id) => _trackWrite(_shifts.doc(id).delete());
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
      recipientIds: [d['recipientId'] as String],
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


  Future<void> logAudit(AuditEntry e) => _trackWrite(_auditLog.doc(e.id).set({
    'userId': e.userId,
    'userName': e.userName,
    'action': e.action.name,
    'targetType': e.targetType,
    'targetId': e.targetId,
    'targetName': e.targetName,
    'createdAt': FieldValue.serverTimestamp(),
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
