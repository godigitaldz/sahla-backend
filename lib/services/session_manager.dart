import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../models/user.dart' as app_user;
import '../utils/preferences_utils.dart';
import 'secure_storage_service.dart';
import 'token_utils.dart';

/// Session states for UI feedback
enum SessionState {
  restoring,
  authenticated,
  unauthenticated,
  refreshing,
  error,
}

/// Main session manager that handles persistent phone-auth sessions
/// Uses Supabase as the source of truth with minimal local storage
class SessionManager extends ChangeNotifier {
  // Singleton pattern for global access
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  // Supabase client
  supa.SupabaseClient get _supabase => supa.Supabase.instance.client;

  // Secure storage service
  final SecureStorageService _secureStorage = SecureStorageService();

  // Session state
  SessionState _sessionState = SessionState.restoring;
  app_user.User? _currentUser;
  String? _lastError;
  bool _isInitialized = false;

  // Session monitoring
  Timer? _sessionMonitorTimer;
  static const Duration _sessionCheckInterval = Duration(minutes: 5);
  static const Duration _tokenRefreshThreshold = Duration(minutes: 10);

  // Refresh retry logic
  int _refreshRetryCount = 0;
  static const int _maxRefreshRetries = 3;
  Timer? _refreshRetryTimer;

  // Getters
  SessionState get sessionState => _sessionState;
  app_user.User? get currentUser => _currentUser;
  bool get isAuthenticated =>
      _currentUser != null && _sessionState == SessionState.authenticated;
  bool get isInitialized => _isInitialized;
  bool get isLoading =>
      _sessionState == SessionState.restoring ||
      _sessionState == SessionState.refreshing;
  String? get lastError => _lastError;

  // Prevent concurrent initialization
  bool _isInitializing = false;

  /// Initialize the session manager (synchronous ultra-fast version)
  void initializeSync() {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    try {
      // Start with restoring state (synchronous)
      _sessionState = SessionState.restoring;

      // Restore session synchronously for ultra-fast loading
      _restoreSessionSync();

      _isInitialized = true;
    } catch (e) {
      _sessionState = SessionState.error;
      _lastError = 'Failed to initialize session: $e';
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Initialize the session manager (legacy async version)
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isInitializing) {
      // Wait for sync initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return;
    }
    _isInitializing = true;

    try {
      // Start with restoring state
      _sessionState = SessionState.restoring;
      notifyListeners();

      // Restore session from secure storage and Supabase
      await _restoreSession();

      _isInitialized = true;
    } catch (e) {
      _sessionState = SessionState.error;
      _lastError = 'Failed to initialize session: $e';
      _isInitialized = false;
      notifyListeners();
    } finally {
      _isInitializing = false;
    }
  }

  /// Restore session at startup (used by SplashScreen)
  Future<void> restore() async {
    if (!_isInitialized) {
      await initialize();
      return;
    }

    try {
      debugPrint('🔄 SessionManager: Restoring session...');
      _sessionState = SessionState.restoring;
      notifyListeners();

      await _restoreSession();
    } catch (e) {
      debugPrint('❌ SessionManager: Session restoration failed: $e');
      _sessionState = SessionState.error;
      _lastError = 'Session restoration failed: $e';
      notifyListeners();
    }
  }

  /// Internal session restoration logic (synchronous ultra-fast version)
  void _restoreSessionSync() {
    try {
      final session = _supabase.auth.currentSession;

      if (session != null) {
        debugPrint(
            '🔍 SessionManager: Active session found, validating (sync)...');

        // Check if session is valid and not expired (synchronous)
        final now = DateTime.now().millisecondsSinceEpoch / 1000;
        final expiresAt = session.expiresAt ?? 0;
        final timeUntilExpiry = expiresAt - now;

        if (timeUntilExpiry < 300) {
          // Less than 5 minutes - session is too close to expiry, treat as unauthenticated
          debugPrint(
              '⚠️ Session expires soon, treating as unauthenticated for security...');
          _sessionState = SessionState.unauthenticated;
          _currentUser = null;
        } else {
          debugPrint('✅ Session is valid, loading user (sync)...');
          _loadUserFromSessionSync();
          _startSessionMonitoring();
        }
      } else {
        debugPrint('ℹ️ No active session found (sync)');
        _sessionState = SessionState.unauthenticated;
        _currentUser = null;

        // Attempt metadata restoration in background (non-blocking) for session persistence
        // Supabase should have the session, but this is a safety fallback
        unawaited(_tryRestoreFromStoredMetadata().then((_) {
          if (_currentUser != null) {
            notifyListeners();
          }
        }));
      }
    } catch (e) {
      debugPrint('❌ SessionManager: Session restoration error (sync): $e');
      _sessionState = SessionState.error;
      _lastError = 'Session restoration failed: $e';
      _currentUser = null;
    } finally {
      // Skip notifyListeners for ultra-fast loading (will notify after async restore if needed)
    }
  }

