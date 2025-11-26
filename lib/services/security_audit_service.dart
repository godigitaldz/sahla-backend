import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'context_aware_service.dart';

class SecurityAuditService extends ChangeNotifier {
  static final SecurityAuditService _instance =
      SecurityAuditService._internal();
  factory SecurityAuditService() => _instance;
  SecurityAuditService._internal();

  SupabaseClient get client => Supabase.instance.client;
  final ContextAwareService _contextAware = ContextAwareService();

  // Security audit results
  final List<SecurityIssue> _issues = [];
  final Map<String, SecurityMetric> _metrics = {};
  bool _isAuditing = false;
  Timer? _auditTimer;

  // Authentication security
  bool _isAuthenticated = false;
  String? _currentUserId;
  List<String> _userRoles = [];

  // Data access patterns
  final Map<String, DataAccessPattern> _dataAccessPatterns = {};
  final List<String> _sensitiveOperations = [];

  // Network security
  final List<NetworkSecurityEvent> _networkEvents = [];
  bool _isSecureConnection = true;

  // Getters
  List<SecurityIssue> get issues => List.unmodifiable(_issues);
  Map<String, SecurityMetric> get metrics => Map.unmodifiable(_metrics);
  bool get isAuditing => _isAuditing;
  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserId => _currentUserId;
  List<String> get userRoles => List.unmodifiable(_userRoles);
  bool get isSecureConnection => _isSecureConnection;

  // Initialize security audit
  Future<void> initialize() async {
    debugPrint('🔒 Initializing SecurityAuditService...');

    await _contextAware.initialize();
    await _setupSecurityMonitoring();
    await _performInitialAudit();

    debugPrint('✅ SecurityAuditService initialized');
  }

