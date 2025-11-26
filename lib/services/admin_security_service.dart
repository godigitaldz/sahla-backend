import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSecurityService {
  static final AdminSecurityService _instance =
      AdminSecurityService._internal();
  factory AdminSecurityService() => _instance;
  AdminSecurityService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, DateTime> _adminSessions = {};
  final Map<String, int> _actionCounts = {};

  /// Admin role levels
  static const String superAdminRole = 'super_admin';
  static const String adminRole = 'admin';
  static const String moderatorRole = 'moderator';

  /// Action types for rate limiting
  static const String approveAction = 'approve';
  static const String rejectAction = 'reject';
  static const String bulkAction = 'bulk_operation';
  static const String exportAction = 'export';

  /// Rate limits (actions per hour)
  static const Map<String, int> rateLimits = {
    approveAction: 100,
    rejectAction: 100,
    bulkAction: 20,
    exportAction: 10,
  };

  /// Verify admin access for current user
  Future<bool> verifyAdminAccess(String userId) async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .single();

      final role = response['role'] as String?;
      return role != null && _isAdminRole(role);
    } catch (e) {
      debugPrint('❌ Error verifying admin access: $e');
      return false;
    }
  }

  /// Check if user has specific admin role
  Future<bool> hasAdminRole(String userId,
      {String requiredRole = adminRole}) async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .single();

      final role = response['role'] as String?;
      if (role == null) return false;

      return _hasRequiredRole(role, requiredRole);
    } catch (e) {
      debugPrint('❌ Error checking admin role: $e');
      return false;
    }
  }

  /// Check if role is admin role
  bool _isAdminRole(String role) {
    return role == superAdminRole || role == adminRole || role == moderatorRole;
  }

  /// Check if user has required role level
  bool _hasRequiredRole(String userRole, String requiredRole) {
    final roleHierarchy = {
      superAdminRole: 3,
      adminRole: 2,
      moderatorRole: 1,
    };

    final userLevel = roleHierarchy[userRole] ?? 0;
    final requiredLevel = roleHierarchy[requiredRole] ?? 0;

    return userLevel >= requiredLevel;
  }

  /// Log admin action for audit trail
  Future<void> logAdminAction({
    required String adminId,
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? details,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      await _supabase.from('admin_audit_log').insert({
        'admin_id': adminId,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'details': details ?? {},
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('📝 Admin action logged: $action on $targetType:$targetId');
    } catch (e) {
      debugPrint('❌ Error logging admin action: $e');
    }
  }

  /// Check rate limit for admin action
  bool checkRateLimit(String adminId, String action) {
    final now = DateTime.now();
    final key = '${adminId}_$action';

    // Clean old entries
    _actionCounts.removeWhere((k, count) {
      if (k.startsWith('${adminId}_')) {
        final lastAction = _adminSessions[k];
        if (lastAction != null && now.difference(lastAction).inHours >= 1) {
          return true;
        }
      }
      return false;
    });

    // Check current count
    final currentCount = _actionCounts[key] ?? 0;
    final limit = rateLimits[action] ?? 50;

    if (currentCount >= limit) {
      debugPrint('⚠️ Rate limit exceeded for $action: $currentCount/$limit');
      return false;
    }

    // Update count
    _actionCounts[key] = currentCount + 1;
    _adminSessions[key] = now;

    return true;
  }

  /// Get admin session info
  Map<String, dynamic> getAdminSessionInfo(String adminId) {
    final now = DateTime.now();
    final sessions = _adminSessions.entries
        .where((entry) => entry.key.startsWith('${adminId}_'))
        .map((entry) => {
              'action': entry.key.split('_').last,
              'last_action': entry.value,
              'time_since': now.difference(entry.value),
            })
        .toList();

    return {
      'admin_id': adminId,
      'active_sessions': sessions.length,
      'sessions': sessions,
    };
  }

  /// Validate admin session
  Future<bool> validateAdminSession(String adminId) async {
    try {
      // Check if user still has admin role
      final hasAccess = await verifyAdminAccess(adminId);
      if (!hasAccess) {
        await _invalidateAdminSession(adminId);
        return false;
      }

      // Check session timeout (8 hours)
      final sessionKey = '${adminId}_session';
      final lastActivity = _adminSessions[sessionKey];
      if (lastActivity != null &&
          DateTime.now().difference(lastActivity).inHours >= 8) {
        await _invalidateAdminSession(adminId);
        return false;
      }

      // Update last activity
      _adminSessions[sessionKey] = DateTime.now();

      return true;
    } catch (e) {
      debugPrint('❌ Error validating admin session: $e');
      return false;
    }
  }

  /// Invalidate admin session
  Future<void> _invalidateAdminSession(String adminId) async {
    _adminSessions.removeWhere((key, value) => key.startsWith('${adminId}_'));
    _actionCounts.removeWhere((key, value) => key.startsWith('${adminId}_'));

    debugPrint('🔒 Admin session invalidated for: $adminId');
  }

  /// Get admin permissions
  Future<List<String>> getAdminPermissions(String adminId) async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', adminId)
          .single();

      final role = response['role'] as String?;
      if (role == null) return [];

      return _getPermissionsForRole(role);
    } catch (e) {
      debugPrint('❌ Error getting admin permissions: $e');
      return [];
    }
  }

  /// Get permissions for specific role
  List<String> _getPermissionsForRole(String role) {
    switch (role) {
      case superAdminRole:
        return [
          'approve_requests',
          'reject_requests',
          'bulk_operations',
          'export_data',
          'view_analytics',
          'manage_users',
          'system_settings',
          'audit_logs',
        ];
      case adminRole:
        return [
          'approve_requests',
          'reject_requests',
          'bulk_operations',
          'export_data',
          'view_analytics',
          'audit_logs',
        ];
      case moderatorRole:
        return [
          'approve_requests',
          'reject_requests',
          'view_analytics',
        ];
      default:
        return [];
    }
  }

  /// Check if admin has specific permission
  Future<bool> hasPermission(String adminId, String permission) async {
    final permissions = await getAdminPermissions(adminId);
    return permissions.contains(permission);
  }

  /// Get admin activity summary
  Future<Map<String, dynamic>> getAdminActivitySummary(String adminId,
      {Duration? period}) async {
    try {
      final endDate = DateTime.now();
      final startDate = period != null
          ? endDate.subtract(period)
          : endDate.subtract(const Duration(days: 30));

      final response = await _supabase
          .from('admin_audit_log')
          .select('action, target_type, timestamp')
          .eq('admin_id', adminId)
          .gte('timestamp', startDate.toIso8601String())
          .lte('timestamp', endDate.toIso8601String());

      final activities = response as List<dynamic>;

      // Count actions by type
      final actionCounts = <String, int>{};
      final targetTypeCounts = <String, int>{};

      for (final activity in activities) {
        final action = activity['action'] as String;
        final targetType = activity['target_type'] as String;

        actionCounts[action] = (actionCounts[action] ?? 0) + 1;
        targetTypeCounts[targetType] = (targetTypeCounts[targetType] ?? 0) + 1;
      }

      return {
        'admin_id': adminId,
        'period': period?.inDays ?? 30,
        'total_actions': activities.length,
        'action_counts': actionCounts,
        'target_type_counts': targetTypeCounts,
        'most_active_day': _getMostActiveDay(activities),
        'average_actions_per_day': activities.length / (period?.inDays ?? 30),
      };
    } catch (e) {
      debugPrint('❌ Error getting admin activity summary: $e');
      return {};
    }
  }

  /// Get most active day from activities
  String _getMostActiveDay(List<dynamic> activities) {
    final dayCounts = <String, int>{};

    for (final activity in activities) {
      final timestamp = DateTime.parse(activity['timestamp']);
      final day = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;
    }

    if (dayCounts.isEmpty) return 'No activity';

    return dayCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Clean up old audit logs (older than 1 year)
  Future<void> cleanupOldAuditLogs() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 365));

      await _supabase
          .from('admin_audit_log')
          .delete()
          .lt('timestamp', cutoffDate.toIso8601String());

      debugPrint('🧹 Old audit logs cleaned up');
    } catch (e) {
      debugPrint('❌ Error cleaning up audit logs: $e');
    }
  }

  /// Get security alerts
  Future<List<Map<String, dynamic>>> getSecurityAlerts() async {
    try {
      final alerts = <Map<String, dynamic>>[];

      // Check for suspicious activity (high action count)
      for (final entry in _actionCounts.entries) {
        final adminId = entry.key.split('_').first;
        final action = entry.key.split('_').last;
        final count = entry.value;
        final limit = rateLimits[action] ?? 50;

        if (count > limit * 0.8) {
          alerts.add({
            'type': 'high_activity',
            'admin_id': adminId,
            'action': action,
            'count': count,
            'limit': limit,
            'severity': 'warning',
          });
        }
      }

      // Check for inactive admins
      final now = DateTime.now();
      for (final entry in _adminSessions.entries) {
        if (entry.key.endsWith('_session')) {
          final adminId = entry.key.split('_').first;
          final lastActivity = entry.value;

          if (now.difference(lastActivity).inHours > 24) {
            alerts.add({
              'type': 'inactive_admin',
              'admin_id': adminId,
              'last_activity': lastActivity,
              'hours_inactive': now.difference(lastActivity).inHours,
              'severity': 'info',
            });
          }
        }
      }

      return alerts;
    } catch (e) {
      debugPrint('❌ Error getting security alerts: $e');
      return [];
    }
  }

  /// Dispose resources
  void dispose() {
    _adminSessions.clear();
    _actionCounts.clear();
    debugPrint('🗑️ AdminSecurityService disposed');
  }
}