  /// Internal session restoration logic (legacy async version)
  Future<void> _restoreSession() async {
    try {
      final session = _supabase.auth.currentSession;

      if (session != null) {
        debugPrint('🔍 SessionManager: Active session found, validating...');

        // Check if session is valid and not expired
        final now = DateTime.now().millisecondsSinceEpoch / 1000;
        final expiresAt = session.expiresAt ?? 0;
        final timeUntilExpiry = expiresAt - now;

        if (timeUntilExpiry < 300) {
          // Less than 5 minutes
          debugPrint('⚠️ Session expires soon, refreshing...');
          await _refreshSessionWithRetry();
        } else {
          debugPrint('✅ Session is valid, loading user...');
          await _loadUserFromSession();
          _startSessionMonitoring();
        }
      } else {
        debugPrint('ℹ️ No active session found');
        _sessionState = SessionState.unauthenticated;
        _currentUser = null;

        // Try to restore from stored metadata if available
        await _tryRestoreFromStoredMetadata();
      }
    } catch (e) {
      debugPrint('❌ SessionManager: Session restoration error: $e');
      _sessionState = SessionState.error;
      _lastError = 'Session restoration failed: $e';
      _currentUser = null;
    } finally {
      notifyListeners();
    }
  }

  /// Try to restore session from stored metadata (fallback mechanism)
  Future<void> _tryRestoreFromStoredMetadata() async {
    try {
      final storedUserId = await _secureStorage.getString('user_id');
      final lastRefreshAt = await _secureStorage.getString('last_refresh_at');

      if (storedUserId != null && lastRefreshAt != null) {
        final lastRefresh = DateTime.tryParse(lastRefreshAt);
        final now = DateTime.now();

        // Only try to restore if last refresh was recent (within 24 hours)
        if (lastRefresh != null && now.difference(lastRefresh).inHours < 24) {
          debugPrint(
              '🔄 SessionManager: Attempting recovery from stored metadata...');

          try {
            // Try to refresh session from stored tokens
            final refreshResult = await _supabase.auth.refreshSession();
            if (refreshResult.session != null) {
              debugPrint('✅ SessionManager: Session recovered successfully');
              await _loadUserFromSession();
              _startSessionMonitoring();
              return;
            }
          } catch (e) {
            debugPrint('⚠️ SessionManager: Session recovery failed: $e');
          }
        }
      }

      // Clear stored metadata if recovery failed
      await _clearStoredSessionData();
    } catch (e) {
      debugPrint('⚠️ SessionManager: Metadata restoration error: $e');
    }
  }

  /// Start periodic session monitoring
  void _startSessionMonitoring() {
    debugPrint('🔄 SessionManager: Starting session monitoring');
    _stopSessionMonitoring(); // Stop any existing timer

    _sessionMonitorTimer = Timer.periodic(_sessionCheckInterval, (timer) {
      _checkAndRefreshSession();
    });
  }

  /// Stop session monitoring
  void _stopSessionMonitoring() {
    _sessionMonitorTimer?.cancel();
    _sessionMonitorTimer = null;
  }

