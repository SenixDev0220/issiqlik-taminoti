import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/app_user.dart';
import 'auth_result.dart';
import 'document_codec.dart';

class AccountAccess {
  const AccountAccess(this.role, this.status, this.boilerhouseIds, this.validAfter);
  final UserRole role;
  final UserStatus status;
  final List<String> boilerhouseIds;
  final Timestamp validAfter;

  factory AccountAccess.parse(Map<String, dynamic>? data) {
    if (data == null) throw const AuthFlowException(AuthFailure.missingProfile);
    try {
      final f = DocumentFields(data);
      final role = f.choice('role', ['admin', 'coAdmin', 'member']);
      final status = f.choice('status', ['active', 'pending', 'blocked']);
      final houses = f.strings('boilerhouseIds', max: 30, required: true);
      if (houses.toSet().length != houses.length || houses.any((id) => !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id))) {
        throw const FormatException('Invalid assignments');
      }
      final cutoff = f.date('sessionValidAfter');
      if (cutoff.millisecondsSinceEpoch < 0) throw const FormatException('Invalid cutoff');
      return AccountAccess(
        UserRole.values.byName(role), UserStatus.values.byName(status), houses, cutoff,
      );
    } on FormatException {
      throw const AuthFlowException(AuthFailure.invalidProfile);
    }
  }

  void checkSession(DateTime? authTime) {
    if (status == UserStatus.blocked) throw const AuthFlowException(AuthFailure.blocked);
    if (authTime == null || authTime.isBefore(validAfter.toDate())) {
      throw const AuthFlowException(AuthFailure.reauthenticationRequired);
    }
    if (status == UserStatus.pending) throw const AuthFlowException(AuthFailure.pendingApproval);
  }

  AppUser validateProfile(String uid, Map<String, dynamic>? data) {
    if (data == null) throw const AuthFlowException(AuthFailure.missingProfile);
    try {
      final f = DocumentFields(data);
      final houses = f.strings('boilerhouseIds', max: 30, required: true);
      if (f.string('id', required: true) != uid || f.string('role') != role.name ||
          f.string('status') != status.name || f.date('sessionValidAfter') != validAfter ||
          houses.length != boilerhouseIds.length ||
          Iterable<int>.generate(houses.length).any((i) => houses[i] != boilerhouseIds[i])) {
        throw const FormatException('Inconsistent profile');
      }
      return AppUser(
        id: uid,
        login: f.string('login', required: true, max: 40),
        firstName: f.string('firstName', required: true, max: 80),
        lastName: f.string('lastName', required: true, max: 80),
        phone: f.string('phone', required: true, max: 16),
        position: f.string('position', max: 120),
        photoUrl: '',
        role: role,
        status: status,
        boilerhouseIds: houses,
      );
    } on FormatException {
      throw const AuthFlowException(AuthFailure.invalidProfile);
    }
  }
}
