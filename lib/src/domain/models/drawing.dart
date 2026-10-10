class Drawing {
  final String id;
  final String title;
  final String number;
  final String category;
  final String description;
  final String boilerHouseId;
  final String? equipmentId;
  final String filePath;
  final String authorId;
  final DateTime addedAt;

  Drawing({
    required this.id,
    required this.title,
    required this.number,
    required this.category,
    required this.description,
    required this.boilerHouseId,
    this.equipmentId,
    required this.filePath,
    required this.authorId,
    required this.addedAt,
  });
}
