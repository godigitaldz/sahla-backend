import "dart:async";

import "package:flutter/foundation.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../models/user.dart" as app_user;
import "../utils/preferences_utils.dart";
import "auth_service.dart";

/// Enhanced Profile Service with Real-time Updates
class ProfileService extends ChangeNotifier {
  static final ProfileService _instance = ProfileService._internal();

  factory ProfileService() => _instance;

  ProfileService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  // Real-time subscriptions
  RealtimeChannel? _profileChannel;

  // Stream controllers for real-time updates
  final StreamController<app_user.User> _profileUpdateController =
      StreamController<app_user.User>.broadcast();
  final StreamController<Map<String, dynamic>> _preferencesUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<app_user.User> get profileUpdateStream =>
      _profileUpdateController.stream;
  Stream<Map<String, dynamic>> get preferencesUpdateStream =>
      _preferencesUpdateController.stream;

  // Cache for performance
  final Map<String, app_user.User> _userCache = {};

  // Current user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Initialize real-time subscriptions
  Future<void> initializeRealtimeSubscriptions(String userId) async {
    try {
      debugPrint(
          "🔄 Initializing profile real-time subscriptions for user: $userId");

      await _setupProfileRealtimeSubscription(userId);

      debugPrint(
          "✅ Profile real-time subscriptions initialized for user: $userId");
    } on Exception catch (e) {
      debugPrint("❌ Error initializing profile real-time subscriptions: $e");
    }
  }

