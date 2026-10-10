import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/equipment.dart';
import '../../services/firebase_service.dart';

final equipmentStreamProvider = StreamProvider<List<Equipment>>((ref) {
  return FirebaseService.instance.equipmentStream();
});

final equipmentListProvider = Provider.family<List<Equipment>, String>((ref, boilerHouseId) {
  final all = ref.watch(equipmentStreamProvider).valueOrNull ?? [];
  return all.where((eq) => eq.boilerHouseId == boilerHouseId).toList();
});

final equipmentByIdProvider = Provider.family<Equipment?, String>((ref, id) {
  final all = ref.watch(equipmentStreamProvider).valueOrNull ?? [];
  for (final eq in all) {
    if (eq.id == id) return eq;
  }
  return null;
});
