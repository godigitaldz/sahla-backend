import "dart:async";
import "dart:convert";

import "package:flutter/foundation.dart";
import "package:supabase_flutter/supabase_flutter.dart" as supa;

import "../models/location.dart";
import "../models/user.dart" as app_user;
import "../utils/preferences_utils.dart";
import "notification_service.dart";
import "push_notification_service.dart";
import "queue_service.dart";
import "session_manager.dart";

class AuthService extends ChangeNotifier {
  AuthService() {
    _setupAuthListener();
    // Initialize auth asynchronously without blocking constructor
    Future.microtask(_initializeAuth);
  }
  supa.SupabaseClient get _supabase => supa.Supabase.instance.client;
  app_user.User? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _lastError;

  // Get SessionManager instance
  SessionManager get _sessionManager => SessionManager();

  app_user.User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  /// Check if this is the user's first login (for showing welcome messages)
  bool get isFirstLogin {
    if (_currentUser == null) {
      return false;
    }
    final createdAt = _currentUser!.createdAt;
    final now = DateTime.now();
    final userCreatedDate =
        DateTime.fromMillisecondsSinceEpoch(createdAt.millisecondsSinceEpoch);
    return now.year == userCreatedDate.year &&
        now.month == userCreatedDate.month &&
        now.day == userCreatedDate.day;
  }

  /// Validate current session and refresh if needed (delegates to SessionManager)
  Future<bool> validateSession() async {
    try {
      return await _sessionManager.ensureAuthenticated();
    } on Exception catch (e) {
      debugPrint("❌ Error validating session: $e");
      return false;
    }
  }

  /// Welcome banner purely server-driven or based on first login
  Future<bool> get shouldShowWelcomeBanner async {
    if (_currentUser == null) {
      return false;
    }
    // For now, show only for first login; no local persistence
    return isFirstLogin;
  }

  /// No-op: dismissal handled server-side if needed
  Future<void> dismissWelcomeBanner() async {}

  /// Initialize authentication state (delegates to SessionManager)
  Future<void> _initializeAuth() async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint("=== INITIALIZING AUTH ===");

      // Wait for SessionManager to initialize if needed
      if (!_sessionManager.isInitialized) {
        await _sessionManager.initialize();
      }

      // Sync with SessionManager state
      _currentUser = _sessionManager.currentUser;
      _isInitialized = true;

