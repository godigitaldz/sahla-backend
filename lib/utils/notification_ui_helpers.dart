import 'package:flutter/material.dart';
import '../models/push_notification.dart';

/// UI helper class for notification-related UI logic
/// Separates UI concerns from data models for better architecture
class NotificationUIHelpers {
  /// Get appropriate icon for notification type
  static IconData getIcon(NotificationType type) {
    debugPrint(
        '🔔 NotificationUIHelpers.getIcon() called for type: ${type.name}');
    switch (type) {
      case NotificationType.order:
        return Icons.restaurant;
      case NotificationType.message:
        return Icons.message;
      case NotificationType.payment:
        return Icons.payment;
      case NotificationType.reminder:
        return Icons.alarm;
      case NotificationType.promotion:
        return Icons.local_offer;
      case NotificationType.system:
        return Icons.info;
      case NotificationType.delivery:
        return Icons.delivery_dining;
    }
  }

  /// Get appropriate color for notification type
  static Color getColor(NotificationType type) {
    debugPrint(
        '🎨 NotificationUIHelpers.getColor() called for type: ${type.name}');
    switch (type) {
      case NotificationType.order:
        return const Color(0xFF593CFB);
      case NotificationType.message:
        return Colors.blue;
      case NotificationType.payment:
        return Colors.green;
      case NotificationType.reminder:
        return Colors.orange;
      case NotificationType.promotion:
        return Colors.red;
      case NotificationType.system:
        return Colors.grey;
      case NotificationType.delivery:
        return Colors.amber;
    }
  }

  /// Get human-readable priority text
  static String getPriorityText(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return 'Low';
      case NotificationPriority.normal:
        return 'Normal';
      case NotificationPriority.high:
        return 'High';
      case NotificationPriority.urgent:
        return 'Urgent';
    }
  }

  /// Format timestamp to relative time string
  static String getTimeString(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return '1 day ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Check if current time is within quiet hours
  static bool isInQuietHours(String? quietHoursStart, String? quietHoursEnd) {
    if (quietHoursStart == null || quietHoursEnd == null) return false;

    try {
      final now = TimeOfDay.now();
      final start = _parseTimeOfDay(quietHoursStart);
      final end = _parseTimeOfDay(quietHoursEnd);

      if (start == null || end == null) return false;

      // Handle overnight quiet hours (e.g., 22:00 to 08:00)
      if (start.hour > end.hour) {
        return (now.hour >= start.hour || now.hour < end.hour) ||
            (now.hour == start.hour && now.minute >= start.minute) ||
            (now.hour == end.hour && now.minute < end.minute);
      } else {
        // Same day quiet hours (e.g., 12:00 to 14:00)
        return (now.hour > start.hour && now.hour < end.hour) ||
            (now.hour == start.hour && now.minute >= start.minute) ||
            (now.hour == end.hour && now.minute < end.minute);
      }
    } catch (e) {
      return false;
    }
  }

  /// Parse time string to TimeOfDay
  static TimeOfDay? _parseTimeOfDay(String timeString) {
    try {
      final parts = timeString.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get default notification channels
  static List<NotificationChannel> getDefaultChannels() {
    debugPrint(
        '📱 NotificationUIHelpers.getDefaultChannels() called - creating 7 default channels');
    return [
      const NotificationChannel(
        id: 'orders',
        name: 'Order Notifications',
        description: 'Notifications about your food orders',
        importance: NotificationPriority.high,
        lightColor: 0xFF593CFB, // Converted to int
      ),
      const NotificationChannel(
        id: 'messages',
        name: 'Messages',
        description: 'New messages from restaurants and delivery personnel',
        importance: NotificationPriority.high,
      ),
      const NotificationChannel(
        id: 'payments',
        name: 'Payment Notifications',
        description: 'Payment confirmations and alerts',
        importance: NotificationPriority.high,
        lightColor: 0xFF4CAF50, // Green color as int
      ),
      const NotificationChannel(
        id: 'reminders',
        name: 'Reminders',
        description: 'Order reminders and important dates',
        importance: NotificationPriority.normal,
        lightColor: 0xFFFF9800, // Orange color as int
      ),
      const NotificationChannel(
        id: 'promotions',
        name: 'Promotions',
        description: 'Special offers and discounts',
        importance: NotificationPriority.low,
        lightColor: 0xFFF44336, // Red color as int
      ),
      const NotificationChannel(
        id: 'system',
        name: 'System Notifications',
        description: 'App updates and system messages',
        importance: NotificationPriority.low,
      ),
      const NotificationChannel(
        id: 'delivery',
        name: 'Delivery Notifications',
        description: 'Delivery updates and tracking',
        importance: NotificationPriority.normal,
        lightColor: 0xFFFFC107, // Amber color as int
      ),
    ];
  }
}
