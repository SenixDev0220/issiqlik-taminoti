import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/data_quality.dart';
import 'account_access.dart';
import 'auth_result.dart';
import 'bounded_operations.dart';
import 'document_codec.dart';
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

  String? _validatedUid;
  int _sessionGeneration = 0;
  Future<void>? _signOutOperation;

  String newDocumentId(String collection) {
    if (!const {'boilerhouses', 'equipment', 'journal', 'instructions', 'drawings', 'shifts', 'changeLogs', 'reactions', 'notifications'}.contains(collection)) {
      throw ArgumentError.value(collection, 'collection');
    }
    return _db.collection(collection).doc().id;
  }

  Future<SignInResult> signIn(String login, String password) async {
    _validatedUid = null;
    try {
      if (_signOutOperation != null) await _signOutOperation;
      final credential = await _auth.signInWithEmailAndPassword(email: _toEmail(login), password: password);
      final uid = credential.user?.uid;
      if (uid == null) throw const AuthFlowException(AuthFailure.internal);
      final user = await fetchUser(uid).timeout(const Duration(seconds: 20));
      if (user == null) throw const AuthFlowException(AuthFailure.reauthenticationRequired);
      _validatedUid = uid;
      return SignInResult.success(user);
    } catch (error) {
      final failure = classifyAuthFailure(error);
      await _finishSessionSafely();
      return SignInResult.failure(failure);
    }
  }

  Future<RegistrationResult> register({required String login, required String password,
    required String firstName, required String lastName, required String phone}) {
    _validatedUid = null;
    return completeRegistrationFlow(operation: () async {
      if (_signOutOperation != null) await _signOutOperation;
      login = SecurityPolicy.normalizeLogin(login);
      phone = SecurityPolicy.normalizePhone(phone);
      firstName = firstName.trim(); lastName = lastName.trim();
      if (!SecurityPolicy.validLogin(login) || !SecurityPolicy.validPhone(phone) ||
          firstName.isEmpty || firstName.length > 80 || lastName.isEmpty || lastName.length > 80 ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch('$firstName$lastName') || password.length < 12 || password.length > 64) {
        throw const AuthFlowException(AuthFailure.invalidInput);
      }
      User user;
      try {
        user = (await _auth.createUserWithEmailAndPassword(email: _toEmail(login), password: password)).user!;
      } on FirebaseAuthException catch (error) {
        if (error.code != 'email-already-in-use') rethrow;
        user = (await _auth.signInWithEmailAndPassword(email: _toEmail(login), password: password)).user!;
      }
      final uid = user.uid;
      await _trackWrite(_db.runTransaction((transaction) async {
        final accessSnapshot = await transaction.get(_access.doc(uid));
        final profile = await transaction.get(_users.doc(uid));
        if (accessSnapshot.exists || profile.exists) {
          final access = AccountAccess.parse(accessSnapshot.data());
          final existing = access.validateProfile(uid, profile.data());
          if (access.role == UserRole.member && access.status == UserStatus.pending &&
              access.boilerhouseIds.isEmpty && access.validAfter.millisecondsSinceEpoch == 0 &&
              existing.login == login && existing.phone == phone &&
              existing.firstName == firstName && existing.lastName == lastName) {
            return;
          }
          throw const AuthFlowException(AuthFailure.invalidProfile);
        }
        final data = <String, dynamic>{'id':uid,'login':login,'firstName':firstName,'lastName':lastName,
          'phone':phone,'position':'','photoUrl':'','role':'member','status':'pending',
          'boilerhouseIds':<String>[],'sessionValidAfter':Timestamp.fromMillisecondsSinceEpoch(0),
          'createdAt':FieldValue.serverTimestamp()};
        transaction.set(_users.doc(uid),data);
        transaction.set(_directory.doc(uid),data);
        transaction.set(_access.doc(uid),_authority(data));
        transaction.set(_profiles.doc(uid),_profile(data));
        transaction.set(_db.collection('phoneClaims').doc(phone),{'uid':uid,'createdAt':FieldValue.serverTimestamp()});
      }));
    }, cleanup: signOut);
  }

  Future<void> signOut() {
    _validatedUid = null;
    _sessionGeneration++;
    DataQualityTracker.instance.clear();
    FirestoreSyncTracker.instance.reset();
    return _signOutOperation ??= _auth.signOut().whenComplete(() => _signOutOperation = null);
  }

  Future<void> _finishSessionSafely() async {
    try {
      await signOut();
    } catch (_) {
      // Protected data stays unavailable even if the native Auth cleanup fails.
      _validatedUid = null;
    }
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
  /// Authority is strict even when business records are displayed tolerantly.
  Future<AppUser?> fetchUser(String uid) async {
    if (currentUid != uid) throw const AuthFlowException(AuthFailure.reauthenticationRequired);
    final generation = _sessionGeneration;
    try {
      await _auth.currentUser!.getIdTokenResult(true);
      final result = await _validatedUser(uid, await _access.doc(uid).get(_server));
      if (generation != _sessionGeneration || currentUid != uid) {
        throw const AuthFlowException(AuthFailure.reauthenticationRequired);
      }
      _validatedUid = uid;
      return result;
    } catch (_) {
      _validatedUid = null;
      rethrow;
    }
  }

  Future<AppUser> _validatedUser(String uid, DocumentSnapshot<Map<String,dynamic>> snapshot) async {
    final auth = _auth.currentUser;
    if (auth?.uid != uid || snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
      throw const AuthFlowException(AuthFailure.network);
    }
    final access = AccountAccess.parse(snapshot.data());
    access.checkSession((await auth!.getIdTokenResult()).authTime);
    final profile = await _users.doc(uid).get(_server);
    return access.validateProfile(uid, profile.data());
  }

  Stream<AppUser?> currentUserStream(String uid) {
    final generation = _sessionGeneration;
    return _access.doc(uid).snapshots(includeMetadataChanges:true).asyncMap((doc) async {
      FirestoreSyncTracker.instance.reportSnapshot(source:'current-user-$uid',isFromCache:doc.metadata.isFromCache,hasPendingWrites:doc.metadata.hasPendingWrites);
      try {
        final user = doc.metadata.isFromCache || doc.metadata.hasPendingWrites
            ? await fetchUser(uid)
            : await _validatedUser(uid, doc);
        if (generation != _sessionGeneration || currentUid != uid) return null;
        return user;
      } catch (_) {
        _validatedUid = null;
        rethrow;
      }
    });
  }
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
    if (!SecurityPolicy.isActive(user) || user!.id != _validatedUid) return Stream.value([]);
    final query = SecurityPolicy.isManager(user) ? _directory.orderBy('createdAt') : _profiles.where('status',isEqualTo:'active');
    return _recordStream(query, _userFromDoc, source: 'directory');
  }

  Stream<List<T>> _recordStream<T>(Query<Map<String, dynamic>>? query,
      T Function(DocumentSnapshot<Map<String, dynamic>>) mapper, {required String source}) async* {
    if (query == null) { yield <T>[]; return; }
    final generation = _sessionGeneration;
    try {
      await for (final snapshot in query.snapshots()) {
        if (generation != _sessionGeneration || _validatedUid != currentUid) return;
        final values = <T>[];
        var invalid = 0;
        for (final document in snapshot.docs) {
          try {
            final fields = DocumentFields(document.data());
            if (fields.boolean('archived')) continue;
            values.add(mapper(document));
          } on FormatException {
            invalid++;
          }
        }
        DataQualityTracker.instance.record(source, invalid);
        yield values;
      }
    } finally {
      DataQualityTracker.instance.record(source, 0);
    }
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
    if (ids.length > 30 || ids.toSet().length != ids.length ||
        ids.any((id) => !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id))) {
      throw ArgumentError('Ko‘pi bilan 30 ta takrorlanmas qozonxona');
    }
    await _requireUser(admin:true);
    if (ids.isNotEmpty) {
      final snapshot = await _boilerhouses.where(FieldPath.documentId, whereIn: ids).get(_server);
      if (snapshot.docs.length != ids.length || snapshot.docs.any((d) => d.data()['archived'] == true)) {
        throw ArgumentError('Qozonxona topilmadi yoki arxivlangan');
      }
    }
    await _editUser(uid,{'boilerhouseIds':ids});
  }
  Future<void> updateUserPosition(String uid,String position) => _editUser(uid,{'position':position.trim()},selfPosition:uid == currentUid);
  Future<void> updateUserPhoto(String uid,String photoUrl) async => throw UnsupportedError('Fayl yuklash o‘chirilgan');
  Query<Map<String,dynamic>>? _scope(CollectionReference<Map<String,dynamic>> col,AppUser? user,{bool documentIds=false}) {
    if (!SecurityPolicy.isActive(user) || user!.id != currentUid || user.id != _validatedUid) return null;
    if (SecurityPolicy.isManager(user)) return col;
    final ids = user.boilerhouseIds.toSet().toList();
    if (ids.isEmpty || ids.length > 30) return null;
    return col.where(documentIds ? FieldPath.documentId : 'boilerHouseId',whereIn:ids);
  }
  Stream<List<T>> _scopedStream<T>(CollectionReference<Map<String,dynamic>> col,AppUser? user,
      T Function(DocumentSnapshot<Map<String,dynamic>>) mapper,{bool documentIds=false}) {
    final q = _scope(col,user,documentIds:documentIds);
    return _recordStream(q, mapper, source: col.path);
  }
  Stream<List<BoilerHouse>> boilerhousesStream({AppUser? user}) => _scopedStream(_boilerhouses,user,_boilerhouseFromDoc,documentIds:true);
  Stream<List<Equipment>> equipmentStream({AppUser? user}) => _scopedStream(_equipment,user,_equipmentFromDoc);
  Stream<List<Drawing>> drawingsStream({AppUser? user}) => _scopedStream(_drawings,user,_drawingFromDoc);
  Stream<List<Instruction>> instructionsStream({AppUser? user}) => !SecurityPolicy.isActive(user)
    ? Stream.value([]) : _recordStream(_instructions, _instructionFromDoc, source: 'instructions');
  Stream<List<JournalEntry>> journalStream({AppUser? user}) {
    final q = _scope(_journal,user);
    return _recordStream(q?.where('deleted',isEqualTo:false).orderBy('eventDateTime',descending:true).limit(100), _entryFromDoc, source: 'journal');
  }
  Future<void> addJournalEntry(JournalEntry e) async {
    final u = await _requireUser();
    if (e.photoPaths.isNotEmpty) throw UnsupportedError('Fayl yuklash o‘chirilgan');
    await _create(_journal.doc(e.id), {..._entryToMap(e),'authorId':u.id,'authorName':u.fullName,
      'createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp(),'version':1,'historyId':'','deleted':false});
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
    return _recordStream(_notifications.where('recipientId',isEqualTo:userId).orderBy('sentAt',descending:true).limit(100), _notifFromDoc, source: 'notifications');
  }
  Future<void> markNotificationRead(String id) => _trackWrite(_notifications.doc(id).update({'isRead':true}));
  Future<void> markAllNotificationsRead(String userId) async {
    if (userId != currentUid || userId != _validatedUid) throw StateError('Ruxsat yo‘q');
    // Snapshot a finite set: new arrivals do not extend this operation forever.
    final snapshot = await _notifications.where('recipientId',isEqualTo:userId)
        .where('isRead',isEqualTo:false).limit(1001).get(_server).timeout(const Duration(seconds: 20));
    final rows = snapshot.docs.take(1000).toList();
    final tasks = <Future<void> Function()>[];
    for (var start = 0; start < rows.length; start += 100) {
      final chunk = rows.skip(start).take(100).toList();
      tasks.add(() {
        if (currentUid != userId || _validatedUid != userId) throw StateError('Session changed');
        final batch = _db.batch();
        for (final row in chunk) { batch.update(row.reference, {'isRead': true}); }
        return _trackWrite(batch.commit());
      });
    }
    final result = await runBoundedBatches(tasks, concurrency: 2);
    if (!result.complete || snapshot.docs.length > 1000) {
      throw PartialOperationException(BatchResult(completed: result.completed,
          failed: result.failed + (snapshot.docs.length > 1000 ? 1 : 0), uncertain: result.uncertain));
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
    final user = await _requireUser(manager:true);
    if (recipientIds.isEmpty || recipientIds.length > 100 || recipientIds.toSet().length != recipientIds.length) {
      throw ArgumentError('1–100 ta takrorlanmas oluvchi talab qilinadi');
    }
    if (title.trim().isEmpty || title.length > 200 || message.trim().isEmpty || message.length > 4000) {
      throw ArgumentError('Xabar matni noto‘g‘ri');
    }
    final targets = {for (final uid in recipientIds) uid: _notifications.doc()};
    final tasks = <Future<void> Function()>[];
    // Eight recipients keep each commit within the Rules document-read budget.
    for (var i = 0; i < recipientIds.length; i += 8) {
      final chunk = recipientIds.skip(i).take(8).toList();
      tasks.add(() {
        if (currentUid != user.id || _validatedUid != user.id) throw StateError('Session changed');
        final batch = _db.batch();
        for (final uid in chunk) {
          batch.set(targets[uid]!, {'recipientId':uid,'senderId':user.id,'type':'important',
            'title':title,'message':message,'isRead':false,
            'createdAt':FieldValue.serverTimestamp(),'sentAt':FieldValue.serverTimestamp()});
        }
        return _trackWrite(batch.commit());
      });
    }
    final result = await runBoundedBatches(tasks);
    if (!result.complete) throw PartialOperationException(result);
  }
  Future<void> _create(DocumentReference<Map<String, dynamic>> reference, Map<String, dynamic> data) async {
    await _requireUser();
    await _trackWrite(_db.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) {
        throw StateError('Yozuv allaqachon mavjud. Ro‘yxatni yangilang; mavjud yozuv qayta yozilmadi.');
      }
      transaction.set(reference, data);
    }));
  }

  Future<void> _archive(DocumentReference<Map<String, dynamic>> reference) async {
    final user = await _requireUser(admin: true);
    await _trackWrite(_db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw StateError('Yozuv topilmadi');
      final before = snapshot.data()!;
      if (before['archived'] == true) return;
      transaction.update(reference, {
        'archived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'archivedBy': user.id,
      });
      transaction.set(reference.collection('history').doc('archive'), {
        'collection': reference.parent.id,
        'documentId': reference.id,
        'actorId': user.id,
        'createdAt': FieldValue.serverTimestamp(),
        'before': before,
      });
    }));
  }

  Future<void> addBoilerhouse(BoilerHouse b) => _create(_boilerhouses.doc(b.id), _boilerhouseToMap(b));
  Future<void> updateBoilerhouse(BoilerHouse b) => _trackWrite(_boilerhouses.doc(b.id).update(_boilerhouseToMap(b)));
  Future<void> deleteBoilerhouse(String id) => _archive(_boilerhouses.doc(id));
  Future<void> addEquipment(Equipment e) => _create(_equipment.doc(e.id), _equipmentToMap(e));
  Future<void> updateEquipment(Equipment e) => _trackWrite(_equipment.doc(e.id).update(_equipmentToMap(e)));
  Future<void> deleteEquipment(String id) => _archive(_equipment.doc(id));
  Future<void> addInstruction(Instruction i) async {
    final u = await _requireUser(manager:true);
    await _create(_instructions.doc(i.id), {..._instructionToMap(i),'authorId':u.id,
      'createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
  }
  Future<void> updateInstruction(Instruction i) => _trackWrite(_instructions.doc(i.id).update({..._instructionToMap(i),'updatedAt':FieldValue.serverTimestamp()}));
  Future<void> deleteInstruction(String id) => _archive(_instructions.doc(id));
  void _validateDrawing(Drawing d) {
    if (d.filePath.isNotEmpty) throw ArgumentError('Maxfiy fayllar uchun operator migratsiyasi kerak');
  }
  Future<void> addDrawing(Drawing d) async {
    _validateDrawing(d); final u = await _requireUser(manager:true);
    await _create(_drawings.doc(d.id), {..._drawingToMap(d),'authorId':u.id,'addedAt':FieldValue.serverTimestamp()});
  }
  Future<void> updateDrawing(Drawing d) async { _validateDrawing(d); await _trackWrite(_drawings.doc(d.id).update(_drawingToMap(d))); }
  Future<void> deleteDrawing(String id) => _archive(_drawings.doc(id));
  Stream<List<ChangeLogEntry>> changeLogsStream(String boilerHouseId) => _recordStream(_changeLogs.where('boilerHouseId',isEqualTo:boilerHouseId)
    .orderBy('createdAt',descending:true).limit(50), _changeLogFromDoc, source: 'changeLogs-$boilerHouseId');
  Future<void> addChangeLog(ChangeLogEntry e) async {
    final u = await _requireUser();
    if (e.photoUrls.isNotEmpty) throw UnsupportedError('Fayl yuklash o‘chirilgan');
    await _create(_changeLogs.doc(e.id), {..._changeLogToMap(e),'authorId':u.id,'authorName':u.fullName,'createdAt':FieldValue.serverTimestamp()});
  }
  Stream<List<ChangeLogReaction>> reactionsStream(String id) => _recordStream(_changeLogs.doc(id).collection('reactions').orderBy('createdAt').limit(200), _reactionFromDoc, source: 'reactions-$id');
  Future<void> addReaction(ChangeLogReaction r) async {
    final u = await _requireUser();
    await _create(_changeLogs.doc(r.changeLogId).collection('reactions').doc(r.id), {
      ..._reactionToMap(r),'authorId':u.id,'authorName':u.fullName,'createdAt':FieldValue.serverTimestamp()});
  }
  Stream<List<Shift>> shiftsStream({required DateTime from,required DateTime to,AppUser? user}) {
    final q = _scope(_shifts,user);
    return _recordStream(q?.where('date',isGreaterThanOrEqualTo:Timestamp.fromDate(from))
      .where('date',isLessThan:Timestamp.fromDate(to)).orderBy('date'), _shiftFromDoc, source: 'shifts');
  }
  Future<void> addShift(Shift s) async {
    final u = await _requireUser(manager:true);
    await _create(_shifts.doc(s.id), {..._shiftToMap(s),'createdBy':u.id,'createdAt':FieldValue.serverTimestamp()});
  }
  Future<void> updateShift(Shift s) => _trackWrite(_shifts.doc(s.id).update(_shiftToMap(s)));
  Future<void> deleteShift(String id) => _archive(_shifts.doc(id));
  AppUser _userFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = BusinessDocumentCodec.read('users', doc.id, doc.data());
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
    final d = BusinessDocumentCodec.read('journal', doc.id, doc.data());
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
    final d = BusinessDocumentCodec.read('notifications', doc.id, doc.data());
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
    final d = BusinessDocumentCodec.read('boilerhouses', doc.id, doc.data());
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
    final d = BusinessDocumentCodec.read('equipment', doc.id, doc.data());
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
    final d = BusinessDocumentCodec.read('instructions', doc.id, doc.data());
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
    final d = BusinessDocumentCodec.read('drawings', doc.id, doc.data());
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
    final d = BusinessDocumentCodec.read('changeLogs', doc.id, doc.data());
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
    final d = BusinessDocumentCodec.read('reactions', doc.id, doc.data());
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
    final d = BusinessDocumentCodec.read('shifts', doc.id, doc.data());
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


  Stream<List<AuditEntry>> auditLogStream() {
    return _recordStream(_auditLog.orderBy('createdAt', descending: true).limit(200), _auditFromDoc, source: 'audit');
  }

  AuditEntry _auditFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = BusinessDocumentCodec.read('audit_log', doc.id, doc.data());
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
