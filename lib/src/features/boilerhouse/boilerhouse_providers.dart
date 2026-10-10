import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/boiler_house.dart';
import '../../services/firebase_service.dart';

final boilerhousesStreamProvider = StreamProvider<List<BoilerHouse>>((ref) {
  return FirebaseService.instance.boilerhousesStream();
});

final boilerHouseListProvider = Provider<List<BoilerHouse>>((ref) {
  return ref.watch(boilerhousesStreamProvider).valueOrNull ?? [];
});

final selectedBoilerHouseProvider = Provider.family<BoilerHouse?, String>((ref, id) {
  final houses = ref.watch(boilerHouseListProvider);
  for (final h in houses) {
    if (h.id == id) return h;
  }
  return null;
});
