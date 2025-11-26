enum NotificationType {
  order,
  message,
  payment,
  reminder,
  promotion,
  system,
  delivery,
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

class PushNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationPriority priority;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;
  final String? actionUrl;
  final List<NotificationAction> actions;

  const PushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.priority = NotificationPriority.normal,
    this.data,
    this.isRead = false,
    this.imageUrl,
    this.actionUrl,
    this.actions = const [],
  });

  PushNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    NotificationPriority? priority,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
    String? imageUrl,
    String? actionUrl,
    List<NotificationAction>? actions,
  }) {
    return PushNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
      actionUrl: actionUrl ?? this.actionUrl,
      actions: actions ?? this.actions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'priority': priority.name,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
      'actions': actions.map((a) => a.toMap()).toList(),
    };
  }

  factory PushNotification.fromMap(Map<String, dynamic> map) {
    return PushNotification(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.system,
      ),
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      data: map['data'],
      timestamp: DateTime.parse(map['timestamp']),
      isRead: map['isRead'] ?? false,
      imageUrl: map['imageUrl'],
      actionUrl: map['actionUrl'],
      actions: (map['actions'] as List<dynamic>?)
              ?.map((a) => NotificationAction.fromMap(a))
              .toList() ??
          [],
    );
  }
}

class NotificationAction {
  final String id;
  final String title;
  final String? actionUrl;
  final Map<String, dynamic>? data;
  final bool destructive;

  const NotificationAction({
    required this.id,
    required this.title,
    this.actionUrl,
    this.data,
    this.destructive = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'actionUrl': actionUrl,
      'data': data,
      'destructive': destructive,
    };
  }

  factory NotificationAction.fromMap(Map<String, dynamic> map) {
    return NotificationAction(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      actionUrl: map['actionUrl'],
      data: map['data'],
      destructive: map['destructive'] ?? false,
    );
  }
}

class NotificationSettings {
  final bool enabled;
  final bool orderNotifications;
  final bool messageNotifications;
  final bool paymentNotifications;
  final bool reminderNotifications;
  final bool promotionNotifications;
  final bool systemNotifications;
  final bool deliveryNotifications;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String? soundPath;
  final String? quietHoursStart; // Changed from TimeOfDay to String
  final String? quietHoursEnd; // Changed from TimeOfDay to String

  const NotificationSettings({
    this.enabled = true,
    this.orderNotifications = true,
    this.messageNotifications = true,
    this.paymentNotifications = true,
    this.reminderNotifications = true,
    this.promotionNotifications = true,
    this.systemNotifications = true,
    this.deliveryNotifications = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.soundPath,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  NotificationSettings copyWith({
    bool? enabled,
    bool? orderNotifications,
    bool? messageNotifications,
    bool? paymentNotifications,
    bool? reminderNotifications,
    bool? promotionNotifications,
    bool? systemNotifications,
    bool? deliveryNotifications,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? soundPath,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      orderNotifications: orderNotifications ?? this.orderNotifications,
      messageNotifications: messageNotifications ?? this.messageNotifications,
      paymentNotifications: paymentNotifications ?? this.paymentNotifications,
      reminderNotifications:
          reminderNotifications ?? this.reminderNotifications,
      promotionNotifications:
          promotionNotifications ?? this.promotionNotifications,
      systemNotifications: systemNotifications ?? this.systemNotifications,
      deliveryNotifications:
          deliveryNotifications ?? this.deliveryNotifications,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      soundPath: soundPath ?? this.soundPath,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'orderNotifications': orderNotifications,
      'messageNotifications': messageNotifications,
      'paymentNotifications': paymentNotifications,
      'reminderNotifications': reminderNotifications,
      'promotionNotifications': promotionNotifications,
      'systemNotifications': systemNotifications,
      'deliveryNotifications': deliveryNotifications,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'soundPath': soundPath,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      enabled: map['enabled'] ?? true,
      orderNotifications: map['orderNotifications'] ?? true,
      messageNotifications: map['messageNotifications'] ?? true,
      paymentNotifications: map['paymentNotifications'] ?? true,
      reminderNotifications: map['reminderNotifications'] ?? true,
      promotionNotifications: map['promotionNotifications'] ?? true,
      systemNotifications: map['systemNotifications'] ?? true,
      deliveryNotifications: map['deliveryNotifications'] ?? true,
      soundEnabled: map['soundEnabled'] ?? true,
      vibrationEnabled: map['vibrationEnabled'] ?? true,
      soundPath: map['soundPath'],
      quietHoursStart: map['quietHoursStart'],
      quietHoursEnd: map['quietHoursEnd'],
    );
  }

  bool isNotificationTypeEnabled(NotificationType type) {
    if (!enabled) return false;

    switch (type) {
      case NotificationType.order:
        return orderNotifications;
      case NotificationType.message:
        return messageNotifications;
      case NotificationType.payment:
        return paymentNotifications;
      case NotificationType.reminder:
        return reminderNotifications;
      case NotificationType.promotion:
        return promotionNotifications;
      case NotificationType.system:
        return systemNotifications;
      case NotificationType.delivery:
        return deliveryNotifications;
    }
  }
}

// Notification channel configuration
class NotificationChannel {
  final String id;
  final String name;
  final String description;
  final NotificationPriority importance;
  final bool enableLights;
  final bool enableVibration;
  final int? lightColor; // Changed from Color to int
  final List<int>? vibrationPattern;
  final String? soundPath;

  const NotificationChannel({
    required this.id,
    required this.name,
    required this.description,
    this.importance = NotificationPriority.normal,
    this.enableLights = true,
    this.enableVibration = true,
    this.lightColor,
    this.vibrationPattern,
    this.soundPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'importance': importance.name,
      'enableLights': enableLights,
      'enableVibration': enableVibration,
      'lightColor': lightColor,
      'vibrationPattern': vibrationPattern,
      'soundPath': soundPath,
    };
  }

  factory NotificationChannel.fromMap(Map<String, dynamic> map) {
    return NotificationChannel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      importance: NotificationPriority.values.firstWhere(
        (e) => e.name == map['importance'],
        orElse: () => NotificationPriority.normal,
      ),
      enableLights: map['enableLights'] ?? true,
      enableVibration: map['enableVibration'] ?? true,
      lightColor: map['lightColor'],
      vibrationPattern: map['vibrationPattern'] != null
          ? List<int>.from(map['vibrationPattern'])
          : null,
      soundPath: map['soundPath'],
    );
  }
}
