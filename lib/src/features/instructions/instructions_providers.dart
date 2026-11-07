import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/instruction.dart';
import '../../services/firebase_service.dart';
import '../../core/app_state.dart';

final instructionsStreamProvider = StreamProvider<List<Instruction>>((ref) {
  return FirebaseService.instance.instructionsStream(user: ref.watch(currentUserProvider));
});

final instructionsProvider = Provider<List<Instruction>>((ref) {
  return ref.watch(instructionsStreamProvider).valueOrNull ?? [];
});

final instructionsByCategoryProvider = Provider.family<List<Instruction>, String>((ref, category) {
  return ref.watch(instructionsProvider).where((i) => i.category == category).toList();
});
