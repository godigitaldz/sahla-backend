import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:google_fonts/google_fonts.dart";
import "package:permission_handler/permission_handler.dart";

import "../home_screen.dart";
import "../l10n/app_localizations.dart";
import "../services/permission_flow_service.dart";

/// World-class permission screen with:
/// - Auto-skip when permissions already granted
/// - Optimized for low-end devices (minimal rebuilds, efficient state)
/// - Handles all scenarios (granted, denied, permanently denied, service off)
/// - Real-time permission status updates
/// - Stable error handling
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with SingleTickerProviderStateMixin {
  // Performance: Use separate state variables to minimize rebuilds
  bool _isInitializing = true;
  bool _requesting = false;
  bool _shouldNavigateToHome = false;

  // Permission status tracking (optimized for minimal rebuilds)
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  bool _locationServiceEnabled = true;
  bool _locationPermanentlyDenied = false;
  bool _notificationPermanentlyDenied = false;

  // Performance: Cache expensive calculations
  late bool _isArabic;

  // Animation controller for fade-in effect
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize fade animation controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Check permissions asynchronously without blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionsAndSkip();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Check permissions on init and skip if already granted
  Future<void> _checkPermissionsAndSkip() async {
    try {
      // Check if permissions are already granted
      final shouldShow = await PermissionFlowService.shouldShowPermissionsScreen();

      if (!shouldShow && mounted) {
        // All permissions granted, navigate immediately with fade transition
        debugPrint('✅ All permissions granted - navigating directly to home');

        // Small delay to ensure smooth fade transition
        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          _goHome();
        }
        return;
      }

      // Load current permission status
      await _loadPermissionStatus();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        // Start fade-in animation
        _fadeController.forward();
      }
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      // On error, show screen anyway
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        // Start fade-in animation even on error
        _fadeController.forward();
      }
    }
  }

  /// Load current permission status efficiently
  Future<void> _loadPermissionStatus() async {
    try {
      // Load status in parallel for better performance
      final results = await Future.wait([
        _getLocationStatus(),
        _getNotificationStatus(),
        Geolocator.isLocationServiceEnabled().catchError((_) => true),
      ]);

      if (mounted) {
        setState(() {
          _locationStatus = results[0] as PermissionStatus;
          _notificationStatus = results[1] as PermissionStatus;
          _locationServiceEnabled = results[2] as bool;
          _locationPermanentlyDenied = _locationStatus == PermissionStatus.permanentlyDenied;
          _notificationPermanentlyDenied = _notificationStatus == PermissionStatus.permanentlyDenied;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading permission status: $e');
    }
  }

  /// Get location permission status
  Future<PermissionStatus> _getLocationStatus() async {
    try {
      final permission = await Geolocator.checkPermission();

      // Convert Geolocator permission to PermissionStatus
      switch (permission) {
        case LocationPermission.denied:
          return PermissionStatus.denied;
        case LocationPermission.deniedForever:
          return PermissionStatus.permanentlyDenied;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return PermissionStatus.granted;
        case LocationPermission.unableToDetermine:
          return PermissionStatus.denied;
      }
    } catch (e) {
      debugPrint('❌ Error checking location permission: $e');
      // Fallback to permission_handler
      try {
        final status = await Permission.locationWhenInUse.status;
        return status;
      } catch (fallbackError) {
        debugPrint('❌ Fallback location permission check failed: $fallbackError');
        return PermissionStatus.denied;
      }
    }
  }

  /// Get notification permission status
  Future<PermissionStatus> _getNotificationStatus() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.getNotificationSettings();

        switch (settings.authorizationStatus) {
          case AuthorizationStatus.authorized:
          case AuthorizationStatus.provisional:
            return PermissionStatus.granted;
          case AuthorizationStatus.denied:
          case AuthorizationStatus.notDetermined:
            return PermissionStatus.denied;
        }
      } else {
        final status = await Permission.notification.status;
        return status;
      }
    } catch (e) {
      debugPrint('❌ Error checking notification permission: $e');
      // Fallback to permission_handler
      try {
        final status = await Permission.notification.status;
        return status;
      } catch (fallbackError) {
        debugPrint('❌ Fallback notification permission check failed: $fallbackError');
        return PermissionStatus.denied;
      }
    }
  }

  /// Request all permissions with proper error handling
  Future<void> _requestAll() async {
    if (_requesting) return;

    setState(() {
      _requesting = true;
    });

    try {
      // Request notification permission first
      await _requestNotificationPermission();

      // Small delay to avoid overwhelming the system
      await Future.delayed(const Duration(milliseconds: 300));

      // Request location permission after notification
      await _requestLocationPermission();

      // Reload status after requests
      await _loadPermissionStatus();

      // Check if all permissions are now granted
      final shouldShow = await PermissionFlowService.shouldShowPermissionsScreen();

      if (!shouldShow && mounted) {
        // All permissions granted, fade out and navigate to home
        await _fadeController.reverse();
        if (mounted) {
          _goHome();
        }
        return;
      }
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      // Reload status even on error
      await _loadPermissionStatus();
    } finally {
      if (mounted) {
        setState(() {
          _requesting = false;
        });
      }
    }
  }

  /// Request notification permission with proper iOS handling
  Future<bool> _requestNotificationPermission() async {
    try {
      debugPrint('🔔 Requesting notification permission...');

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final messaging = FirebaseMessaging.instance;
        final currentSettings = await messaging.getNotificationSettings();

        // If already authorized, return true
        if (currentSettings.authorizationStatus == AuthorizationStatus.authorized ||
            currentSettings.authorizationStatus == AuthorizationStatus.provisional) {
          debugPrint('🔔 Notification permission already granted');
          return true;
        }

        // Request permission
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

        if (mounted) {
          setState(() {
            _notificationStatus = granted ? PermissionStatus.granted : PermissionStatus.denied;
            _notificationPermanentlyDenied = settings.authorizationStatus == AuthorizationStatus.denied;
          });
        }

        return granted;
      } else {
        final currentStatus = await Permission.notification.status;

        // If already granted, return true
        if (currentStatus.isGranted) {
          debugPrint('🔔 Notification permission already granted');
          return true;
        }

        // If permanently denied, open settings
        if (currentStatus.isPermanentlyDenied) {
          debugPrint('🔔 Notification permission permanently denied');
          if (mounted) {
            await _showPermanentlyDeniedDialog(
              title: 'Notification Permission Required',
              message: 'Notification permission is permanently denied. Please enable it in app settings.',
              onOpenSettings: () => openAppSettings(),
            );
          }
          return false;
        }

        // Request permission
        final status = await Permission.notification.request();

        if (mounted) {
          setState(() {
            _notificationStatus = status;
            _notificationPermanentlyDenied = status.isPermanentlyDenied;
          });
        }

        return status.isGranted;
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  /// Request location permission with proper error handling
  Future<bool> _requestLocationPermission() async {
    try {
      debugPrint('📍 Requesting location permission...');

      // First check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (mounted) {
        setState(() {
          _locationServiceEnabled = serviceEnabled;
        });
      }

      if (!serviceEnabled) {
        debugPrint('📍 Location services are disabled');
        if (mounted) {
          await _showLocationServiceDialog();
        }
        return false;
      }

      // Check current permission status
      final currentPermission = await Geolocator.checkPermission();

      // If already granted, return true
      if (currentPermission == LocationPermission.whileInUse ||
          currentPermission == LocationPermission.always) {
        debugPrint('📍 Location permission already granted');
        if (mounted) {
          setState(() {
            _locationStatus = PermissionStatus.granted;
          });
        }
        return true;
      }

      // If permanently denied, open settings
      if (currentPermission == LocationPermission.deniedForever) {
        debugPrint('📍 Location permission permanently denied');
        if (mounted) {
          setState(() {
            _locationPermanentlyDenied = true;
            _locationStatus = PermissionStatus.permanentlyDenied;
          });
          await _showPermanentlyDeniedDialog(
            title: 'Location Permission Required',
            message: 'Location permission is permanently denied. Please enable it in app settings.',
            onOpenSettings: () => Geolocator.openAppSettings(),
          );
        }
        return false;
      }

      // Request permission
      final permission = await Geolocator.requestPermission();

      final granted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      if (mounted) {
        setState(() {
          _locationStatus = granted ? PermissionStatus.granted : PermissionStatus.denied;
          _locationPermanentlyDenied = permission == LocationPermission.deniedForever;
        });
      }

      // Verify location services are still enabled after permission grant
      if (granted) {
        final serviceStillEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceStillEnabled && mounted) {
          setState(() {
            _locationServiceEnabled = false;
          });
          await _showLocationServiceDialog();
        }
      }

      return granted;
    } catch (e) {
      debugPrint('❌ Error requesting location permission: $e');
      // Fallback to permission_handler
      try {
        final status = await Permission.locationWhenInUse.status;
        if (status.isGranted) {
          if (mounted) {
            setState(() {
              _locationStatus = PermissionStatus.granted;
            });
          }
          return true;
        }
        if (status.isPermanentlyDenied) {
          if (mounted) {
            setState(() {
              _locationPermanentlyDenied = true;
              _locationStatus = PermissionStatus.permanentlyDenied;
            });
            await openAppSettings();
          }
          return false;
        }
        final requestStatus = await Permission.locationWhenInUse.request();
        if (mounted) {
          setState(() {
            _locationStatus = requestStatus;
            _locationPermanentlyDenied = requestStatus.isPermanentlyDenied;
          });
        }
        return requestStatus.isGranted;
      } catch (fallbackError) {
        debugPrint('❌ Fallback location permission request failed: $fallbackError');
        return false;
      }
    }
  }

  /// Show dialog for permanently denied permission
  Future<void> _showPermanentlyDeniedDialog({
    required String title,
    required String message,
    required VoidCallback onOpenSettings,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onOpenSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to enable location services
  Future<void> _showLocationServiceDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Required'),
        content: const Text('Please enable location services to use this feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openLocationSettings();
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  /// Navigate to home screen with smooth fade transition
  void _goHome() {
    if (!mounted || _shouldNavigateToHome) return;

    _shouldNavigateToHome = true;

    // Use pushReplacement with smooth fade transition
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Smooth fade transition matching splash screen
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400), // Smooth fade
        reverseTransitionDuration: const Duration(milliseconds: 300),
        opaque: true, // Ensure opaque to prevent white flash
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache expensive calculations once
    _isArabic = Localizations.localeOf(context).languageCode == 'ar';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // Use gradient background instead of image to differentiate from splash screen
      backgroundColor: const Color(0xFFF8F9FA),
      body: Container(
        decoration: BoxDecoration(
          // Professional gradient background
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange[50]!,
              Colors.orange[100]!,
              Colors.white,
              Colors.orange[50]!,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _PermissionScreenPainter(),
              ),
            ),
            // Content container with fade animation
            Center(
              child: _isInitializing
                  ? const SizedBox.shrink() // No loading indicator
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildContent(l10n),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build main content with optimized rebuilds
  Widget _buildContent(AppLocalizations l10n) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon for visual appeal
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.orange[400]!,
                        Colors.orange[600]!,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.security,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.enablePermissions,
                  style: GoogleFonts.saira(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A1A1A),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.permissionsDescription,
                  style: GoogleFonts.roboto(
                    fontSize: _isArabic ? 14 : 15,
                    color: Colors.grey[700],
                    height: _isArabic ? 1.5 : 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: _isArabic ? 28 : 24),
                // Location permission tile with status
                _PermissionTile(
                  icon: Icons.location_on,
                  title: l10n.locationPermissionTitle,
                  subtitle: l10n.locationPermissionSubtitle,
                  status: _locationStatus,
                  isPermanentlyDenied: _locationPermanentlyDenied,
                  serviceEnabled: _locationServiceEnabled,
                  onRetry: _locationPermanentlyDenied || !_locationServiceEnabled
                      ? () async {
                          if (!_locationServiceEnabled) {
                            await Geolocator.openLocationSettings();
                          } else {
                            await Geolocator.openAppSettings();
                          }
                          // Reload status after returning from settings
                          await Future.delayed(const Duration(milliseconds: 500));
                          await _loadPermissionStatus();
                        }
                      : null,
                ),
                SizedBox(height: _isArabic ? 16 : 12),
                // Notification permission tile with status
                _PermissionTile(
                  icon: Icons.notifications_active,
                  title: l10n.notificationsPermissionTitle,
                  subtitle: l10n.notificationsPermissionSubtitle,
                  status: _notificationStatus,
                  isPermanentlyDenied: _notificationPermanentlyDenied,
                  serviceEnabled: true,
                  onRetry: _notificationPermanentlyDenied
                      ? () async {
                          await openAppSettings();
                          // Reload status after returning from settings
                          await Future.delayed(const Duration(milliseconds: 500));
                          await _loadPermissionStatus();
                        }
                      : null,
                ),
                const SizedBox(height: 24),
                // Request button
                FractionallySizedBox(
                  widthFactor: 0.75,
                  child: SizedBox(
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: ElevatedButton(
                        onPressed: _requesting ? null : _requestAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF424242),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: _requesting
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF424242),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.allowAll,
                                    style: GoogleFonts.roboto(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF424242),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                l10n.allowAll,
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF424242),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Skip button
                TextButton(
                  onPressed: _requesting ? null : _goHome,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    l10n.skipForNow,
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for permission screen background pattern
class _PermissionScreenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    // Draw subtle circles in the background
    // Top right circle
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.15),
      size.width * 0.3,
      paint,
    );

    // Bottom left circle
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.85),
      size.width * 0.25,
      paint,
    );

    // Center circle (very subtle)
    paint.color = Colors.orange.withValues(alpha: 0.02);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.2,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Permission tile with status indicator and retry functionality
class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.isPermanentlyDenied,
    required this.serviceEnabled,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final PermissionStatus status;
  final bool isPermanentlyDenied;
  final bool serviceEnabled;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isGranted = status.isGranted && serviceEnabled;
    final showRetry = (isPermanentlyDenied || !serviceEnabled) && onRetry != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isGranted ? Colors.green : Colors.orange[600],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isGranted ? Icons.check : icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.roboto(
                          fontSize: isArabic ? 13 : 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          height: isArabic ? 1.3 : 1.2,
                        ),
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      ),
                    ),
                    if (isGranted)
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 18,
                      )
                    else if (showRetry)
                      IconButton(
                        icon: const Icon(Icons.settings, size: 18),
                        color: Colors.orange[600],
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onRetry,
                        tooltip: 'Open Settings',
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.roboto(
                    fontSize: isArabic ? 11 : 12,
                    color: Colors.black,
                    height: isArabic ? 1.4 : 1.2,
                  ),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                ),
                if (showRetry) ...[
                  const SizedBox(height: 4),
                  Text(
                    !serviceEnabled
                        ? 'Location services are disabled'
                        : 'Permission permanently denied. Tap settings icon to enable.',
                    style: GoogleFonts.roboto(
                      fontSize: 10,
                      color: Colors.red[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