  /// Setup real-time subscription for profile changes
  Future<void> _setupProfileRealtimeSubscription(String userId) async {
    try {
      // Clean up existing channel
      await _profileChannel?.unsubscribe();

      // Create new channel for profile updates
      _profileChannel = _supabase
          .channel("profile_$userId")
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: "public",
            table: "user_profiles",
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: "id",
              value: userId,
            ),
            callback: (payload) => _handleProfileUpdate(payload, userId),
          )
          .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint(
              "✅ Profile real-time subscription active for user: $userId");
        } else {
          debugPrint(
              "✅ Profile real-time subscription active for user: $userId");
        }
      });
    } on Exception catch (e) {
      debugPrint("❌ Error setting up profile real-time subscription: $e");
    }
  }

  /// Handle profile updates from real-time subscription
  void _handleProfileUpdate(PostgresChangePayload payload, String userId) {
    try {
      debugPrint("🔄 Profile update received for user: $userId");

      // Invalidate user cache
      _userCache.remove(userId);

      // Fetch updated profile
      _fetchAndNotifyProfileUpdate(userId);
    } on Exception catch (e) {
      debugPrint("❌ Error handling profile update: $e");
    }
  }

  /// Fetch and notify profile update
  Future<void> _fetchAndNotifyProfileUpdate(String userId) async {
    try {
      final authService = AuthService();
      final user = await authService.getUserById(userId);

      if (user != null) {
        // Update cache
        _userCache[userId] = user;

        // Notify listeners
        _profileUpdateController.add(user);
        notifyListeners();

        debugPrint("✅ Profile update propagated for user: $userId");
      }
    } on Exception catch (e) {
      debugPrint("❌ Error fetching profile update: $e");
    }
  }

  /// Get current user profile with real-time updates
  Future<app_user.User?> getCurrentUserProfile(
      {bool forceRefresh = false}) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return null;
      }

      // Check cache first (unless force refresh)
      if (!forceRefresh && _userCache.containsKey(userId)) {
        return _userCache[userId];
      }

      final authService = AuthService();
      final user = await authService.getUserById(userId);

      if (user != null) {
        // Update cache
        _userCache[userId] = user;
      }

      return user;
    } on Exception catch (e) {
      debugPrint("❌ Error getting current user profile: $e");
      return null;
    }
  }

  /// Update user profile with real-time notification
  Future<bool> updateUserProfile({
    String? name,
    String? address,
    String? wilaya,
    DateTime? dateOfBirth,
    String? languagePreference,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return false;
      }

      final updateData = <String, dynamic>{
        "updated_at": DateTime.now().toIso8601String(),
      };

      if (name != null) {
        updateData["name"] = name;
      }
      if (address != null) {
        updateData["address"] = address;
      }
      if (wilaya != null) {
        updateData["wilaya"] = wilaya;
      }
      if (dateOfBirth != null) {
        updateData["date_of_birth"] = dateOfBirth.toIso8601String();
      }
      if (languagePreference != null) {
        updateData["language_preference"] = languagePreference;
      }

      await _supabase.from("user_profiles").update(updateData).eq("id", userId);

      // Invalidate cache to force refresh
      _userCache.remove(userId);

      // Fetch and notify updated profile
      await _fetchAndNotifyProfileUpdate(userId);

      debugPrint("✅ Profile updated successfully for user: $userId");
      return true;
    } on Exception catch (e) {
      debugPrint("❌ Error updating profile: $e");
      return false;
    }
  }

  /// Update user language preference
  Future<bool> updateLanguagePreference(String languageCode) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return false;
      }

      // Validate language code
      const supportedLanguages = ["en", "ar", "fr"];
      if (!supportedLanguages.contains(languageCode)) {
        debugPrint("❌ Unsupported language code: $languageCode");
        return false;
      }

      await _supabase.from("user_profiles").update({
        "language_preference": languageCode,
        "updated_at": DateTime.now().toIso8601String(),
      }).eq("id", userId);

      // Invalidate cache to force refresh
      _userCache.remove(userId);

      // Fetch and notify updated profile
      await _fetchAndNotifyProfileUpdate(userId);

      debugPrint(
          "✅ Language preference updated successfully for user: $userId to $languageCode");
      return true;
    } on Exception catch (e) {
      debugPrint("❌ Error updating language preference: $e");
      return false;
    }
  }

  /// Get user language preference
  Future<String?> getUserLanguagePreference() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return null;
      }

      final response = await _supabase
          .from("user_profiles")
          .select("language_preference")
          .eq("id", userId)
          .single();

      return response["language_preference"] as String?;
    } catch (e) {
      // Check if it's a DNS/network error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('socketexception') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('nodename nor servname') ||
          errorString.contains('connection refused') ||
          errorString.contains('network is unreachable')) {
        debugPrint(
          "⚠️ Network/DNS error getting user language preference: $e\n"
          "💡 This is likely a simulator/emulator network issue. Troubleshooting:\n"
          "   - iOS Simulator: Settings > General > Reset > Reset Network Settings\n"
          "   - Android Emulator: Cold boot the emulator\n"
          "   - Try using a physical device instead\n"
          "   - Check your host machine's internet connection",
        );
      } else {
        debugPrint("❌ Error getting user language preference: $e");
      }
      return null;
    }
  }

  /// Update user preferences with real-time notification
  Future<bool> updateUserPreferences(Map<String, dynamic> preferences) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return false;
      }

      // Validate and merge preferences with defaults using PreferencesUtils
      final validatedPreferences =
          PreferencesUtils.mergeWithDefaults(preferences);

      // Validate preferences structure
      if (!PreferencesUtils.isValidPreferences(validatedPreferences)) {
        debugPrint("⚠️ Invalid preferences structure, using defaults");
        final defaultPrefs = PreferencesUtils.getDefaultPreferences();
        await _supabase.from("user_profiles").update({
          "preferences": defaultPrefs,
          "updated_at": DateTime.now().toIso8601String(),
        }).eq("id", userId);

        _preferencesUpdateController.add(defaultPrefs);
        notifyListeners();
        return true;
      }

      await _supabase.from("user_profiles").update({
        "preferences": validatedPreferences,
        "updated_at": DateTime.now().toIso8601String(),
      }).eq("id", userId);

      // Notify preferences update
      _preferencesUpdateController.add(validatedPreferences);
      notifyListeners();

      debugPrint("✅ User preferences updated successfully for user: $userId");
      return true;
    } on Exception catch (e) {
      debugPrint("❌ Error updating user preferences: $e");
      return false;
    }
  }

  /// Refresh all user data
  Future<void> refreshUserData(String userId) async {
    try {
      debugPrint("🔄 Refreshing all user data for: $userId");

      // Clear caches
      _userCache.remove(userId);

      // Fetch fresh data
      await _fetchAndNotifyProfileUpdate(userId);

      debugPrint("✅ User data refreshed for: $userId");
    } on Exception catch (e) {
      debugPrint("❌ Error refreshing user data: $e");
    }
  }

  /// Get user preferences
  Future<Map<String, dynamic>> getUserPreferences(String userId) async {
    try {
      final response = await _supabase
          .from("user_profiles")
          .select("preferences")
          .eq("id", userId)
          .single();

      // Use PreferencesUtils to safely handle preferences
      final rawPreferences = response["preferences"];
      return PreferencesUtils.mergeWithDefaults(rawPreferences);
    } on Exception catch (e) {
      debugPrint("❌ Error getting user preferences: $e");
      // Return default preferences on error
      return PreferencesUtils.getDefaultPreferences();
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _profileChannel?.unsubscribe();
    _profileUpdateController.close();
    _preferencesUpdateController.close();
    super.dispose();
  }
}
