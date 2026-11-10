/// Categories of in-app and mobile notifications.
enum NotificationCategory {
  outOfStock,
  lowStock,
  auditReminder,
  backupReminder,
  capacityAlert,
  system,
}

/// Represents an in-app notification item.
class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    this.productId,
    this.actionLabel,
    this.actionRoute,
  });

  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime timestamp;
  final bool isRead;
  final int? productId;
  final String? actionLabel;
  final String? actionRoute;

  InAppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationCategory? category,
    DateTime? timestamp,
    bool? isRead,
    int? productId,
    String? actionLabel,
    String? actionRoute,
  }) {
    return InAppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      productId: productId ?? this.productId,
      actionLabel: actionLabel ?? this.actionLabel,
      actionRoute: actionRoute ?? this.actionRoute,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category.name,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'productId': productId,
        'actionLabel': actionLabel,
        'actionRoute': actionRoute,
      };

  factory InAppNotification.fromJson(Map<String, dynamic> map) {
    return InAppNotification(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      category: NotificationCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => NotificationCategory.system,
      ),
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRead: map['isRead'] as bool? ?? false,
      productId: map['productId'] as int?,
      actionLabel: map['actionLabel'] as String?,
      actionRoute: map['actionRoute'] as String?,
    );
  }
}
