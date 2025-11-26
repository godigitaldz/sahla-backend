import "package:flutter/foundation.dart";

import "../models/user.dart" as app_user;
import "../services/auth_service.dart";
import "../services/profile_service.dart";
import "../utils/preferences_utils.dart";

/// Enhanced Profile Provider with Real-time Updates
class ProfileProvider extends ChangeNotifier {
  ProfileProvider({
    ProfileService? profileService,
    AuthService? authService,
  })  : _profileService = profileService ?? ProfileService(),
        _authService = authService ?? AuthService();

  final ProfileService _profileService;
  final AuthService _authService;

  // Current user data
  app_user.User? _currentUser;
  Map<String, dynamic> _preferences = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  app_user.User? get currentUser => _currentUser;
  Map<String, dynamic> get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize the provider
  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Load current user from auth service
      _currentUser = _authService.currentUser;

      // Load user preferences
      await _loadPreferences();

      _isLoading = false;
      notifyListeners();
    } on Exception catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load user preferences
  Future<void> _loadPreferences() async {
    if (_currentUser != null) {
      try {
        final rawPreferences =
            await _profileService.getUserPreferences(_currentUser!.id);
        // Use PreferencesUtils to ensure we have valid preferences with defaults
        _preferences = PreferencesUtils.mergeWithDefaults(rawPreferences);
      } on Exception catch (e) {
        debugPrint("Error loading preferences: $e");
        // Use default preferences on error
        _preferences = PreferencesUtils.getDefaultPreferences();
      }
    } else {
      // No user logged in, use default preferences
      _preferences = PreferencesUtils.getDefaultPreferences();
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    if (_currentUser == null) {
      return false;
    }

    // Input validation: ensure required fields are present
    if (profileData.isEmpty) {
      debugPrint("⚠️ ProfileProvider: Empty profile data provided");
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final success = await _profileService.updateUserProfile(
        name: profileData["name"],
        address: profileData["address"],
        wilaya: profileData["wilaya"],
        dateOfBirth: profileData["dateOfBirth"],
        languagePreference: profileData["languagePreference"],
      );

      if (success) {
        // Reload user data
        _currentUser = _authService.currentUser;
        notifyListeners();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } on Exception catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update user language preference
  Future<bool> updateLanguagePreference(String languageCode) async {
    if (_currentUser == null) {
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final success =
          await _profileService.updateLanguagePreference(languageCode);

      if (success) {
        // Reload user data
        _currentUser = _authService.currentUser;
        notifyListeners();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } on Exception catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get user language preference
  Future<String?> getUserLanguagePreference() async {
    if (_currentUser == null) {
      return null;
    }
    return _profileService.getUserLanguagePreference();
  }

  // Update user preferences
  Future<bool> updateUserPreferences(Map<String, dynamic> preferences) async {
    if (_currentUser == null) {
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Validate and merge preferences with defaults using PreferencesUtils
      final validatedPreferences =
          PreferencesUtils.mergeWithDefaults(preferences);

      final success =
          await _profileService.updateUserPreferences(validatedPreferences);

      if (success) {
        // Update local preferences with validated data
        _preferences = PreferencesUtils.mergeWithDefaults(validatedPreferences);
        notifyListeners();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } on Exception catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    _currentUser = _authService.currentUser;
    await _loadPreferences();
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
