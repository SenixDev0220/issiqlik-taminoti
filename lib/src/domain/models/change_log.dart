class ChangeLogEntry {
  final String id;
  final String boilerHouseId;
  final String title;
  final String text;
  final List<String> photoUrls;
  final String authorId;
  final String authorName;
  final DateTime createdAt;

  const ChangeLogEntry({
    required this.id,
    required this.boilerHouseId,
    required this.title,
    required this.text,
    this.photoUrls = const [],
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });
}

class ChangeLogReaction {
  final String id;
  final String changeLogId;
  final String text;
  final String authorId;
  final String authorName;
  final DateTime createdAt;

  const ChangeLogReaction({
    required this.id,
    required this.changeLogId,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });
}