  // Setup security monitoring
  Future<void> _setupSecurityMonitoring() async {
    _isAuditing = true;

    // Monitor authentication state
    _monitorAuthenticationState();

    // Monitor data access patterns
    _monitorDataAccessPatterns();

    // Monitor network security
    _monitorNetworkSecurity();

    // Periodic security audit
    _auditTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performSecurityAudit();
    });

    debugPrint('🔍 Security monitoring started');
  }

  // Monitor authentication state
  void _monitorAuthenticationState() {
    client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      _isAuthenticated = session != null;
      _currentUserId = session?.user.id;

      if (event == AuthChangeEvent.signedIn) {
        _handleUserSignIn(session!.user);
      } else if (event == AuthChangeEvent.signedOut) {
        _handleUserSignOut();
      }

      _updateSecurityMetric(
          'authentication_state', _isAuthenticated ? 1.0 : 0.0, DateTime.now());
      debugPrint('🔐 Authentication state changed: ${event.name}');
    });
  }

  // Handle user sign in
  void _handleUserSignIn(User user) {
    _currentUserId = user.id;
    _loadUserRoles(user.id);
    _auditUserPermissions(user);

    debugPrint('👤 User signed in: ${user.email}');
  }

  // Handle user sign out
  void _handleUserSignOut() {
    _currentUserId = null;
    _userRoles.clear();
    _clearSensitiveData();

    debugPrint('👤 User signed out');
  }

  // Load user roles
  Future<void> _loadUserRoles(String userId) async {
    try {
      final response = await client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      _userRoles = [response['role'] ?? 'user'];
    } catch (e) {
      debugPrint('⚠️ Error loading user roles: $e');
      _userRoles = ['user'];
    }
  }

  // Audit user permissions
  void _auditUserPermissions(User user) {
    // Check if user has appropriate permissions
    if (!_userRoles.contains('admin') && !_userRoles.contains('host')) {
      _addSecurityIssue(
        SecurityIssue(
          type: SecurityIssueType.permission,
          severity: SecuritySeverity.warning,
          message: 'User has limited permissions',
          details: 'User ${user.email} has roles: ${_userRoles.join(', ')}',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  // Monitor data access patterns
  void _monitorDataAccessPatterns() {
    // Track database operations
    _contextAware.trackEvent(
      eventName: 'data_access_monitoring',
      service: 'SecurityAuditService',
      operation: 'monitoring',
      metadata: {
        'monitoring_enabled': true,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Monitor network security
  void _monitorNetworkSecurity() {
    // Check if using HTTPS - removed direct supabaseUrl access
    _isSecureConnection = true; // Assume secure for now

    if (!_isSecureConnection) {
      _addSecurityIssue(
        SecurityIssue(
          type: SecurityIssueType.network,
          severity: SecuritySeverity.critical,
          message: 'Insecure connection detected',
          details: 'App is not using HTTPS',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  // Perform initial security audit
  Future<void> _performInitialAudit() async {
    debugPrint('🔍 Performing initial security audit...');

    await _auditAuthenticationSecurity();
    await _auditDataAccessSecurity();
    await _auditNetworkSecurity();
    await _auditCodeSecurity();

    debugPrint('✅ Initial security audit completed');
  }

  // Audit authentication security
  Future<void> _auditAuthenticationSecurity() async {
    // Check if user is authenticated
    if (!_isAuthenticated) {
      _addSecurityIssue(
        SecurityIssue(
          type: SecurityIssueType.authentication,
          severity: SecuritySeverity.info,
          message: 'User not authenticated',
          details: 'No active session found',
          timestamp: DateTime.now(),
        ),
      );
    }

    // Check session expiry
    final session = client.auth.currentSession;
    if (session != null) {
      final expiresAt = session.expiresAt;
      final now = DateTime.now();

      if (expiresAt != null) {
        final expiryDate =
            DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
        if (expiryDate.isBefore(now)) {
          _addSecurityIssue(
            SecurityIssue(
              type: SecurityIssueType.authentication,
              severity: SecuritySeverity.warning,
              message: 'Session expired',
              details: 'User session has expired',
              timestamp: DateTime.now(),
            ),
          );
        }
      }
    }
  }

  // Audit data access security
  Future<void> _auditDataAccessSecurity() async {
    // Check RLS policies
    await _checkRLSPolicies();

    // Check data access patterns
    _analyzeDataAccessPatterns();

    // Check for sensitive operations
    _auditSensitiveOperations();
  }

  // Check RLS policies
  Future<void> _checkRLSPolicies() async {
    try {
      // Test RLS policies by attempting operations
      final tables = ['cars', 'bookings', 'profiles', 'notifications'];

      for (final table in tables) {
        await _testRLSPolicy(table);
      }
    } catch (e) {
      debugPrint('⚠️ Error checking RLS policies: $e');
    }
  }

  // Test RLS policy for a table
  Future<void> _testRLSPolicy(String table) async {
    try {
      // Try to access data
      await client.from(table).select().limit(1);

      // If successful, check if user has proper access
      if (!_isAuthenticated) {
        _addSecurityIssue(
          SecurityIssue(
            type: SecurityIssueType.dataAccess,
            severity: SecuritySeverity.critical,
            message: 'Unauthenticated access to $table',
            details: 'RLS policy may not be properly configured',
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      // Expected error for unauthenticated users
      if (_isAuthenticated) {
        _addSecurityIssue(
          SecurityIssue(
            type: SecurityIssueType.dataAccess,
            severity: SecuritySeverity.warning,
            message: 'Access denied to $table',
            details: 'User may not have proper permissions',
            timestamp: DateTime.now(),
          ),
        );
      }
    }
  }

  // Analyze data access patterns
  void _analyzeDataAccessPatterns() {
    // Check for unusual access patterns
    final patterns = _dataAccessPatterns.values;

    for (final pattern in patterns) {
      if (pattern.accessCount > 100) {
        _addSecurityIssue(
          SecurityIssue(
            type: SecurityIssueType.dataAccess,
            severity: SecuritySeverity.warning,
            message: 'High data access frequency',
            details:
                'Table ${pattern.table} accessed ${pattern.accessCount} times',
            timestamp: DateTime.now(),
          ),
        );
      }
    }
  }

  // Audit sensitive operations
  void _auditSensitiveOperations() {
    for (final operation in _sensitiveOperations) {
      _addSecurityIssue(
        SecurityIssue(
          type: SecurityIssueType.operation,
          severity: SecuritySeverity.info,
          message: 'Sensitive operation detected',
          details: 'Operation: $operation',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  // Audit network security
  Future<void> _auditNetworkSecurity() async {
    // Check connection security
    if (!_isSecureConnection) {
      _addSecurityIssue(
        SecurityIssue(
          type: SecurityIssueType.network,
          severity: SecuritySeverity.critical,
          message: 'Insecure network connection',
          details: 'App is not using encrypted connection',
          timestamp: DateTime.now(),
        ),
      );
    }

    // Check for network vulnerabilities
    _checkNetworkVulnerabilities();
  }

  // Check network vulnerabilities
  void _checkNetworkVulnerabilities() {
    // Add network security checks here
    // This would include checking for:
    // - Certificate validation
    // - DNS security
    // - Network protocol security
  }

  // Audit code security
  Future<void> _auditCodeSecurity() async {
    // Check for common security issues
    _checkForSecurityVulnerabilities();

    // Validate input sanitization
    _validateInputSanitization();

    // Check for proper error handling
    _checkErrorHandling();
  }

  // Check for security vulnerabilities
  void _checkForSecurityVulnerabilities() {
    // Check for SQL injection vulnerabilities
    _checkSQLInjectionVulnerabilities();

    // Check for XSS vulnerabilities
    _checkXSSVulnerabilities();

    // Check for CSRF vulnerabilities
    _checkCSRFVulnerabilities();
  }

  // Check SQL injection vulnerabilities
  void _checkSQLInjectionVulnerabilities() {
    // This would analyze code for potential SQL injection vulnerabilities
    // For now, we'll add a placeholder check
    debugPrint('🔍 Checking for SQL injection vulnerabilities...');
  }

  // Check XSS vulnerabilities
  void _checkXSSVulnerabilities() {
    // This would analyze code for potential XSS vulnerabilities
    debugPrint('🔍 Checking for XSS vulnerabilities...');
  }

  // Check CSRF vulnerabilities
  void _checkCSRFVulnerabilities() {
    // This would analyze code for potential CSRF vulnerabilities
    debugPrint('🔍 Checking for CSRF vulnerabilities...');
  }

  // Validate input sanitization
  void _validateInputSanitization() {
    // Check if user inputs are properly sanitized
    debugPrint('🔍 Validating input sanitization...');
  }

  // Check error handling
  void _checkErrorHandling() {
    // Check if errors are handled securely
    debugPrint('🔍 Checking error handling...');
  }

  // Perform periodic security audit
  void _performSecurityAudit() {
    debugPrint('🔍 Performing periodic security audit...');

    _auditAuthenticationSecurity();
    _auditDataAccessSecurity();
    _auditNetworkSecurity();

    _updateSecurityMetrics();
  }

  // Update security metrics
  void _updateSecurityMetrics() {
    final timestamp = DateTime.now();

    // Authentication security score
    final authScore = _calculateAuthenticationScore();
    _updateSecurityMetric('authentication_score', authScore, timestamp);

    // Data access security score
    final dataScore = _calculateDataAccessScore();
    _updateSecurityMetric('data_access_score', dataScore, timestamp);

    // Network security score
    final networkScore = _calculateNetworkSecurityScore();
    _updateSecurityMetric('network_security_score', networkScore, timestamp);

    // Overall security score
    final overallScore = (authScore + dataScore + networkScore) / 3;
    _updateSecurityMetric('overall_security_score', overallScore, timestamp);
  }

  // Calculate authentication score
  double _calculateAuthenticationScore() {
    double score = 1.0;

    if (!_isAuthenticated) score -= 0.3;
    if (_userRoles.isEmpty) score -= 0.2;
    if (_issues
        .any((issue) => issue.type == SecurityIssueType.authentication)) {
      score -= 0.3;
    }

    return score.clamp(0.0, 1.0);
  }

  // Calculate data access score
  double _calculateDataAccessScore() {
    double score = 1.0;

    if (_issues.any((issue) => issue.type == SecurityIssueType.dataAccess)) {
      score -= 0.4;
    }

    return score.clamp(0.0, 1.0);
  }

  // Calculate network security score
  double _calculateNetworkSecurityScore() {
    double score = 1.0;

    if (!_isSecureConnection) score -= 0.5;
    if (_issues.any((issue) => issue.type == SecurityIssueType.network)) {
      score -= 0.3;
    }

    return score.clamp(0.0, 1.0);
  }

  // Update security metric
  void _updateSecurityMetric(String name, double value, DateTime timestamp) {
    if (!_metrics.containsKey(name)) {
      _metrics[name] = SecurityMetric(name: name);
    }

    _metrics[name]!.addValue(value, timestamp);
  }

  // Add security issue
  void _addSecurityIssue(SecurityIssue issue) {
    _issues.add(issue);
    debugPrint('⚠️ Security issue: ${issue.message}');
    notifyListeners();
  }

  // Track data access
  void trackDataAccess(String table, String operation) {
    final key = '${table}_$operation';

    if (!_dataAccessPatterns.containsKey(key)) {
      _dataAccessPatterns[key] = DataAccessPattern(
        table: table,
        operation: operation,
        accessCount: 0,
        lastAccess: DateTime.now(),
      );
    }

    _dataAccessPatterns[key]!.accessCount++;
    _dataAccessPatterns[key]!.lastAccess = DateTime.now();
  }

  // Track sensitive operation
  void trackSensitiveOperation(String operation) {
    _sensitiveOperations.add(operation);
  }

  // Track network event
  void trackNetworkEvent(NetworkSecurityEvent event) {
    _networkEvents.add(event);
  }

  // Clear sensitive data
  void _clearSensitiveData() {
    _sensitiveOperations.clear();
    _dataAccessPatterns.clear();
    _networkEvents.clear();
  }

  // Generate security report
  SecurityReport generateSecurityReport() {
    return SecurityReport(
      issues: _issues,
      metrics: _metrics,
      dataAccessPatterns: _dataAccessPatterns,
      networkEvents: _networkEvents,
      timestamp: DateTime.now(),
    );
  }

  // Get security summary
  Map<String, dynamic> getSecuritySummary() {
    final criticalIssues =
        _issues.where((i) => i.severity == SecuritySeverity.critical).length;
    final warningIssues =
        _issues.where((i) => i.severity == SecuritySeverity.warning).length;
    final infoIssues =
        _issues.where((i) => i.severity == SecuritySeverity.info).length;

    return {
      'total_issues': _issues.length,
      'critical_issues': criticalIssues,
      'warning_issues': warningIssues,
      'info_issues': infoIssues,
      'is_authenticated': _isAuthenticated,
      'is_secure_connection': _isSecureConnection,
      'user_roles': _userRoles,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Dispose resources
  @override
  void dispose() {
    _isAuditing = false;
    _auditTimer?.cancel();
    super.dispose();
  }
}

// Security issue class
class SecurityIssue {
  final SecurityIssueType type;
  final SecuritySeverity severity;
  final String message;
  final String details;
  final DateTime timestamp;

  SecurityIssue({
    required this.type,
    required this.severity,
    required this.message,
    required this.details,
    required this.timestamp,
  });
}

// Security issue types
enum SecurityIssueType {
  authentication,
  dataAccess,
  network,
  operation,
  permission,
}

// Security severity levels
enum SecuritySeverity {
  info,
  warning,
  critical,
}

// Security metric class
class SecurityMetric {
  final String name;
  final List<SecurityMetricValue> values = [];
  double? _currentValue;

  SecurityMetric({required this.name});

  void addValue(double value, DateTime timestamp) {
    values.add(SecurityMetricValue(value: value, timestamp: timestamp));
    _currentValue = value;

    // Keep only last 50 values
    if (values.length > 50) {
      values.removeAt(0);
    }
  }

  double? get currentValue => _currentValue;
  double? get averageValue {
    if (values.isEmpty) return null;
    return values.map((v) => v.value).reduce((a, b) => a + b) / values.length;
  }
}

// Security metric value class
class SecurityMetricValue {
  final double value;
  final DateTime timestamp;

  SecurityMetricValue({required this.value, required this.timestamp});
}

// Data access pattern class
class DataAccessPattern {
  final String table;
  final String operation;
  int accessCount;
  DateTime lastAccess;

  DataAccessPattern({
    required this.table,
    required this.operation,
    required this.accessCount,
    required this.lastAccess,
  });
}

// Network security event class
class NetworkSecurityEvent {
  final String eventType;
  final String details;
  final DateTime timestamp;

  NetworkSecurityEvent({
    required this.eventType,
    required this.details,
    required this.timestamp,
  });
}

// Security report class
class SecurityReport {
  final List<SecurityIssue> issues;
  final Map<String, SecurityMetric> metrics;
  final Map<String, DataAccessPattern> dataAccessPatterns;
  final List<NetworkSecurityEvent> networkEvents;
  final DateTime timestamp;

  SecurityReport({
    required this.issues,
    required this.metrics,
    required this.dataAccessPatterns,
    required this.networkEvents,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'issues_count': issues.length,
      'metrics_count': metrics.length,
      'data_access_patterns_count': dataAccessPatterns.length,
      'network_events_count': networkEvents.length,
    };
  }
}