  /// Check session expiration and refresh if needed
  Future<void> _checkAndRefreshSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        debugPrint('⚠️ SessionManager: No active session during monitoring');
        _stopSessionMonitoring();
        await _handleSessionInvalidated();
        return;
      }

      final secondsUntilExpiry =
          TokenUtils.secondsUntilExpiry(session.accessToken);

      if (secondsUntilExpiry < _tokenRefreshThreshold.inSeconds) {
        debugPrint(
            '⚠️ SessionManager: Token expires soon, refreshing proactively...');
        await _refreshSessionWithRetry();
      }
    } catch (e) {
      debugPrint('❌ SessionManager: Error during session monitoring: $e');
      await _handleSessionRefreshError(e);
    }
  }

  /// Refresh session with retry logic and exponential backoff
  Future<void> _refreshSessionWithRetry() async {
    if (_sessionState == SessionState.refreshing) return; // Already refreshing

    try {
      _sessionState = SessionState.refreshing;
      _refreshRetryCount = 0;
      notifyListeners();

      await _performSessionRefresh();
    } catch (e) {
      debugPrint('❌ SessionManager: Session refresh failed: $e');
      await _handleSessionRefreshError(e);
    } finally {
      if (_sessionState == SessionState.refreshing) {
        _sessionState = isAuthenticated
            ? SessionState.authenticated
            : SessionState.unauthenticated;
        notifyListeners();
      }
    }
  }

  /// Perform the actual session refresh
  Future<void> _performSessionRefresh() async {
    const maxRetries = 3;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        debugPrint(
            '🔄 SessionManager: Refresh attempt ${attempt + 1}/$maxRetries');

        final refreshResult = await _supabase.auth.refreshSession();

        if (refreshResult.session != null) {
          debugPrint('✅ SessionManager: Session refreshed successfully');

          // Update stored metadata
          await _updateStoredSessionMetadata();

          // Reload user data if needed
          if (_currentUser != null) {
            await _loadUserFromSession();
          }

          _refreshRetryCount = 0;
          return;
        } else {
          throw Exception('Refresh returned null session');
        }
      } catch (e) {
        debugPrint(
            '⚠️ SessionManager: Refresh attempt ${attempt + 1} failed: $e');

        if (attempt == maxRetries - 1) {
          rethrow; // Last attempt failed
        }

        // Exponential backoff with jitter
        final delayMs =
            (1000 * pow(2, attempt)).toInt() + Random().nextInt(500);
        debugPrint('⏳ SessionManager: Retrying in ${delayMs}ms...');
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  /// Handle session refresh errors with retry and fallback
  Future<void> _handleSessionRefreshError(dynamic error) async {
    _refreshRetryCount++;

    debugPrint('❌ SessionManager: Refresh error #$_refreshRetryCount: $error');

    if (_refreshRetryCount >= _maxRefreshRetries) {
      debugPrint(
          '❌ SessionManager: Max refresh retries reached, signing out...');
      await logout();
      return;
    }

    // Schedule retry with exponential backoff
    final delayMs = (2000 * pow(2, _refreshRetryCount - 1)).toInt() +
        Random().nextInt(1000);
    debugPrint('⏳ SessionManager: Retrying refresh in ${delayMs}ms...');

    _refreshRetryTimer?.cancel();
    _refreshRetryTimer = Timer(Duration(milliseconds: delayMs), () {
      _refreshSessionWithRetry();
    });
  }

  /// Handle invalidated session (logout and cleanup)
  Future<void> _handleSessionInvalidated() async {
    debugPrint('🚪 SessionManager: Session invalidated, signing out...');
    await logout();
  }

  /// Load user from current session (synchronous ultra-fast version)
  void _loadUserFromSessionSync() {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        debugPrint(
            '❌ SessionManager: No session available for user loading (sync)');
        _currentUser = null;
        _sessionState = SessionState.unauthenticated;
        return;
      }

      final user = session.user;

      debugPrint(
          '🔍 SessionManager: Loading user profile for: ${user.id} (sync)');

      // ULTRA-FAST LOADING: Skip database calls for 0.05s target
      // Create minimal user object for immediate UI rendering
      _currentUser = app_user.User(
        id: user.id,
        name: 'User', // Minimal default name
        email: '', // No email for phone-only auth
        phone: '', // Skip phone lookup for speed
        profileImage: null,
        role: app_user.UserRole.customer, // Default role
        isEmailVerified: true, // No email verification required
        isPhoneVerified: false, // Skip verification check for speed
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        preferences: PreferencesUtils.getDefaultPreferences(),
      );

      _sessionState = SessionState.authenticated;
      debugPrint(
          '✅ SessionManager: User loaded successfully (sync ultra-fast)');

      // Skip metadata update for ultra-fast loading
    } catch (e) {
      debugPrint('❌ SessionManager: Error loading user profile (sync): $e');
      _sessionState = SessionState.error;
      _lastError = 'Failed to load user profile: $e';
      _currentUser = null;
    }
  }

  /// Load user from current session (legacy async version)
  Future<void> _loadUserFromSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        debugPrint('❌ SessionManager: No session available for user loading');
        _currentUser = null;
        _sessionState = SessionState.unauthenticated;
        return;
      }

      final user = session.user;

      debugPrint('🔍 SessionManager: Loading user profile for: ${user.id}');

      // Get user profile from database
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .single();

      // Parse user preferences
      Map<String, dynamic> userPreferences = {};
      if (response['preferences'] != null) {
        try {
          if (response['preferences'] is Map) {
            userPreferences =
                Map<String, dynamic>.from(response['preferences']);
          } else if (response['preferences'] is String) {
            userPreferences =
                Map<String, dynamic>.from(jsonDecode(response['preferences']));
          }
          userPreferences = PreferencesUtils.mergeWithDefaults(userPreferences);
        } catch (e) {
          debugPrint('❌ SessionManager: Error parsing preferences: $e');
          userPreferences = PreferencesUtils.getDefaultPreferences();
        }
      } else {
        userPreferences = PreferencesUtils.getDefaultPreferences();
      }

      // Create user object
      _currentUser = app_user.User(
        id: user.id,
        name: response['name'] ?? 'User',
        email: '', // No email for phone-only auth
        phone: response['phone'] ?? '',
        profileImage: response['profile_image'],
        role: _parseUserRole(response['role'] ?? 'customer'),
        isEmailVerified: true, // No email verification required
        isPhoneVerified: response['is_verified'] ?? false,
        createdAt: DateTime.parse(
            response['created_at'] ?? DateTime.now().toIso8601String()),
        lastLoginAt: response['updated_at'] != null
            ? DateTime.parse(response['updated_at'])
            : null,
        preferences: userPreferences,
      );

      _sessionState = SessionState.authenticated;
      debugPrint('✅ SessionManager: User loaded successfully');

      // Update stored metadata
      await _updateStoredSessionMetadata();
    } catch (e) {
      // Check if it's a DNS/network error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('socketexception') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('nodename nor servname') ||
          errorString.contains('connection refused') ||
          errorString.contains('network is unreachable')) {
        debugPrint(
          '⚠️ SessionManager: Network/DNS error loading user profile: $e\n'
          '💡 This is likely a simulator/emulator network issue. Troubleshooting:\n'
          '   - iOS Simulator: Settings > General > Reset > Reset Network Settings\n'
          '   - Android Emulator: Cold boot the emulator\n'
          '   - Try using a physical device instead\n'
          '   - Check your host machine\'s internet connection',
        );
      } else {
        debugPrint('❌ SessionManager: Error loading user profile: $e');
      }
      _sessionState = SessionState.error;
      _lastError = 'Failed to load user profile: $e';
      _currentUser = null;
    }
  }

  /// Parse user role from string
  app_user.UserRole _parseUserRole(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'admin':
        return app_user.UserRole.admin;
      case 'restaurant_owner':
      case 'restaurantowner':
        return app_user.UserRole.restaurantOwner;
      case 'delivery_man':
      case 'deliveryman':
        return app_user.UserRole.deliveryMan;
      case 'customer':
      default:
        return app_user.UserRole.customer;
    }
  }

  /// Set current user after phone authentication
  Future<void> setCurrentUser(app_user.User user) async {
    try {
      debugPrint('👤 SessionManager: Setting current user after phone auth...');
      _currentUser = user;
      _sessionState = SessionState.authenticated;
      _lastError = null;

      // Store minimal session metadata (no tokens)
      await _updateStoredSessionMetadata();

      _startSessionMonitoring();
      notifyListeners();

      debugPrint('✅ SessionManager: Current user set successfully');
    } catch (e) {
      debugPrint('❌ SessionManager: Error setting current user: $e');
      _lastError = 'Failed to set current user: $e';
      notifyListeners();
      throw Exception('Failed to set current user: $e');
    }
  }

  /// Update stored session metadata (minimal data only)
  Future<void> _updateStoredSessionMetadata() async {
    try {
      if (_currentUser != null) {
        await _secureStorage.setString('user_id', _currentUser!.id);
        await _secureStorage.setString(
            'last_refresh_at', DateTime.now().toIso8601String());
      }
    } catch (e) {
      debugPrint('⚠️ SessionManager: Failed to update stored metadata: $e');
      // Don't fail the operation for metadata storage issues
    }
  }

  /// Clear stored session data
  Future<void> _clearStoredSessionData() async {
    try {
      await _secureStorage.clear();
      debugPrint('🧹 SessionManager: Stored session data cleared');
    } catch (e) {
      debugPrint('⚠️ SessionManager: Failed to clear stored data: $e');
    }
  }

  /// Force refresh the current session
  Future<bool> forceRefreshSession() async {
    try {
      debugPrint('🔄 SessionManager: Manual session refresh requested');

      await _refreshSessionWithRetry();

      final session = _supabase.auth.currentSession;
      return session != null;
    } catch (e) {
      debugPrint('❌ SessionManager: Manual session refresh failed: $e');
      return false;
    }
  }

  /// Ensure user is authenticated (refresh if needed)
  Future<bool> ensureAuthenticated() async {
    try {
      var session = _supabase.auth.currentSession;

      if (session == null) {
        debugPrint(
            'ℹ️ SessionManager: No active session, attempting refresh...');
        await _refreshSessionWithRetry();
        session = _supabase.auth.currentSession;
      }

      if (session == null) {
        debugPrint('❌ SessionManager: Still no active session after refresh');
        _currentUser = null;
        _sessionState = SessionState.unauthenticated;
        notifyListeners();
        return false;
      }

      // Check if we need to reload user data
      if (_currentUser == null) {
        await _loadUserFromSession();
      }

      return isAuthenticated;
    } catch (e) {
      debugPrint('❌ SessionManager: ensureAuthenticated failed: $e');
      _sessionState = SessionState.error;
      _lastError = 'Authentication check failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get current access token for Socket.IO authentication
  Future<String?> getCurrentAccessToken() async {
    try {
      final session = _supabase.auth.currentSession;
      return session?.accessToken;
    } catch (e) {
      debugPrint('⚠️ SessionManager: Failed to get access token: $e');
      return null;
    }
  }

  /// Logout and clear all session data
  Future<void> logout() async {
    try {
      debugPrint('🚪 SessionManager: Logging out...');

      // Stop monitoring
      _stopSessionMonitoring();
      _refreshRetryTimer?.cancel();

      // Sign out from Supabase
      try {
        await _supabase.auth.signOut();
      } catch (e) {
        debugPrint('⚠️ SessionManager: Supabase sign out failed: $e');
      }

      // Clear local state
      _currentUser = null;
      _sessionState = SessionState.unauthenticated;
      _lastError = null;

      // Clear stored data
      await _clearStoredSessionData();

      notifyListeners();
      debugPrint('✅ SessionManager: Logout successful');
    } catch (e) {
      debugPrint('❌ SessionManager: Logout error: $e');
      // Force state cleanup even if there are errors
      _currentUser = null;
      _sessionState = SessionState.unauthenticated;
      await _clearStoredSessionData();
      notifyListeners();
    }
  }

  /// Get session status for debugging
  Map<String, dynamic> getSessionStatus() {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      return {
        'isAuthenticated': false,
        'sessionState': _sessionState.toString(),
        'hasSession': false,
        'currentUser': _currentUser?.id,
      };
    }

    final secondsUntilExpiry =
        TokenUtils.secondsUntilExpiry(session.accessToken);

    return {
      'isAuthenticated': isAuthenticated,
      'sessionState': _sessionState.toString(),
      'hasSession': true,
      'currentUser': _currentUser?.id,
      'sessionExpiry': DateTime.fromMillisecondsSinceEpoch(
          (session.expiresAt! * 1000).round()),
      'secondsUntilExpiry': secondsUntilExpiry,
      'refreshRetryCount': _refreshRetryCount,
    };
  }

  @override
  void dispose() {
    _stopSessionMonitoring();
    _refreshRetryTimer?.cancel();
    super.dispose();
  }
}
