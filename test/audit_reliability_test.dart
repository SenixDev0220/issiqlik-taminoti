import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khorazm_issiklik_manbai_app/src/services/account_access.dart';
import 'package:khorazm_issiklik_manbai_app/src/services/auth_result.dart';
import 'package:khorazm_issiklik_manbai_app/src/services/bounded_operations.dart';
import 'package:khorazm_issiklik_manbai_app/src/services/document_codec.dart';
import 'package:khorazm_issiklik_manbai_app/src/core/data_quality.dart';

void main() {
  final epoch = Timestamp.fromMillisecondsSinceEpoch(0);
  test('auth failures distinguish credentials, transport, rights and revoked sessions', () {
    expect(classifyAuthFailure(FirebaseAuthException(code: 'wrong-password')), AuthFailure.invalidCredentials);
    expect(classifyAuthFailure(FirebaseAuthException(code: 'network-request-failed')), AuthFailure.network);
    expect(classifyAuthFailure(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')), AuthFailure.permissionDenied);
    expect(classifyAuthFailure(FirebaseAuthException(code: 'user-token-expired')), AuthFailure.reauthenticationRequired);
    expect(classifyAuthFailure(TimeoutException('synthetic')), AuthFailure.network);
  });
  test('successful registration remains successful when native cleanup fails', () async {
    var cleaned = false;
    final result = await completeRegistrationFlow(operation: () async {}, cleanup: () async {
      cleaned = true;
      throw StateError('synthetic cleanup');
    });
    expect(cleaned, isTrue);
    expect(result.succeeded, isTrue);
    expect(result.cleanupFailed, isTrue);
  });
  test('registration failure retains its cause even when cleanup also fails', () async {
    final result = await completeRegistrationFlow(
      operation: () async => throw const AuthFlowException(AuthFailure.permissionDenied),
      cleanup: () async => throw StateError('cleanup'),
    );
    expect(result.failure, AuthFailure.permissionDenied);
    expect(result.cleanupFailed, isTrue);
  });
  test('authority never defaults malformed roles, assignment lists or cutoff', () {
    final valid = {'role': 'member', 'status': 'active', 'boilerhouseIds': ['h1'], 'sessionValidAfter': epoch};
    for (final patch in [
      {'role': 'unknown'}, {'boilerhouseIds': 'h1'}, {'boilerhouseIds': [1]},
      {'boilerhouseIds': ['h1', 'h1']}, {'sessionValidAfter': 0},
    ]) {
      expect(() => AccountAccess.parse({...valid, ...patch}), throwsA(isA<AuthFlowException>()));
    }
    final access = AccountAccess.parse({...valid, 'sessionValidAfter': Timestamp.fromMillisecondsSinceEpoch(2000)});
    expect(() => access.checkSession(DateTime.fromMillisecondsSinceEpoch(1000)), throwsA(isA<AuthFlowException>()));
  });
  test('malformed legacy documents produce a recoverable format error, not TypeError', () {
    expect(() => BusinessDocumentCodec.read('notifications', 'n', {'recipientIds': [], 'createdAt': epoch}), throwsFormatException);
    expect(() => BusinessDocumentCodec.read('journal', 'j', {'boilerHouseId': 'h1', 'eventDateTime': 'yesterday'}), throwsFormatException);
    expect(() => BusinessDocumentCodec.read('users', 'u', {'role': 'member', 'status': 'active', 'boilerhouseIds': 'h1'}), throwsFormatException);
    final read = BusinessDocumentCodec.read('notifications', 'n', {
      'recipientId': 'u', 'title': 'Notice', 'message': '', 'createdAt': epoch,
    });
    expect(read['sentAt'], epoch);
    expect(read['isRead'], false);
  });
  test('bounded batches cap concurrent requests and report partial failures', () async {
    var concurrent = 0;
    var maximum = 0;
    final tasks = List<Future<void> Function()>.generate(10, (i) => () async {
      concurrent++;
      if (concurrent > maximum) maximum = concurrent;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      concurrent--;
      if (i == 4) throw StateError('synthetic');
    });
    final result = await runBoundedBatches(tasks, concurrency: 3);
    expect(maximum, lessThanOrEqualTo(3));
    expect(result.completed, 9);
    expect(result.failed, 1);
    expect(result.complete, isFalse);
  });
  test('timeout is marked uncertain instead of silently successful', () async {
    final pending = Completer<void>();
    final result = await runBoundedBatches([() => pending.future], timeout: const Duration(milliseconds: 1));
    expect(result.uncertain, 1);
    pending.complete();
  });
  test('data quality tracker retains only counts and clears restored collections', () async {
    final tracker = DataQualityTracker();
    tracker.record('journal', 2);
    tracker.record('notifications', 1);
    expect(tracker.count, 3);
    tracker.record('journal', 0);
    expect(tracker.count, 1);
    tracker.clear();
    expect(tracker.count, 0);
    await tracker.dispose();
  });
}
