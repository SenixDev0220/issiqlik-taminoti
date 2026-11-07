import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/models/app_user.dart';

enum AuthFailure {
  invalidCredentials,
  pendingApproval,
  blocked,
  reauthenticationRequired,
  missingProfile,
  invalidProfile,
  permissionDenied,
  network,
  rateLimited,
  invalidInput,
  registrationUnavailable,
  internal,
}

class AuthFlowException implements Exception {
  const AuthFlowException(this.failure);
  final AuthFailure failure;
}

class SignInResult {
  const SignInResult.success(this.user) : failure = null;
  const SignInResult.failure(this.failure) : user = null;
  final AppUser? user;
  final AuthFailure? failure;
  bool get succeeded => user != null && failure == null;
}

class RegistrationResult {
  const RegistrationResult.success({this.cleanupFailed = false}) : failure = null;
  const RegistrationResult.failure(this.failure, {this.cleanupFailed = false});
  final AuthFailure? failure;
  final bool cleanupFailed;
  bool get succeeded => failure == null;
}

AuthFailure classifyAuthFailure(Object error, {bool registration = false}) {
  if (error is AuthFlowException) return error.failure;
  if (error is TimeoutException) return AuthFailure.network;
  if (error is FormatException || error is ArgumentError) return AuthFailure.invalidInput;
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'wrong-password' || 'invalid-credential' || 'user-not-found' || 'invalid-email' => AuthFailure.invalidCredentials,
      'user-disabled' => AuthFailure.blocked,
      'user-token-expired' || 'invalid-user-token' || 'requires-recent-login' => AuthFailure.reauthenticationRequired,
      'network-request-failed' || 'web-network-request-failed' => AuthFailure.network,
      'too-many-requests' || 'quota-exceeded' => AuthFailure.rateLimited,
      'weak-password' => AuthFailure.invalidInput,
      'email-already-in-use' => AuthFailure.registrationUnavailable,
      'operation-not-allowed' => AuthFailure.permissionDenied,
      _ => AuthFailure.internal,
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => registration ? AuthFailure.registrationUnavailable : AuthFailure.permissionDenied,
      'unavailable' || 'deadline-exceeded' || 'cancelled' => AuthFailure.network,
      'resource-exhausted' => AuthFailure.rateLimited,
      'unauthenticated' => AuthFailure.reauthenticationRequired,
      _ => AuthFailure.internal,
    };
  }
  return AuthFailure.internal;
}

/// Cleanup cannot replace a known successful registration with a false failure.
Future<RegistrationResult> completeRegistrationFlow({
  required Future<void> Function() operation,
  required Future<void> Function() cleanup,
}) async {
  AuthFailure? failure;
  try {
    await operation();
  } catch (error) {
    failure = classifyAuthFailure(error, registration: true);
  }
  var cleanupFailed = false;
  try {
    await cleanup();
  } catch (_) {
    cleanupFailed = true;
  }
  return failure == null
      ? RegistrationResult.success(cleanupFailed: cleanupFailed)
      : RegistrationResult.failure(failure, cleanupFailed: cleanupFailed);
}