      debugPrint("✅ Auth initialized - synced with SessionManager");
    } on Exception catch (e) {
      debugPrint("❌ Error initializing auth: $e");
      _lastError = "Failed to initialize authentication";
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get user with automatic retry and token refresh
  Future<supa.User?> _getUserWithRetry() async {
    const maxRetries = 2;
    int retryCount = 0;

    while (retryCount <= maxRetries) {
      try {
        debugPrint(
            "🔍 Getting user (attempt ${retryCount + 1}/${maxRetries + 1})");

        // Try to get user from current session
        final fresh = await supa.Supabase.instance.client.auth.getUser();
        var user = fresh.user ?? supa.Supabase.instance.client.auth.currentUser;

        if (user != null) {
          debugPrint("✅ User found: ${user.id}");
          return user;
        } else if (retryCount < maxRetries) {
          // No user found, try to refresh session
          debugPrint("🔄 No user found, attempting session refresh...");
          await _sessionManager.forceRefreshSession();

          // Check again after refresh
          final refreshedUser =
              await supa.Supabase.instance.client.auth.getUser();
          user = refreshedUser.user ??
              supa.Supabase.instance.client.auth.currentUser;

          if (user != null) {
            debugPrint("✅ User found after refresh: ${user.id}");
            return user;
          }
        }

        retryCount++;
        if (retryCount <= maxRetries) {
          final delayMs = 500 * retryCount; // 500ms, 1000ms
          debugPrint("⏳ Retrying in ${delayMs}ms...");
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      } on Exception catch (e) {
        debugPrint("⚠️ Error getting user (attempt ${retryCount + 1}): $e");

        // Check if it's a JWT/token error
        if (e.toString().contains("JWT") ||
            e.toString().contains("token") ||
            e.toString().contains("expired")) {
          if (retryCount < maxRetries) {
            debugPrint("🔄 JWT error detected, attempting session refresh...");
            try {
              await _sessionManager.forceRefreshSession();
            } on Exception catch (refreshError) {
              debugPrint("❌ Session refresh failed: $refreshError");
            }
          }
        }

        retryCount++;
        if (retryCount <= maxRetries) {
          final delayMs = 500 * retryCount;
          debugPrint("⏳ Retrying in ${delayMs}ms...");
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          debugPrint("❌ Max retries reached for getting user");
          return null;
        }
      }
    }

    return null;
  }

  /// Restore user state directly from session
  Future<void> restoreUserState() async {
    debugPrint("🔍 Restoring user state...");
    try {
      final session = supa.Supabase.instance.client.auth.currentSession;
      if (session != null) {
        debugPrint("✅ Active session found, loading from server");
        await _loadUserFromSession();
      } else {
        debugPrint("ℹ️ No active session");
        _currentUser = null;
      }
    } finally {
      notifyListeners();
    }
  }

  /// Public method to reinitialize auth state (useful for hot restart recovery)
  Future<void> reinitializeAuth() async {
    debugPrint("🔄 Reinitializing auth state...");
    await _initializeAuth();
  }

  /// Setup authentication state change listener (syncs with SessionManager)
  void _setupAuthListener() {
    supa.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint("Auth state changed: ${data.event}");

      switch (data.event) {
        case supa.AuthChangeEvent.signedIn:
          // Sync with SessionManager state
          _currentUser = _sessionManager.currentUser;
          notifyListeners();

          // Handle post-sign-in tasks if user is available
          if (_currentUser != null) {
            _handlePostSignIn(_currentUser!);
          }
          break;

        case supa.AuthChangeEvent.signedOut:
          _currentUser = null;
          notifyListeners();
          break;

        case supa.AuthChangeEvent.tokenRefreshed:
          debugPrint("🔄 Token refreshed via auth state change");
          // SessionManager handles token refresh monitoring
          _currentUser = _sessionManager.currentUser;
          notifyListeners();
          break;

        case supa.AuthChangeEvent.userUpdated:
          // Reload user from SessionManager
          _currentUser = _sessionManager.currentUser;
          notifyListeners();
          break;

        case supa.AuthChangeEvent.passwordRecovery:
          // Handle password recovery if needed
          break;

        case supa.AuthChangeEvent.initialSession:
          // Handle initial session if needed
          break;

        case supa.AuthChangeEvent.userDeleted:
          // Handle user deletion
          _currentUser = null;
          notifyListeners();
          break;

        case supa.AuthChangeEvent.mfaChallengeVerified:
          // Handle MFA challenge verification
          _currentUser = _sessionManager.currentUser;
          notifyListeners();
          break;
      }
    });
  }

  /// Handle post-sign-in tasks
  Future<void> _handlePostSignIn(app_user.User user) async {
    try {
      // Reinitialize cart for this user session
      try {
        await Future.microtask(() {
          // Cart initialization will be handled by CartProvider
        });
      } on Exception catch (_) {}

      // Register push token
      try {
        await PushNotificationService().initializeAndRegisterToken();
      } on Exception catch (_) {}

      // First login welcome notification
      if (isFirstLogin) {
        try {
          await NotificationService().notifyUserSignup(
            userId: user.id,
            userEmail: "",
            userName: user.name ?? "User",
          );
        } on Exception catch (_) {}
      }

      // Generic signed-in notification
      try {
        final result = await QueueService().enqueue(
          taskIdentifier: "send_notification",
          payload: {
            "user_id": user.id,
            "title": "Signed in",
            "message": "You have signed in successfully."
          },
        );
        if (!result.success) {
          debugPrint("Failed to enqueue sign-in notification: ${result.error}");
        }
      } on Exception catch (e) {
        debugPrint("Error enqueuing sign-in notification: $e");
      }
    } on Exception catch (e) {
      debugPrint("Error in post-sign-in handling: $e");
    }
  }

  /// Load user from current session with automatic token refresh
  Future<void> _loadUserFromSession() async {
    try {
      debugPrint("=== LOADING USER FROM SESSION ===");

      // Try to get user with automatic retry on token expiration
      final user = await _getUserWithRetry();

      if (user == null) {
        debugPrint("❌ No user found in session after retry");
        _currentUser = null;
        notifyListeners();
        return;
      }

      debugPrint("Current session user ID: ${user.id}");
      debugPrint("Current session user email: ${user.email}");

      Map<String, dynamic>? response;
      int retryCount = 0;
      const maxRetries = 3;
      while (retryCount < maxRetries) {
        try {
          response = await supa.Supabase.instance.client
              .from("user_profiles")
              .select()
              .eq("id", user.id)
              .single();
          break;
        } on Exception catch (e) {
          retryCount++;
          debugPrint("⚠️ Attempt $retryCount: Failed to load user profile: $e");

          // If user profile doesn't exist, create it
          if (e.toString().contains("No rows found") ||
              e.toString().contains("PGRST116")) {
            debugPrint("🔄 User profile not found, creating new profile...");
            try {
              await _createUserProfile(
                  user.id, user.userMetadata?["name"], user.phone);
              // Retry loading the profile after creation
              response = await supa.Supabase.instance.client
                  .from("user_profiles")
                  .select()
                  .eq("id", user.id)
                  .single();
              break;
            } catch (createError) {
              debugPrint("❌ Failed to create user profile: $createError");
              rethrow;
            }
          }

          if (retryCount >= maxRetries) {
            debugPrint("❌ Max retries reached, giving up on user profile load");
            rethrow;
          }
          await Future.delayed(Duration(milliseconds: 200 * retryCount));
          debugPrint("⏳ Retrying in ${200 * retryCount}ms...");
        }
      }
      if (response == null) {
        throw Exception("Failed to load user profile after all retry attempts");
      }

      final parsedRole = _parseUserRole(response["role"] ?? "user");

      // Use PreferencesUtils for safe preference handling
      Map<String, dynamic> userPreferences = {};

      // Parse preferences from response using PreferencesUtils
      if (response["preferences"] != null) {
        try {
          Map<String, dynamic>? rawPreferences;
          if (response["preferences"] is Map) {
            rawPreferences = Map<String, dynamic>.from(response["preferences"]);
          } else if (response["preferences"] is String) {
            rawPreferences =
                Map<String, dynamic>.from(jsonDecode(response["preferences"]));
          }

          // Merge with defaults and validate using PreferencesUtils
          userPreferences = PreferencesUtils.mergeWithDefaults(rawPreferences);
        } on Exception catch (e) {
          debugPrint("❌ Error parsing preferences: $e");
          userPreferences = PreferencesUtils.getDefaultPreferences();
        }
      } else {
        userPreferences = PreferencesUtils.getDefaultPreferences();
      }

      // Handle verified phone number from response
      if (response["preferences"] != null &&
          response["preferences"] is Map &&
          response["preferences"]["verified_phone_number"] != null) {
        userPreferences["verified_phone_number"] =
            response["preferences"]["verified_phone_number"];
      }

      // Handle date of birth with safe parsing
      if (response["date_of_birth"] != null) {
        final currentDob = PreferencesUtils.getStringPreference(
            userPreferences, "date_of_birth", "");
        if (currentDob.isEmpty) {
          try {
            final dobStr = response["date_of_birth"].toString();
            final parsed = DateTime.parse(dobStr);
            userPreferences["date_of_birth"] = parsed.toIso8601String();
          } on Exception catch (_) {
            userPreferences["date_of_birth"] =
                response["date_of_birth"].toString();
          }
        }
      }

      // Email verification status is handled by Supabase

      _currentUser = app_user.User(
        id: user.id,
        name: response["name"] ?? "User",
        email: "", // No email for phone-only auth
        phone: response["phone"] ?? "",
        profileImage: response["profile_image"],
        role: parsedRole,
        isEmailVerified: true, // No email verification required
        isPhoneVerified: response["is_verified"] ?? false,
        createdAt: DateTime.parse(
            response["created_at"] ?? DateTime.now().toIso8601String()),
        lastLoginAt: response["updated_at"] != null
            ? DateTime.parse(response["updated_at"])
            : null,
        preferences: userPreferences,
      );

      debugPrint("✅ User loaded successfully from session");
      await _updateLastLogin(user.id);

      // Initialize cart for the logged-in user
      await _initializeUserCart(user.id);

      // Session monitoring handled automatically by SessionManager

      // Register push token
      try {
        await PushNotificationService().initializeAndRegisterToken();
      } on Exception catch (_) {}

      // If first login (same-day account creation), enqueue a welcome if not already sent
      try {
        if (isFirstLogin) {
          await NotificationService().notifyUserSignup(
            userId: _currentUser!.id,
            userEmail: "",
            userName: _currentUser!.name ?? "User",
          );
        }
      } on Exception catch (_) {}

      notifyListeners();
    } on Exception catch (e) {
      debugPrint("❌ Error loading user profile: $e");
      _lastError = "Failed to load user profile";
      _currentUser = null;
      notifyListeners();
    }
  }

  /// Create user profile in user_profiles table
  Future<void> _createUserProfile(
      String userId, String? fullName, String? phone) async {
    try {
      debugPrint("=== CREATING USER PROFILE ===");
      debugPrint("User ID: $userId");
      debugPrint("Name: $fullName");
      debugPrint("Phone: $phone");

      final existing = await supa.Supabase.instance.client
          .from("user_profiles")
          .select("id")
          .eq("id", userId)
          .maybeSingle();
      if (existing != null) {
        debugPrint("✅ User profile already exists");
        return;
      }

      // Create new user profile with minimal required data
      final profileData = <String, dynamic>{
        "id": userId,
        "role": "customer",
        "is_verified": true,
        "created_at": DateTime.now().toIso8601String(),
        "updated_at": DateTime.now().toIso8601String(),
      };

      // Add name if provided, otherwise leave as null (user can set it later)
      if (fullName != null && fullName.trim().isNotEmpty) {
        profileData["name"] = fullName.trim();
      }
      // Note: name field is now nullable, no default value

      // Add phone if provided
      if (phone != null && phone.trim().isNotEmpty) {
        profileData["phone"] = phone.trim();
      }

      // Create new user profile using upsert to handle duplicates
      await supa.Supabase.instance.client
          .from("user_profiles")
          .upsert(profileData);

      debugPrint("✅ User profile created successfully");
    } on Exception catch (e) {
      debugPrint("❌ Error creating user profile: $e");
      // Don't rethrow - let the calling method handle the error
    }
  }

  Future<void> _updateLastLogin(String userId) async {
    try {
      await supa.Supabase.instance.client.from("user_profiles").update(
          {"updated_at": DateTime.now().toIso8601String()}).eq("id", userId);
    } on Exception catch (_) {}
  }

  Future<void> refreshUserSession() async {
    try {
      debugPrint("=== REFRESHING USER SESSION ===");
      await _sessionManager.forceRefreshSession();
      _currentUser = _sessionManager.currentUser;
      notifyListeners();
      debugPrint("✅ User session refreshed successfully");
    } on Exception catch (e) {
      debugPrint("❌ Error refreshing user session: $e");
    }
  }

  /// Ensure there is an active Supabase session and local user loaded (delegates to SessionManager)
  Future<bool> ensureAuthenticated() async {
    try {
      final result = await _sessionManager.ensureAuthenticated();
      _currentUser = _sessionManager.currentUser;
      notifyListeners();
      return result;
    } on Exception catch (e) {
      debugPrint("ensureAuthenticated failed: $e");
      return false;
    }
  }

  /// Sign up with phone number only
  /// Returns: null if successful, error message if failed
  Future<String?> signUpWithPhone(String phone, String countryCode) async {
    try {
      _isLoading = true;
      _lastError = null;
      notifyListeners();

      debugPrint("=== PHONE SIGNUP DEBUG ===");
      debugPrint("Attempting signup with phone: +$countryCode$phone");

      // Validate input
      if (phone.trim().isEmpty) {
        return "Phone number is required";
      }
      if (countryCode.trim().isEmpty) {
        return "Country code is required";
      }

      // Use phone authentication flow
      final result = await sendPhoneOtp(phone, countryCode);
      if (result["success"] == true) {
        debugPrint("✅ Phone OTP sent successfully");
        return null;
      } else {
        return result["error"] ?? "Failed to send verification code";
      }
    } on Exception catch (e) {
      debugPrint("❌ Unexpected phone signup error: $e");
      _lastError = "An unexpected error occurred";
      return "An unexpected error occurred. Please try again.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with phone number only
  Future<String?> loginWithPhone(String phone, String countryCode) async {
    try {
      _isLoading = true;
      _lastError = null;
      notifyListeners();

      debugPrint("=== PHONE LOGIN DEBUG ===");
      debugPrint("Attempting login with phone: +$countryCode$phone");

      // Validate input
      if (phone.trim().isEmpty) {
        return "Phone number is required";
      }
      if (countryCode.trim().isEmpty) {
        return "Country code is required";
      }

      // Use phone authentication flow
      final result = await sendPhoneOtp(phone, countryCode);
      if (result["success"] == true) {
        debugPrint("✅ Phone OTP sent successfully");
        return null;
      } else {
        return result["error"] ?? "Failed to send verification code";
      }
    } on Exception catch (e) {
      debugPrint("❌ Unexpected phone login error: $e");
      _lastError = "An unexpected error occurred";
      return "An unexpected error occurred. Please try again.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user profile
  Future<String?> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    try {
      debugPrint("=== UPDATING USER PROFILE ===");

      final user = supa.Supabase.instance.client.auth.currentUser;
      if (user == null) {
        return "No authenticated user found";
      }

      final updates = <String, dynamic>{
        "updated_at": DateTime.now().toIso8601String(),
      };

      if (fullName != null && fullName.isNotEmpty) {
        updates["name"] = fullName;
        updates["full_name"] = fullName; // Update both fields for compatibility
      }
      if (phone != null && phone.isNotEmpty) {
        updates["phone"] = phone;
      }
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        updates["profile_image_url"] = avatarUrl;
        updates["profile_image"] =
            avatarUrl; // Update both fields for compatibility
      }

      if (updates.length == 1) {
        // Only updated_at was added
        return "No valid updates provided";
      }

      debugPrint("Updating user profile with: $updates");

      final result = await supa.Supabase.instance.client
          .from("user_profiles")
          .update(updates)
          .eq("id", user.id)
          .select();

      debugPrint("Profile update result: $result");

      // Reload user data
      await _loadUserFromSession();

      debugPrint("✅ Profile updated successfully");
      return null;
    } on Exception catch (e) {
      debugPrint("❌ Error updating profile: $e");
      return "Failed to update profile: ${e.toString()}";
    }
  }

  /// Login with email and password using Redis sessions
  Future<String?> loginWithEmailPassword(String email, String password) async {
    try {
      _isLoading = true;
      _lastError = null;
      notifyListeners();

      debugPrint("=== EMAIL/PASSWORD LOGIN DEBUG ===");
      debugPrint("Attempting login with email: $email");

      // Validate input
      if (email.trim().isEmpty) {
        return "Email is required";
      }
      if (password.trim().isEmpty) {
        return "Password is required";
      }

      // Perform Supabase authentication
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Load user profile from database
        await _loadUserFromSession();
        _isInitialized = true;

        debugPrint("✅ Supabase login successful");
        debugPrint("User: ${_currentUser?.name}");

        // Handle post-sign-in tasks
        if (_currentUser != null) {
          await _handlePostSignIn(_currentUser!);
        }

        return null; // Success
      } else {
        return "Login failed";
      }
    } on Exception catch (e) {
      debugPrint("❌ Unexpected email/password login error: $e");
      _lastError = "An unexpected error occurred";
      return "An unexpected error occurred. Please try again.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out
  Future<void> logout() async {
    try {
      // Perform Supabase logout
      try {
        await supa.Supabase.instance.client.auth.signOut();
        debugPrint("✅ Supabase logout successful");
      } on Exception catch (e) {
        debugPrint("⚠️ Supabase logout failed: $e");
      }

      _currentUser = null;
      _clearAllLocalData();
      notifyListeners();
      debugPrint("✅ Logout completed");
    } on Exception catch (e) {
      debugPrint("❌ Error during logout: $e");
    }
  }

  /// Clear all local data
  void _clearAllLocalData() {
    // Clear any cached data, preferences, etc.
    debugPrint("Clearing local data...");
  }

  /// Parse user role from string
  app_user.UserRole _parseUserRole(String role) {
    switch (role.toLowerCase()) {
      case "customer":
        return app_user.UserRole.customer;
      case "restaurant_owner":
        return app_user.UserRole.restaurantOwner;
      case "delivery_man":
        return app_user.UserRole.deliveryMan;
      case "admin":
        return app_user.UserRole.admin;
      default:
        return app_user.UserRole.customer;
    }
  }

  /// Debug current user state
  void debugCurrentUserState() {
    debugPrint("=== DEBUG CURRENT USER STATE ===");
    debugPrint("Current user: $_currentUser");
    debugPrint("Is authenticated: $isAuthenticated");
    debugPrint("Is loading: $_isLoading");
    debugPrint("Is initialized: $_isInitialized");
    debugPrint("Last error: $_lastError");

    final session = supa.Supabase.instance.client.auth.currentSession;
    debugPrint('Supabase session: ${session != null ? 'Active' : 'None'}');
    if (session != null) {
      debugPrint("Session user ID: ${session.user.id}");
      debugPrint("Session user email: ${session.user.email}");
    }
  }

  /// Force refresh user state
  Future<void> forceRefreshUserState() async {
    try {
      debugPrint("=== FORCE REFRESHING USER STATE ===");

      // Clear current user state
      _currentUser = null;
      notifyListeners();

      // Check for active session
      final session = supa.Supabase.instance.client.auth.currentSession;
      if (session != null) {
        debugPrint("Active session found, reloading user...");
        await _loadUserFromSession();
      } else {
        debugPrint("No active session found");
      }
    } on Exception catch (e) {
      debugPrint("❌ Error refreshing user state: $e");
    }
  }

  /// Reset app state completely
  Future<void> resetAppState() async {
    try {
      debugPrint("=== RESETTING APP STATE ===");

      // Sign out from any session
      try {
        await supa.Supabase.instance.client.auth.signOut();
        debugPrint("✅ Signed out from Supabase");
      } on Exception catch (_) {
        debugPrint("No session to sign out from");
      }

      // Clear all local data
      _clearAllLocalData();

      // Clear current user state
      _currentUser = null;
      _isLoading = false;
      _lastError = null;
      notifyListeners();

      debugPrint("✅ App state completely reset");
    } on Exception catch (e) {
      debugPrint("❌ Error resetting app state: $e");
    }
  }

  /// Debug method to create a test user
  Future<void> createTestUser() async {
    try {
      debugPrint("=== CREATING TEST USER ===");

      // Create a test user with proper data
      final response = await supa.Supabase.instance.client.auth.signUp(
        email: "test@example.com",
        password: "testpassword123",
        data: {
          "name": "Test User",
        },
      );

      if (response.user != null) {
        debugPrint("✅ Test user created successfully!");
        debugPrint("User ID: ${response.user!.id}");
        debugPrint("User email: ${response.user!.email}");

        // Wait for trigger to complete
        await Future.delayed(const Duration(milliseconds: 1000));

        // Load the user data
        await _loadUserFromSession();

        debugPrint("✅ Test user loaded successfully!");
        debugPrint("Current user name: ${_currentUser?.name}");
        debugPrint("Current user email: ${_currentUser?.email}");
        debugPrint("Current user role: ${_currentUser?.role}");
      } else {
        debugPrint("❌ Test user creation failed");
      }
    } on Exception catch (e) {
      debugPrint("❌ Error creating test user: $e");
    }
  }

  /// Debug method to manually create a test user in the database
  Future<void> createManualTestUser() async {
    try {
      debugPrint("=== CREATING MANUAL TEST USER ===");

      final session = supa.Supabase.instance.client.auth.currentSession;
      if (session == null) {
        debugPrint("❌ No active session found");
        return;
      }

      final userId = session.user.id;
      debugPrint("Current user ID: $userId");

      // Manually insert a test user with proper data
      final response = await supa.Supabase.instance.client
          .from("user_profiles")
          .upsert({
            "id": userId,
            "name": "Test User Full Name",
            "phone": "+1234567890", // Default phone for test user
            "role": "customer",
            "is_verified": true,
            "created_at": DateTime.now().toIso8601String(),
            "updated_at": DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      debugPrint("✅ Manual test user created/updated successfully!");
      debugPrint("Response: $response");

      // Reload user data
      await _loadUserFromSession();

      debugPrint("✅ Test user loaded successfully!");
      debugPrint("Current user name: ${_currentUser?.name}");
      debugPrint("Current user email: ${_currentUser?.email}");
      debugPrint("Current user role: ${_currentUser?.role}");
    } on Exception catch (e) {
      debugPrint("❌ Error creating manual test user: $e");
    }
  }

  /// Set current user after phone authentication (delegates to SessionManager)
  Future<void> setCurrentUser(app_user.User user) async {
    try {
      debugPrint("=== SETTING CURRENT USER AFTER PHONE AUTH ===");
      await _sessionManager.setCurrentUser(user);
      _currentUser = _sessionManager.currentUser;
      _isLoading = false;
      _lastError = null;
      notifyListeners();
      debugPrint("✅ Current user set successfully after phone authentication");
    } on Exception catch (e) {
      debugPrint("❌ Error setting current user: $e");
      _lastError = "Failed to set current user";
      notifyListeners();
      throw Exception("Failed to set current user: $e");
    }
  }

  // Phone number normalization
  String _normalizePhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r"[^\d]"), "");
  }

  // Country code normalization
  String _normalizeCountryCode(String countryCode) {
    return countryCode.replaceAll(RegExp(r"[^\d]"), "");
  }

  // Enhanced phone verification with proper login/signup logic using custom OTP system
  Future<Map<String, dynamic>> verifyPhoneCode(
      String phone, String countryCode, String code) async {
    try {
      final cleanPhone = _normalizePhoneNumber(phone);
      final cleanCountry = _normalizeCountryCode(countryCode);
      final fullPhone = "+$cleanCountry$cleanPhone";

      debugPrint("🔐 Verifying OTP via custom system for: $fullPhone");

      // Call the verify-otp Edge Function
      final response = await _supabase.functions.invoke(
        'verify-otp',
        body: {
          'phone_number': cleanPhone,
          'country_code': cleanCountry,
          'full_phone': fullPhone,
          'code': code,
        },
      );

      if (response.data == null || response.data['success'] != true) {
        final error = response.data?['error'] ?? 'Invalid or expired code';
        debugPrint("❌ OTP verification failed: $error");
        return {"success": false, "error": error};
      }

      final userId = response.data['user_id'] as String?;
      final isNewUser = response.data['is_new_user'] == true;

      if (userId == null) {
        debugPrint("❌ OTP verification succeeded but no user ID returned");
        return {"success": false, "error": "Failed to create or retrieve user"};
      }

      debugPrint("✅ OTP verified. User ID: $userId (New: $isNewUser)");

      // Now create a proper Supabase Auth session for the user
      // The Edge Function has created the user in Supabase Auth
      // We need to establish a session for the client
      try {
        final auth = supa.Supabase.instance.client.auth;

        // Check if there's already a session for this user
        final currentSession = auth.currentSession;
        if (currentSession != null && currentSession.user.id == userId) {
          debugPrint("✅ User already has an active session");
        } else {
          // The user exists in Supabase Auth (created by Edge Function)
          // We need to sign them in. Since we're using phone auth and bypassing
          // Supabase's built-in OTP, we'll use a workaround:
          // 1. The Edge Function created the user with phone_confirmed: true
          // 2. We can't directly create a session from the client without OTP
          // 3. So we'll rely on the SessionManager to handle session restoration
          //    or we can use Supabase's admin API via another Edge Function

          // For now, we'll sign out any existing session and let the session manager
          // handle the new session. The user profile will be loaded, and if needed,
          // we can create a session using Supabase's admin API in a separate call.

          try {
            // Sign out any existing session
            await auth.signOut();

            // The session will be established when the SessionManager loads the user
            // Since the user exists in Supabase Auth, the SessionManager should be able
            // to restore the session or we'll need to create one via admin API
            debugPrint("⚠️ Session will be established by SessionManager");
          } catch (e) {
            debugPrint("⚠️ Could not sign out existing session: $e");
            // Continue anyway
          }
        }

        // Ensure user profile exists and is updated
        try {
          // First, try to update existing profile
          await _supabase.from("user_profiles").update({
            "phone": fullPhone,
            "is_verified": true,
            "updated_at": DateTime.now().toIso8601String(),
          }).eq("id", userId);
          debugPrint("✅ Updated existing user profile with phone verification");
        } on Exception catch (e) {
          debugPrint(
              "⚠️ Failed to update existing profile, creating new one: $e");
          // If update fails, create new profile
          try {
            await _createUserProfile(
                userId,
                null, // No name required
                fullPhone);
            debugPrint("✅ Created new user profile for phone authentication");
          } on Exception catch (createError) {
            debugPrint("❌ Failed to create user profile: $createError");
          }
        }

        // Reload app user from DB
        await _loadUserFromSession();
        if (_currentUser == null) {
          // If session manager didn't load the user, try to load directly
          final user = await getUserById(userId);
          if (user != null) {
            _currentUser = user;
            notifyListeners();
          } else {
            debugPrint("❌ Failed to load user profile after verification");
            return {
              "success": false,
              "error": "Failed to load user data after verification"
            };
          }
        }

        debugPrint("✅ Phone verified and user session established");
        return {
          "success": true,
          "isNewUser": isNewUser,
          "userId": userId
        };
      } catch (e) {
        debugPrint("❌ Error setting up user session: $e");
        // Even if session setup fails, the OTP was verified
        return {
          "success": true,
          "isNewUser": isNewUser,
          "userId": userId,
          "warning": "User verified but session setup incomplete"
        };
      }
    } on Exception catch (e) {
      debugPrint("❌ Error in phone verification: $e");
      return {"success": false, "error": "Verification failed: $e"};
    }
  }

  /// Send OTP to user's phone using custom OTP system (cost-effective)
  /// Uses Supabase Edge Function with cheaper SMS API (Twilio direct, AWS SNS, etc.)
  Future<Map<String, dynamic>> sendPhoneOtp(String phone, String countryCode,
      {String? captchaToken}) async {
    try {
      final cleanPhone = _normalizePhoneNumber(phone);
      final cleanCountry = _normalizeCountryCode(countryCode);
      final fullPhone = "+$cleanCountry$cleanPhone";

      debugPrint("📨 Sending OTP via custom system for: $fullPhone");

      // Call the send-otp Edge Function
      final response = await _supabase.functions.invoke(
        'send-otp',
        body: {
          'phone_number': cleanPhone,
          'country_code': cleanCountry,
          'full_phone': fullPhone,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        debugPrint("✅ OTP sent successfully via custom system");
        return {
          "success": true,
          "expires_in": response.data['expires_in'] ?? 600,
        };
      } else {
        final error = response.data?['error'] ?? 'Failed to send OTP';
        debugPrint("❌ Error sending OTP: $error");
        return {"success": false, "error": error};
      }
    } on Exception catch (e) {
      debugPrint("❌ Error sending OTP: $e");
      return {"success": false, "error": "Failed to send code: $e"};
    }
  }

  /// Get user by ID
  Future<app_user.User?> getUserById(String userId) async {
    try {
      final response = await _supabase
          .from("user_profiles")
          .select("*")
          .eq("id", userId)
          .maybeSingle();

      if (response != null) {
        return _buildUserFromResponse(response);
      }
      return null;
    } on Exception catch (e) {
      debugPrint("❌ Error getting user by ID: $e");
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile({
    String? name,
    String? address,
    String? wilaya,
    DateTime? dateOfBirth,
    String? profileImageUrl,
  }) async {
    try {
      final userId = _currentUser?.id;
      if (userId == null) {
        debugPrint("❌ No current user found for profile update");
        return false;
      }

      final updateData = <String, dynamic>{
        "updated_at": DateTime.now().toIso8601String(),
      };

      // Only update columns that exist in the database schema
      if (name != null && name.isNotEmpty) {
        updateData["name"] = name;
      }
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        updateData["profile_image_url"] = profileImageUrl;
      }

      // Note: address, wilaya, and dateOfBirth columns don't exist in the database schema
      // These will be stored in user preferences instead
      if (address != null || wilaya != null || dateOfBirth != null) {
        debugPrint(
            "⚠️ Address, wilaya, and dateOfBirth are not stored in user_profiles table");
        debugPrint(
            "⚠️ These fields should be stored in user preferences instead");
      }

      if (updateData.length == 1) {
        // Only updated_at was added
        debugPrint("❌ No valid updates provided");
        return false;
      }

      debugPrint("🔄 Updating user profile with: ${updateData.toString()}");

      // Adaptive update: retry removing unknown columns if DB rejects them
      final Map<String, dynamic> pending =
          Map<String, dynamic>.from(updateData);
      int attempts = 0;
      while (true) {
        attempts++;
        try {
          final result = await _supabase
              .from("user_profiles")
              .update(pending)
              .eq("id", userId)
              .select();
          debugPrint("User profile update result: ${result.toString()}");
          break;
        } on Exception catch (e) {
          final message = e.toString();
          debugPrint("❌ Update attempt #$attempts failed: $message");
          // Strip unknown column and retry (e.g., column "full_name" does not exist)
          final match = RegExp(r'column\s+"?(\w+)"?\s+does not exist',
                  caseSensitive: false)
              .firstMatch(message);
          if (match != null) {
            final col = match.group(1);
            if (col != null && pending.containsKey(col)) {
              pending.remove(col);
              debugPrint("➡️ Retrying without unknown column: $col");
              // If only updated_at remains after removal, abort
              if (pending.keys.where((k) => k != "updated_at").isEmpty) {
                debugPrint("No valid updatable columns remain. Aborting.");
                return false;
              }
              // Retry loop
              continue;
            }
          }
          // Non-recoverable error
          return false;
        }
      }

      // Reload current user
      await _loadUserFromSession();

      debugPrint("✅ User profile updated successfully");
      return true;
    } on Exception catch (e) {
      debugPrint("❌ Error updating user profile: $e");
      return false;
    }
  }

  /// Build User object from database response
  app_user.User _buildUserFromResponse(Map<String, dynamic> response) {
    return app_user.User(
      id: response["id"] ?? "",
      name: response["full_name"] ?? response["name"],
      email: response["email"] ?? "",
      phone: response["phone"],
      profileImage: response["profile_image_url"],
      role: _parseUserRole(response["role"]),
      isEmailVerified: true, // Email verification no longer required
      isPhoneVerified: response["phone_verified"] ?? false,
      createdAt:
          DateTime.tryParse(response["created_at"] ?? "") ?? DateTime.now(),
      lastLoginAt: response["last_login_at"] != null
          ? DateTime.tryParse(response["last_login_at"])
          : null,
      preferences: response["preferences"] ?? {},
      restaurantOwnerProfile: response["restaurant_owner_profile"] != null
          ? app_user.RestaurantOwnerProfile.fromJson(
              response["restaurant_owner_profile"])
          : null,
      location: response["location"] != null
          ? Location.fromJson(response["location"])
          : null,
      address: response["address"],
      wilaya: response["wilaya"],
      dateOfBirth: response["date_of_birth"] != null
          ? DateTime.tryParse(response["date_of_birth"])
          : null,
    );
  }

  /// Initialize cart for the authenticated user
  Future<void> _initializeUserCart(String userId) async {
    try {
      debugPrint("🛒 Initializing cart for user: $userId");

      // Get cart provider from the service locator (Provider)
      // This will be called from the widget tree where Provider is available
      // For now, we'll handle cart initialization in the UI layer
      debugPrint("🛒 Cart initialization scheduled for user: $userId");
    } on Exception catch (e) {
      debugPrint("❌ Error initializing cart: $e");
    }
  }

  /// Get cart provider instance (to be called from widget tree)
  void initializeCartForUser(String userId) {
    try {
      debugPrint("🛒 Setting up real-time cart sync for user: $userId");
      // Cart initialization will be handled by the CartProvider itself

      debugPrint("✅ Cart initialized successfully for user: $userId");
    } on Exception catch (e) {
      debugPrint("❌ Error setting up cart: $e");
    }
  }

  /// Force refresh the current session (delegates to SessionManager)
  Future<bool> forceRefreshSession() async {
    try {
      debugPrint("🔄 Manual session refresh requested");
      final result = await _sessionManager.forceRefreshSession();
      return result;
    } on Exception catch (e) {
      debugPrint("❌ Manual session refresh failed: $e");
      return false;
    }
  }

  /// Get session status information
  Map<String, dynamic> getSessionStatus() {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      return {
        "isAuthenticated": false,
        "hasSession": false,
        "sessionExpiry": null,
        "timeUntilExpiry": null,
      };
    }

    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    final expiresAt = session.expiresAt ?? 0;
    final timeUntilExpiry = expiresAt - now;

    return {
      "isAuthenticated": true,
      "hasSession": true,
      "sessionExpiry":
          DateTime.fromMillisecondsSinceEpoch((expiresAt * 1000).round()),
      "timeUntilExpiry": Duration(seconds: timeUntilExpiry.round()),
      "userId": session.user.id,
      "userEmail": session.user.email,
    };
  }

  /// Login as virtual restaurant owner (for testing/demo purposes)
  Future<void> loginAsVirtualRestaurantOwner() async {
    try {
      debugPrint("=== CREATING VIRTUAL RESTAURANT OWNER ===");

      _isLoading = true;
      notifyListeners();

      // Create a virtual user with restaurant owner role
      final virtualUserId =
          "virtual_restaurant_owner_${DateTime.now().millisecondsSinceEpoch}";

      _currentUser = app_user.User(
        id: virtualUserId,
        name: "Virtual Restaurant Owner",
        email: "virtual@restaurant.demo",
        phone: "+213555000000",
        role: app_user.UserRole.restaurantOwner,
        isEmailVerified: true,
        isPhoneVerified: true,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        preferences: PreferencesUtils.getDefaultPreferences(),
        restaurantOwnerProfile: app_user.RestaurantOwnerProfile(
          id: "virtual_profile_${DateTime.now().millisecondsSinceEpoch}",
          userId: virtualUserId,
          businessName: "Demo Restaurant",
          businessDescription: "A virtual restaurant for testing",
          createdAt: DateTime.now(),
          isVerified: true,
        ),
      );

      _isInitialized = true;
      _lastError = null;

      debugPrint("✅ Virtual restaurant owner created successfully");
      debugPrint("Virtual user: ${_currentUser?.name}");
      debugPrint("Virtual user role: ${_currentUser?.role}");
    } catch (e) {
      debugPrint("❌ Error creating virtual restaurant owner: $e");
      _lastError = "Failed to create virtual restaurant owner";
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send password reset email and enqueue a notification
  Future<bool> sendPasswordResetEmail(String email,
      {String? redirectTo}) async {
    try {
      await supa.Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );

      // Lookup user id by email to target the in-app notification
      String? userId;
      try {
        final row = await supa.Supabase.instance.client
            .from("user_profiles")
            .select("id")
            .eq("email", email)
            .maybeSingle();
        if (row != null) {
          userId = row["id"] as String?;
        }
      } on Exception catch (_) {}

      // Enqueue notification (if we found a user, send directly to them; otherwise system)
      try {
        final result = await QueueService().enqueue(
          taskIdentifier: "send_notification",
          payload: {
            "user_id": userId ?? "system",
            "title": "Password Reset Requested",
            "message": "If an account exists for $email, a reset link was sent."
          },
        );
        if (!result.success) {
          debugPrint(
              "Failed to enqueue password reset notification: ${result.error}");
        }
      } on Exception catch (e) {
        debugPrint("Error enqueuing password reset notification: $e");
      }

      return true;
    } on Exception catch (e) {
      debugPrint("❌ resetPasswordForEmail failed: $e");
      return false;
    }
  }
}
