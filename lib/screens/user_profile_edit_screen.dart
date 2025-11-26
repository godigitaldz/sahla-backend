import "dart:async";
import "dart:io";

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:provider/provider.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:url_launcher/url_launcher.dart";

import "../home_screen.dart";
import "../l10n/app_localizations.dart";
import "../services/auth_service.dart";
import "../services/image_picker_service.dart";
import "../services/transition_service.dart";
import "../utils/performance_utils.dart";
import "../utils/preferences_utils.dart";
import "../widgets/home_screen/home_layout_helper.dart";
import "become_delivery_man_screen.dart";
import "become_restaurant_owner_screen.dart";
import "phone_auth_screen.dart";

/// Profile edit constants for maintainability
class ProfileEditConstants {
  static const double avatarRadius = 50;
  static const double cameraIconSize = 14;
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 16);
  static const Duration saveButtonAnimationDuration =
      Duration(milliseconds: 300);

  static const Map<String, dynamic> fieldValidators = {
    "name": {"minLength": 2, "maxLength": 100},
    "phone": {"pattern": r"^\+?[1-9]\d{1,14}$"},
  };

  static const String profileImageField =
      "profile_image_url"; // Standardized field name
}

/// Enhanced auto-save service with database sync
class ProfileAutoSaveService {
  static const Duration autoSaveDelay = Duration(milliseconds: 1000);
  static Timer? _autoSaveTimer;
  static final Map<String, dynamic> _pendingChanges = {};
  static bool _isSaving = false;

  static void queueSave(String field, value) {
    _pendingChanges[field] = value;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(autoSaveDelay, _executeSave);
  }

  static Future<void> _executeSave() async {
    if (_pendingChanges.isEmpty || _isSaving) {
      return;
    }

    _isSaving = true;
    try {
      final authService =
          AuthService(); // Would need to get from context in real implementation
      final userId = authService.currentUser?.id;

      if (userId != null) {
        final supabase = Supabase.instance.client;
        await supabase
            .from("user_profiles")
            .update(_pendingChanges)
            .eq("id", userId);

        _pendingChanges.clear();
        debugPrint(
            "✅ Autosave successful: ${_pendingChanges.length} fields saved");
      }
    } on Exception catch (e) {
      debugPrint("❌ Autosave failed: $e");
      // Queue for retry with exponential backoff
      _autoSaveTimer = Timer(autoSaveDelay * 2, _executeSave);
    } finally {
      _isSaving = false;
    }
  }

  static void dispose() {
    _autoSaveTimer?.cancel();
    _pendingChanges.clear();
  }
}

/// Data validation service for profile fields
class ProfileDataValidator {
  static String? validateName(String? value, AppLocalizations? l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n?.fullNameRequired ?? "Full name is required";
    }
    if (value.trim().length < 2) {
      return l10n?.nameMinLength ?? "Name must be at least 2 characters";
    }
    if (value.trim().length > 100) {
      return "Name must be less than 100 characters";
    }
    return null;
  }

  static String? validateDateOfBirth(DateTime? date) {
    if (date == null) {
      return null;
    }

    final now = DateTime.now();
    final minAge =
        DateTime(now.year - 150, now.month, now.day); // 150 years max
    final maxAge = DateTime(now.year - 13, now.month, now.day); // 13 years min

    if (date.isBefore(minAge)) {
      return "Please enter a valid date of birth";
    }
    if (date.isAfter(maxAge)) {
      return "You must be at least 13 years old";
    }
    return null;
  }

  static bool isValidPhone(String phone) {
    final regex = RegExp(r"^\+?[1-9]\d{1,14}$"); // E.164 format
    return regex.hasMatch(phone);
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is optional
    }
    if (!isValidPhone(value)) {
      return "Please enter a valid phone number";
    }
    return null;
  }
}

/// Enhanced image upload service with schema compliance
class ProfileImageService {
  static const String profileImageField =
      ProfileEditConstants.profileImageField;

