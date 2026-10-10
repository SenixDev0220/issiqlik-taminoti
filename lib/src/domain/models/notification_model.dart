enum AppNotificationType { emergency, important, informational, system }

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String message;
  final List<String> recipientIds; // empty = broadcast to all
  final String? relatedObjectId;
  final String? relatedObjectType;
  final bool isRead;
  final DateTime createdAt;
  final DateTime sentAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.recipientIds = const [],
    this.relatedObjectId,
    this.relatedObjectType,
    this.isRead = false,
    required this.createdAt,
    required this.sentAt,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        message: message,
        recipientIds: recipientIds,
        relatedObjectId: relatedObjectId,
        relatedObjectType: relatedObjectType,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        sentAt: sentAt,
      );
}
