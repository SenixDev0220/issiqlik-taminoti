import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../domain/models/journal_entry.dart';

final journalEntriesProvider = Provider<List<JournalEntry>>((ref) {
  return ref.watch(journalStoreProvider);
});

final journalEntriesByBoilerHouseProvider =
    Provider.family<List<JournalEntry>, String>((ref, boilerHouseId) {
  return ref.watch(journalStoreProvider).where((e) => e.boilerHouseId == boilerHouseId).toList();
});