  static Future<Map<String, dynamic>> uploadProfileImage({
    required File image,
    required String userId,
    String? existingImageUrl,
  }) async {
    try {
      debugPrint("📤 ProfileImageService: Starting upload for user: $userId");
      // Validate image
      debugPrint("📤 ProfileImageService: Validating image...");
      if (!await _validateImage(image)) {
        debugPrint("❌ ProfileImageService: Image validation failed");
        return {"success": false, "error": "Invalid image file"};
      }
      debugPrint("✅ ProfileImageService: Image validation passed");

      // Generate unique filename
      // Path format must match RLS policy: {userId}/filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = image.path.split(".").last.toLowerCase();
      final fileName = "$timestamp.$extension";
      final filePath = "$userId/$fileName";

      // Map extension to correct MIME type (jpg -> jpeg)
      final mimeType = extension == 'jpg' ? 'jpeg' : extension;

      debugPrint("📤 ProfileImageService: Generated filename: $fileName");
      debugPrint("📤 ProfileImageService: File path: $filePath");
      debugPrint("📤 ProfileImageService: MIME type: image/$mimeType");

      // Upload to Supabase Storage
      debugPrint("📤 ProfileImageService: Starting Supabase storage upload...");
      final supabase = Supabase.instance.client;

      // Verify user is authenticated
      final currentUser = supabase.auth.currentUser;
      debugPrint(
          "📤 ProfileImageService: Current auth user: ${currentUser?.id ?? 'null'}");
      if (currentUser == null || currentUser.id != userId) {
        debugPrint(
            "❌ ProfileImageService: User authentication mismatch or not authenticated");
        return {"success": false, "error": "User not authenticated"};
      }

      // Read file as bytes for upload
      debugPrint("📤 ProfileImageService: Reading image file as bytes...");
      final fileBytes = await image.readAsBytes();
      debugPrint(
          "📤 ProfileImageService: File size: ${fileBytes.length} bytes");

      final uploadStartTime = DateTime.now();
      debugPrint(
          "📤 ProfileImageService: Uploading to storage bucket 'profile-images' with path '$filePath'...");

      await supabase.storage.from("profile-images").uploadBinary(
            filePath,
            fileBytes,
            fileOptions: FileOptions(
              upsert: true,
              cacheControl: "3600",
              contentType: 'image/$mimeType',
            ),
          );

      final uploadEndTime = DateTime.now();
      final uploadDuration = uploadEndTime.difference(uploadStartTime);
      debugPrint(
          "✅ ProfileImageService: Storage upload completed in ${uploadDuration.inSeconds}s");

      // Get public URL
      debugPrint("📤 ProfileImageService: Getting public URL...");
      final imageUrl =
          supabase.storage.from("profile-images").getPublicUrl(filePath);
      debugPrint("📤 ProfileImageService: Public URL: $imageUrl");

      // Update user_profiles table
      // Update both profile_image and profile_image_url for backward compatibility
      debugPrint("📤 ProfileImageService: Updating user_profiles table...");
      try {
        await supabase.from("user_profiles").update({
          "profile_image": imageUrl, // Legacy field (used by User model)
          profileImageField: imageUrl, // Standardized field (profile_image_url)
          "profile_image_updated_at": DateTime.now().toIso8601String(),
        }).eq("id", userId);
        debugPrint("✅ ProfileImageService: Database update successful");
      } catch (e) {
        debugPrint("❌ ProfileImageService: Database update failed: $e");
        return {"success": false, "error": "Database update failed: $e"};
      }

      // Delete old image if exists
      if (existingImageUrl != null) {
        debugPrint(
            "📤 ProfileImageService: Deleting old image: $existingImageUrl");
        await _deleteOldImage(existingImageUrl);
        debugPrint("✅ ProfileImageService: Old image deleted");
      }

      debugPrint("✅ ProfileImageService: Upload completed successfully");
      return {"success": true, "url": imageUrl};
    } on Exception catch (e) {
      debugPrint("❌ ProfileImageService: Exception occurred: $e");
      debugPrint("❌ ProfileImageService: Stack trace: ${StackTrace.current}");
      return {"success": false, "error": e.toString()};
    }
  }

  static Future<bool> _validateImage(File image) async {
    try {
      // Use a different approach to validate image size without async dart:io
      final bytes = await image.readAsBytes();
      return bytes.length <= 5 * 1024 * 1024; // 5MB limit
    } on Exception {
      return false;
    }
  }

  static Future<void> _deleteOldImage(String imageUrl) async {
    try {
      // Extract filename from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 2) {
        final bucket = pathSegments[0];
        final fileName = pathSegments.sublist(1).join("/");
        await Supabase.instance.client.storage.from(bucket).remove([fileName]);
      }
    } on Exception catch (e) {
      debugPrint("❌ Error deleting old image: $e");
    }
  }
}

