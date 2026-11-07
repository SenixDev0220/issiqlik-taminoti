import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/drawing.dart';
import '../../services/firebase_service.dart';
import '../../core/app_state.dart';

final drawingsStreamProvider = StreamProvider<List<Drawing>>((ref) {
  return FirebaseService.instance.drawingsStream(user: ref.watch(currentUserProvider));
});

final drawingsProvider = Provider<List<Drawing>>((ref) {
  return ref.watch(drawingsStreamProvider).valueOrNull ?? [];
});

final drawingsByBoilerHouseProvider = Provider.family<List<Drawing>, String>((ref, boilerHouseId) {
  return ref.watch(drawingsProvider).where((d) => d.boilerHouseId == boilerHouseId).toList();
});
