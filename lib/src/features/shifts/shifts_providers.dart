import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/shift.dart';
import '../../services/firebase_service.dart';

/// Monday (date-only) of the week containing [d]. Use this to build the family
/// key for [weekShiftsProvider] so equal weeks share a single stream.
DateTime weekStartOf(DateTime d) {
  return DateTime(d.year, d.month, d.day - (d.weekday - 1));
}

/// Shifts for one week: [weekStart, weekStart + 7 days). Key must be a
/// Monday date-only [DateTime] (see [weekStartOf]).
final weekShiftsProvider = StreamProvider.family<List<Shift>, DateTime>((ref, weekStart) {
  return FirebaseService.instance.shiftsStream(
    from: weekStart,
    to: DateTime(weekStart.year, weekStart.month, weekStart.day + 7),
  );
});
