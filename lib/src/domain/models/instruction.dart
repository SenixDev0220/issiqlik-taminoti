enum InstructionUrgency { normal, mandatory }

class Instruction {
  final String id;
  final String title;
  final String category;
  final String body;
  final String version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authorId;
  final List<String> boilerHouseIds;
  final List<String> equipmentTypes;
  final InstructionUrgency urgency;

  Instruction({
    required this.id,
    required this.title,
    required this.category,
    required this.body,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.authorId,
    this.boilerHouseIds = const [],
    this.equipmentTypes = const [],
    this.urgency = InstructionUrgency.normal,
  });
}
