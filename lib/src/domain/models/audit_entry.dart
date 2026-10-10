enum AuditAction { add, edit, delete, ban, unban, approve, decline, changeRole }

class AuditEntry {
  final String id;
  final String userId;
  final String userName;
  final AuditAction action;
  final String targetType; // boilerhouse, user, instruction, drawing
  final String targetId;
  final String targetName;
  final DateTime createdAt;

  const AuditEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.createdAt,
  });
}
