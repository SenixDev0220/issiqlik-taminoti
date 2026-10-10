enum JournalEntryImportance { normal, important, critical }

enum JournalEntryStatus { open, inProgress, closed }

class JournalEntry {
  final String id;
  final String boilerHouseId;
  final String? equipmentId;
  final DateTime eventDateTime;
  final String category;
  final String title;
  final String description;
  final JournalEntryImportance importance;
  final JournalEntryStatus status;
  final List<String> photoPaths;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalEntry({
    required this.id,
    required this.boilerHouseId,
    this.equipmentId,
    required this.eventDateTime,
    required this.category,
    required this.title,
    required this.description,
    required this.importance,
    required this.status,
    this.photoPaths = const [],
    required this.authorId,
    this.authorName = '',
    required this.createdAt,
    required this.updatedAt,
  });
}
