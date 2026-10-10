enum ShiftType { day, night }

class Shift {
  final String id;
  final String boilerHouseId;
  final String boilerHouseName;
  final String operatorId;
  final String operatorName;

  /// Calendar day of the shift (time component is ignored).
  final DateTime date;
  final ShiftType type;
  final String note;
  final String createdBy;
  final DateTime createdAt;

  const Shift({
    required this.id,
    required this.boilerHouseId,
    required this.boilerHouseName,
    required this.operatorId,
    required this.operatorName,
    required this.date,
    required this.type,
    this.note = '',
    required this.createdBy,
    required this.createdAt,
  });
}