/// Enhanced realtime service for profile updates
class ProfileRealtimeService {
  static RealtimeChannel? _channel;
  static String? _currentUserId;

  static void subscribeToProfileUpdates(
      String userId, Function(Map<String, dynamic>) onUpdate) {
    if (_currentUserId == userId && _channel != null) {
      return;
    }

    _currentUserId = userId;
    _channel?.unsubscribe();

    final supabase = Supabase.instance.client;
    _channel = supabase.channel("user_profile:$userId").onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: "public",
          table: "user_profiles",
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: "id",
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              onUpdate(Map<String, dynamic>.from(newRecord));
            }
          },
        )..subscribe();
  }

  static void dispose() {
    _channel?.unsubscribe();
    _channel = null;
    _currentUserId = null;
  }
}

class UserProfileEditScreen extends StatefulWidget {
  const UserProfileEditScreen({
    super.key,
    this.isNewUser = false,
  });

  final bool isNewUser;

  @override
  State<UserProfileEditScreen> createState() => _UserProfileEditScreenState();
}

class _UserProfileEditScreenState extends State<UserProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _emailFocusNode = FocusNode();

  // Performance optimized state management
  bool _isLoading = true; // Start with loading state
  bool _isSaving = false;
  bool _isInitialized = false;
  DateTime? _dateOfBirth;
  String? _cachedProfileImage;

  // Original values for change detection
  String? _originalName;
  DateTime? _originalDateOfBirth;

  // Optimized realtime + autosave
  RealtimeChannel? _profileChannel;
  Timer? _debounceTimer;
  Timer? _performanceTimer;
  static const Duration _performanceCheckInterval = Duration(seconds: 30);
  bool _isApplyingRemoteUpdate = false;
  // Debounced handlers for button taps
  late final Function _debouncedLogout;
  late final Function _debouncedSave;

  // Performance tracking
  int _rebuildCount = 0;
  DateTime _lastPerformanceCheck = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Initialize debounced handlers once
    _debouncedLogout = PerformanceUtils.debounce(
        _showLogoutDialog, const Duration(milliseconds: 300));
    _debouncedSave = PerformanceUtils.debounce(
        _saveProfile, const Duration(milliseconds: 300));

    if (widget.isNewUser) {
      debugPrint("👤 New user detected - showing profile completion flow");
    }

    // Add listeners to text controllers for immediate change detection
    _nameController.addListener(_onFieldChanged);
    _dateOfBirthController.addListener(_onFieldChanged);

    // Optimize initialization - batch operations and reduce async gaps
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  /// Optimized initialization with batched operations
  void _initializeScreen() {
    if (!mounted) {
      return;
    }

    try {
      // Step 1: Restore user state first (fastest operation)
      _restoreUserState();

      // Step 2: Load user data with enhanced error handling
      _loadUserData();

      // Step 3: Subscribe to realtime updates (last, non-blocking)
      _subscribeRealtimeProfile();

      // Step 4: Start performance monitoring
      _startPerformanceMonitoring();

      // Step 5: Mark as initialized
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("❌ Error initializing screen: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    // Clean up all resources
    _nameController.removeListener(_onFieldChanged);
    _dateOfBirthController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _emailController.dispose();
    _emailFocusNode.dispose();
    _phoneController.dispose();
    _dateOfBirthController.dispose();
    _debounceTimer?.cancel();
    _performanceTimer?.cancel();
    _profileChannel?.unsubscribe();

    // Log final performance metrics
    _logPerformanceMetrics();

    super.dispose();
  }

  /// Start performance monitoring
  void _startPerformanceMonitoring() {
    _performanceTimer = Timer.periodic(_performanceCheckInterval, (timer) {
      _checkPerformanceMetrics();
    });
  }

  /// Check and log performance metrics
  void _checkPerformanceMetrics() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastPerformanceCheck);

    if (elapsed.inSeconds >= 30) {
      debugPrint(
          "📊 Profile Edit Screen Performance: $_rebuildCount rebuilds in ${elapsed.inSeconds}s");
      _rebuildCount = 0;
      _lastPerformanceCheck = now;
    }
  }

  /// Log final performance metrics on dispose
  void _logPerformanceMetrics() {
    debugPrint(
        "📊 Profile Edit Screen Final Performance: $_rebuildCount total rebuilds");
  }

  /// Check if there are unsaved changes
  bool _hasChanges() {
    if (!_isInitialized) {
      return false;
    }

    // Check if name has changed
    final currentName = _nameController.text.trim();
    final originalName = _originalName ?? "";

    // Check if date of birth has changed
    final currentDateOfBirth = _dateOfBirth;
    final originalDateOfBirth = _originalDateOfBirth;

    // Check for changes
    final nameChanged = currentName != originalName;
    final dateChanged = currentDateOfBirth != originalDateOfBirth;

    final hasChanges = nameChanged || dateChanged;

    debugPrint(
        "🔍 Change detection: currentName=\"$currentName\", originalName=\"$originalName\", currentDate=$currentDateOfBirth, originalDate=$originalDateOfBirth, hasChanges=$hasChanges");

    return hasChanges;
  }

  /// Called when any field changes - triggers immediate UI update
  void _onFieldChanged() {
    if (mounted && _isInitialized) {
      // Only trigger rebuild if there are actual changes to avoid unnecessary rebuilds
      if (_hasChanges()) {
        setState(() {
          // This will trigger a rebuild and update the save button visibility
        });
      }
    }
  }

  /// Show logout confirmation dialog
  void _showLogoutDialog() {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) {
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            localizations.logout,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          content: Text(
            localizations.logoutConfirmation,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: Text(
                localizations.cancel,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Handle logout logic here - use context immediately after pop
                try {
                  await Supabase.instance.client.auth.signOut();
                  // Navigate to phone auth screen after logout
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    await Navigator.of(context).pushAndRemoveUntil(
                      TransitionService.fadeTransition(const PhoneAuthScreen()),
                      (route) => false,
                    );
                  }
                } on Exception catch (e) {
                  debugPrint("Error during logout: $e");
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Error: ${e.toString()}",
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(
                localizations.logout,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[600],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _restoreUserState() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.restoreUserState();

      if (mounted) {
        setState(() {});
      }
    } on Exception catch (e) {
      debugPrint("⚠️ Error restoring user state: $e");
    }
  }

  /// Optimized user data loading with caching
  void _loadUserData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      // Store original values for change detection
      _originalName = user.name ?? "";

      // Load date of birth from user preferences safely
      try {
        final DateTime? dob = PreferencesUtils.getDateTimePreference(
            user.preferences, "date_of_birth");
        if (dob != null) {
          _originalDateOfBirth = dob;
          _dateOfBirth = dob;
          _dateOfBirthController.text = _formatDate(dob);
        }
      } catch (e) {
        debugPrint("Error loading date of birth from preferences: $e");
      }

      // Batch text updates to reduce rebuilds
      final Map<String, String> updates = {};

      if (user.name != null && user.name != _nameController.text) {
        updates["name"] = user.name!;
      }

      if (user.email != _emailController.text) {
        updates["email"] = user.email;
      }

      if (user.phone != null && user.phone != _phoneController.text) {
        updates["phone"] = user.phone!;
      }

      // Apply all text updates at once
      if (updates.isNotEmpty) {
        _nameController.text = updates["name"] ?? _nameController.text;
        _emailController.text = updates["email"] ?? _emailController.text;
        _phoneController.text = updates["phone"] ?? _phoneController.text;
      }

      // Cache profile image URL to avoid repeated network calls (use standardized field)
      debugPrint(
          "🖼️ Load User Data: User profile image: ${user.profileImage}");
      debugPrint(
          "🖼️ Load User Data: Current cached image: $_cachedProfileImage");
      if (user.profileImage != null &&
          user.profileImage != _cachedProfileImage) {
        debugPrint(
            "🖼️ Load User Data: Updating cached image from $_cachedProfileImage to ${user.profileImage}");
        _cachedProfileImage = user.profileImage;
      } else {
        debugPrint("🖼️ Load User Data: No change to cached image");
      }
    }
  }

  /// Enhanced realtime subscription using ProfileRealtimeService
  void _subscribeRealtimeProfile() {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) {
        return;
      }

      ProfileRealtimeService.subscribeToProfileUpdates(
          userId, _applyRemoteProfileUpdate);
    } on Exception catch (e) {
      debugPrint("⚠️ Realtime profile subscribe error: $e");
    }
  }

  Future<void> _applyRemoteProfileUpdate(Map<String, dynamic> data) async {
    if (!mounted) {
      return;
    }
    _isApplyingRemoteUpdate = true;
    try {
      setState(() {
        final newName = (data["name"] ?? data["full_name"])?.toString();
        final newEmail = data["email"]?.toString();
        final newPhone = data["phone"]?.toString();
        // Check both profile_image_url and profile_image for backward compatibility
        final newProfileImage = (data[ProfileEditConstants.profileImageField] ??
                data["profile_image"])
            ?.toString();

        if (newName != null && newName != _nameController.text) {
          _nameController.text = newName;
          _originalName = newName; // Update original value
        }
        if (newEmail != null && newEmail != _emailController.text) {
          _emailController.text = newEmail;
        }
        if (newPhone != null && newPhone != _phoneController.text) {
          _phoneController.text = newPhone;
        }

        // Handle profile image updates
        if (newProfileImage != null && newProfileImage != _cachedProfileImage) {
          debugPrint(
              "🖼️ Realtime Update: Profile image updated from $_cachedProfileImage to $newProfileImage");
          _cachedProfileImage = newProfileImage;
        } else {
          debugPrint(
              "🖼️ Realtime Update: No profile image change (new: $newProfileImage, cached: $_cachedProfileImage)");
        }

        // Handle date of birth updates from preferences
        if (data["preferences"] != null &&
            data["preferences"] is Map &&
            data["preferences"]["date_of_birth"] != null) {
          try {
            final newDateOfBirth =
                DateTime.parse(data["preferences"]["date_of_birth"]);
            if (newDateOfBirth != _dateOfBirth) {
              _dateOfBirth = newDateOfBirth;
              _originalDateOfBirth = newDateOfBirth;
              _dateOfBirthController.text = _formatDate(newDateOfBirth);
            }
          } on FormatException catch (e) {
            debugPrint("Error parsing date of birth from remote update: $e");
          } on Exception catch (e) {
            debugPrint("Error handling date of birth from remote update: $e");
          }
        }
      });
      // Refresh global user
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.forceRefreshUserState();
      } on Exception catch (_) {}
    } finally {
      _isApplyingRemoteUpdate = false;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  /// Build right header buttons - Save/Undo when changes, Logout otherwise
  Widget _buildRightHeaderButtons() {
    if (!_isInitialized || _isLoading) {
      return const SizedBox.shrink();
    }

    if (_hasChanges()) {
      // Show Save and Undo buttons when there are changes
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Undo button
          IconButton(
            onPressed: _undoChanges,
            icon: const Icon(
              Icons.undo,
              color: Colors.black,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          // Save button - orange floating container with right icon (circle)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange[600],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _isSaving ? null : () => _debouncedSave(),
              padding: EdgeInsets.zero,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      );
    } else {
      // Show Logout button when no changes
      return IconButton(
        onPressed: () => _debouncedLogout(),
        icon: const Icon(
          Icons.logout,
          color: Colors.black,
          size: 20,
        ),
      );
    }
  }

  /// Undo changes - restore original values
  void _undoChanges() {
    if (!_isInitialized) return;

    setState(() {
      // Restore original name
      if (_originalName != null) {
        _nameController.text = _originalName!;
      }

      // Restore original date of birth
      if (_originalDateOfBirth != null) {
        _dateOfBirth = _originalDateOfBirth;
        _dateOfBirthController.text = _formatDate(_originalDateOfBirth!);
      } else {
        _dateOfBirth = null;
        _dateOfBirthController.clear();
      }
    });
  }

  /// Handle back button press - show confirmation if there are unsaved changes
  Future<void> _handleBackButton() async {
    if (widget.isNewUser) {
      return; // Don't allow back for new users
    }

    if (_hasChanges()) {
      // Show confirmation dialog
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              "Discard Changes?",
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            content: Text(
              "You have unsaved changes. Are you sure you want to discard them?",
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  AppLocalizations.of(context)?.cancel ?? "Cancel",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  "Discard",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[600],
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (shouldDiscard == true && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      // No changes, just navigate back
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Track rebuilds for performance monitoring
    if (_isInitialized) {
      _rebuildCount++;
    }

    return PerformanceUtils.measurePerformanceWidget(
        "UserProfileEditScreenBuild", () {
      // Use home screen's safe area logic
      final safeAreaTop = HomeLayoutHelper.getSafeAreaTop(context);
      final headerHorizontalPadding =
          HomeLayoutHelper.getHeaderHorizontalPadding(context);

      return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // White container wrapping status bar, header, and profile section
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status bar area
                    SizedBox(height: safeAreaTop),
                    // Header
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: headerHorizontalPadding,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back arrow icon
                          IconButton(
                            onPressed:
                                widget.isNewUser ? null : _handleBackButton,
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),

                          // Title
                          Text(
                            AppLocalizations.of(context)?.editProfile ??
                                "Edit Profile",
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),

                          // Right side buttons - Save/Undo when changes, Logout otherwise
                          _buildRightHeaderButtons(),
                        ],
                      ),
                    ),
                    // Profile Image Section
                    _buildProfileImageSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Main content - positioned below white container
            // Calculate white container height: safeAreaTop + header (64px) + profile section (~140px) + bottom spacing (20px)
            Positioned.fill(
              top: safeAreaTop +
                  64 +
                  140 +
                  20, // safeAreaTop + header + profile + spacing
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        physics: PerformanceUtils.optimizedScrollPhysics,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Personal Info Section - Optimized with proper keys
                            _buildPersonalInfoSection(),
                            const SizedBox(height: 24),
                            // Become Buttons Section - Only rebuild when user role changes
                            _buildBecomeButtonsSection(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildProfileImageSection() {
    debugPrint(
        "🖼️ Build Profile Image: Cached image URL: $_cachedProfileImage");
    return RepaintBoundary(
      child: Center(
        child: Column(
          children: [
            Stack(
              children: [
                // Use cached image URL to prevent unnecessary network calls
                CircleAvatar(
                  key: ValueKey(_cachedProfileImage),
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _cachedProfileImage != null
                      ? NetworkImage(_cachedProfileImage!)
                      : null,
                  child: _cachedProfileImage == null
                      ? Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.grey[600],
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFd47b00),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 14),
                      onPressed: _changeProfileImage,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)?.tapToChangePhoto ??
                  "Tap to change photo",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form fields
            _buildTextField(
              controller: _nameController,
              label: AppLocalizations.of(context)?.fullName ?? "Full Name",
              prefixIcon: Icons.person_outline,
              validator: (value) {
                final localizations = AppLocalizations.of(context);
                if (value == null || value.trim().isEmpty) {
                  return localizations?.fullNameRequired ??
                      "Full name is required";
                }
                if (value.trim().length < 2) {
                  return localizations?.nameMinLength ??
                      "Name must be at least 2 characters";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildDateOfBirthField(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label:
                  AppLocalizations.of(context)?.phoneNumber ?? "Phone Number",
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              enabled: false, // Phone is read-only
              validator: null,
            ),
            const SizedBox(height: 24),
            _buildPrivacyPolicyField(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    int? maxLines,
    bool enabled = true,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
    String? hintText,
  }) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label above the field
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          // Text field without label
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines ?? 1,
            enabled: enabled,
            onChanged: onChanged,
            validator: validator,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: enabled ? Colors.black : Colors.grey[600],
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey[500],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: Colors.grey[400]!, width: 2),
              ),
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey[50],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateOfBirthField() {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: _selectDateOfBirth,
        child: AbsorbPointer(
          child: _buildTextField(
            controller: _dateOfBirthController,
            label: AppLocalizations.of(context)?.dateOfBirth ?? "Date of Birth",
            prefixIcon: Icons.calendar_today,
            // Optional field: allow empty value
            validator: (value) => null,
            hintText: _dateOfBirth == null ? "Select date" : null,
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ??
          DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      firstDate: DateTime(1900),
      lastDate:
          DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
    );

    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
        _dateOfBirthController.text = _formatDate(picked);
      });
      // Trigger immediate UI update for save button
      _onFieldChanged();
    }
  }

  Widget _buildPrivacyPolicyField() {
    return RepaintBoundary(
      child: InkWell(
        onTap: _openPrivacyPolicy,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)?.privacyPolicy ?? "Privacy Policy",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      final url = Uri.parse("https://www.sahla-delivery.com/privacy-policy");
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint("Error opening privacy policy: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open privacy policy"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeProfileImage() async {
    try {
      debugPrint("🖼️ Profile Image Change: Starting image picker...");
      // Show image picker dialog
      final File? selectedImage = await ImagePickerService.pickImage(context);

      if (selectedImage != null) {
        debugPrint(
            "🖼️ Profile Image Change: Image selected: ${selectedImage.path}");
        // Validate image
        if (!ImagePickerService.validateImage(selectedImage)) {
          debugPrint("❌ Profile Image Change: Image validation failed");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)?.invalidImageError ??
                    "Invalid image. Please select a valid image under 5MB."),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        debugPrint("✅ Profile Image Change: Image validation passed");

        // Show loading indicator
        debugPrint("🖼️ Profile Image Change: Showing loading dialog...");
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );
          debugPrint("🖼️ Profile Image Change: Loading dialog shown");
        } else {
          debugPrint(
              "⚠️ Profile Image Change: Widget not mounted, cannot show dialog");
          return;
        }

        // Get current user
        debugPrint("🖼️ Profile Image Change: Getting current user...");
        if (!mounted) {
          debugPrint("⚠️ Profile Image Change: Widget not mounted, aborting");
          return;
        }
        final authService = Provider.of<AuthService>(context, listen: false);
        debugPrint("🖼️ Profile Image Change: AuthService retrieved");
        final user = authService.currentUser;
        debugPrint(
            "🖼️ Profile Image Change: User retrieved: ${user != null ? 'exists' : 'null'}");

        if (user != null) {
          debugPrint("🖼️ Profile Image Change: Current user ID: ${user.id}");
          debugPrint(
              "🖼️ Profile Image Change: Current profile image: ${user.profileImage}");
          // Upload image using enhanced ProfileImageService
          if (!mounted) {
            debugPrint(
                "⚠️ Profile Image Change: Widget not mounted before upload, aborting");
            return;
          }
          debugPrint("🖼️ Profile Image Change: Starting upload...");
          debugPrint(
              "🖼️ Profile Image Change: Image path: ${selectedImage.path}");
          debugPrint("🖼️ Profile Image Change: User ID: ${user.id}");
          debugPrint(
              "🖼️ Profile Image Change: Existing image URL: ${user.profileImage}");

          final uploadStartTime = DateTime.now();
          debugPrint(
              "🖼️ Profile Image Change: Upload started at: $uploadStartTime");

          final result = await ProfileImageService.uploadProfileImage(
            image: selectedImage,
            userId: user.id,
            existingImageUrl: user.profileImage,
          );

          final uploadEndTime = DateTime.now();
          final uploadDuration = uploadEndTime.difference(uploadStartTime);
          debugPrint(
              "🖼️ Profile Image Change: Upload completed at: $uploadEndTime");
          debugPrint(
              "🖼️ Profile Image Change: Upload duration: ${uploadDuration.inSeconds}s");
          debugPrint("🖼️ Profile Image Change: Upload result: $result");

          // Close loading dialog
          debugPrint("🖼️ Profile Image Change: Closing loading dialog...");
          if (mounted) {
            Navigator.of(context).pop();
            debugPrint("🖼️ Profile Image Change: Loading dialog closed");
          }

          if (result["success"] == true) {
            final newImageUrl = result["url"] as String;
            debugPrint("✅ Profile Image Change: Upload successful");
            debugPrint("🖼️ Profile Image Change: New image URL: $newImageUrl");

            // Update user profile with new image URL
            debugPrint("🖼️ Profile Image Change: Updating user profile...");
            final updateSuccess = await authService.updateUserProfile(
              name: user.name,
              profileImageUrl: newImageUrl,
            );
            debugPrint(
                "🖼️ Profile Image Change: Profile update result: $updateSuccess");

            // Force refresh user state to get updated profile image
            debugPrint(
                "🖼️ Profile Image Change: Force refreshing user state...");
            await authService.forceRefreshUserState();
            debugPrint("🖼️ Profile Image Change: User state refreshed");

            // Update cached image immediately for real-time UI update
            // Add cache-busting parameter to force image reload
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final imageUrlWithCacheBust = newImageUrl.contains('?')
                ? "$newImageUrl&t=$timestamp"
                : "$newImageUrl?t=$timestamp";

            debugPrint(
                "🖼️ Profile Image Change: Cache-busted URL: $imageUrlWithCacheBust");
            debugPrint(
                "🖼️ Profile Image Change: Previous cached image: $_cachedProfileImage");

            if (mounted) {
              debugPrint(
                  "🖼️ Profile Image Change: Calling setState to update UI...");
              setState(() {
                _cachedProfileImage = imageUrlWithCacheBust;
              });
              debugPrint("🖼️ Profile Image Change: setState completed");
              debugPrint(
                  "🖼️ Profile Image Change: New cached image: $_cachedProfileImage");
            } else {
              debugPrint(
                  "⚠️ Profile Image Change: Widget not mounted, cannot update state");
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      AppLocalizations.of(context)?.profileImageUpdated ??
                          "Profile image updated successfully!"),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            debugPrint(
                "❌ Profile Image Change: Upload failed: ${result["error"]}");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      "${AppLocalizations.of(context)?.imageUploadFailed ?? "Failed to upload image: {error}"}"
                          .replaceAll(
                              "{error}", (result["error"] ?? "").toString())),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          debugPrint("❌ Profile Image Change: User is null");
        }
      } else {
        debugPrint("🖼️ Profile Image Change: No image selected");
      }
    } on Exception catch (e) {
      debugPrint("❌ Profile Image Change: Exception occurred: $e");
      debugPrint("❌ Profile Image Change: Stack trace: ${StackTrace.current}");
      // Close loading dialog if open
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "${AppLocalizations.of(context)?.errorOccurred ?? "Error: {error}"}"
                    .replaceAll("{error}", e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    // Save method for bottom save button; no strict validators blocking save
    setState(() => _isSaving = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final name = _nameController.text.trim();

      debugPrint(
          "🔄 Saving profile with name: \"$name\" and dateOfBirth: $_dateOfBirth");

      // Update basic profile info (name only - dateOfBirth is stored in preferences)
      final success = await authService.updateUserProfile(
        name: name.isNotEmpty ? name : null,
        // Note: dateOfBirth is not stored in user_profiles table
        // It should be stored in user preferences instead
      );

      if (!success) {
        throw Exception("Failed to update profile in database");
      }

      // Store date of birth in user preferences if provided
      if (_dateOfBirth != null) {
        await _saveDateOfBirthToPreferences(_dateOfBirth!);
      }

      // Update original values after successful save
      _originalName = name;
      _originalDateOfBirth = _dateOfBirth;

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)?.profileUpdated ??
                "Profile updated successfully!")),
      );

      // For new users, navigate to home screen after saving
      if (widget.isNewUser) {
        await Navigator.of(context).pushAndRemoveUntil(
          TransitionService.slideFromRight(const HomeScreen()),
          (route) => false,
        );
      }
    } on Exception catch (e) {
      debugPrint("❌ Error saving profile: $e");
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "${AppLocalizations.of(context)?.profileUpdateError ?? "Error updating profile: {error}"}"
                    .replaceAll("{error}", e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Save date of birth to user preferences
  Future<void> _saveDateOfBirthToPreferences(DateTime dateOfBirth) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        // Update user preferences with date of birth
        final updatedPreferences = Map<String, dynamic>.from(user.preferences);
        updatedPreferences["date_of_birth"] = dateOfBirth.toIso8601String();

        // Update preferences in the database
        final supabase = Supabase.instance.client;
        await supabase
            .from("user_profiles")
            .update({"preferences": updatedPreferences}).eq("id", user.id);

        debugPrint(
            "📅 Date of birth saved to preferences: ${dateOfBirth.toIso8601String()}");
      }
    } on Exception catch (e) {
      debugPrint("❌ Error saving date of birth to preferences: $e");
    }
  }

  Widget _buildBecomeButtonsSection() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.currentUser;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Become Delivery Man button (only for non-delivery and non-restaurant users)
            if (user?.isDeliveryMan != true &&
                user?.isRestaurantOwner != true) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      TransitionService.navigateWithTransition(
                        context,
                        const BecomeDeliveryManScreen(),
                        transitionType: TransitionType.slideFromRight,
                      );
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)
                                        ?.becomeDeliveryMan ??
                                    "Become Delivery Man",
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Become Sahla Partner container (only for non-restaurant owners)
            if (user?.isRestaurantOwner != true) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      TransitionService.navigateWithTransition(
                        context,
                        const BecomeRestaurantOwnerScreen(),
                        transitionType: TransitionType.slideFromRight,
                      );
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)
                                        ?.becomeSahlaPartner ??
                                    "Become Sahla Partner",
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppLocalizations.of(context)?.growWithSahla ??
                                    "Grow with Sahla services",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
