import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'models/user.dart';
import 'providers/home_provider.dart';
import 'providers/location_provider.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/delivery_map_dashboard_screen.dart';
import 'screens/restaurant_dashboard_screen.dart';
import 'screens/user_profile_edit_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'utils/responsive_utils.dart';
import 'widgets/home_screen/language_switcher.dart';
import 'widgets/search_fab.dart';

/// HomeHeader renders the status-safe header row and a high-performance
/// stripe banner with centered text.
class HomeHeader extends StatefulWidget {
  final VoidCallback? onSearchTap;
  final double scrollOffset;
  final double maxScrollOffset;

  const HomeHeader({
    super.key,
    this.onSearchTap,
    this.scrollOffset = 0.0,
    this.maxScrollOffset = 100.0,
  });

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  @override
  void initState() {
    super.initState();
    // Initialize services
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize notification service
      final notificationService = context.read<NotificationService>();
      notificationService.initialize();

      // Initialize location quickly in background
      _initializeLocation();
    });
  }

  /// Initialize location detection in background
  Future<void> _initializeLocation() async {
    try {
      final locationProvider = context.read<LocationProvider>();
      // Try to get fast location without blocking UI
      await locationProvider.getFastLocation();
    } catch (e) {
      // Location initialization failed silently
      debugPrint('Location initialization failed: $e');
    }
  }

  /// Navigate based on user role
  void _navigateBasedOnRole() {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      // If no user, navigate to profile edit screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UserProfileEditScreen(),
        ),
      );
      return;
    }

    switch (currentUser.role) {
      case UserRole.customer:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UserProfileEditScreen(),
          ),
        );
        break;
      case UserRole.restaurantOwner:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RestaurantDashboardScreen(),
          ),
        );
        break;
      case UserRole.deliveryMan:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DeliveryMapDashboardScreen(),
          ),
        );
        break;
      case UserRole.admin:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminDashboardScreen(),
          ),
        );
        break;
    }
  }

  /// Build role-based image widget
  Widget _buildRoleBasedImage(User? currentUser) {
    if (currentUser == null) {
      return Icon(
        Icons.person_outline,
        size: 17.sp,
        color: const Color(0xFF424242), // Dark grey
      );
    }

    switch (currentUser.role) {
      case UserRole.customer:
        return _buildCustomerImage(currentUser);
      case UserRole.restaurantOwner:
        return _buildRestaurantImage(currentUser);
      case UserRole.deliveryMan:
        return _buildDeliveryManImage(currentUser);
      case UserRole.admin:
        return Icon(
          Icons.admin_panel_settings,
          size: 20.sp,
          color: const Color(0xFF424242), // Dark grey
        );
    }
  }

  /// Build customer image (profile image from user_profiles table)
  Widget _buildCustomerImage(User user) {
    // Use profile_image_url from user_profiles table
    if (user.profileImage != null && user.profileImage!.isNotEmpty) {
      return ClipRRect(
        borderRadius: context.responsiveBorderRadius(16),
        child: Image.network(
          user.profileImage!,
          width: 32.w,
          height: 32.h,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.person,
              size: 20.sp,
              color: const Color(0xFF424242), // Dark grey
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Icon(
              Icons.person,
              size: 20.sp,
              color: const Color(0xFF424242), // Dark grey
            );
          },
        ),
      );
    }

    // Fallback to default customer icon
    return Icon(
      Icons.person,
      size: 20.sp,
      color: const Color(0xFF424242), // Dark grey
    );
  }

  /// Build restaurant image (logo from restaurant_owner_profile table)
  Widget _buildRestaurantImage(User user) {
    // Check if user has restaurant owner profile with logo
    if (user.restaurantOwnerProfile?.logoUrl != null &&
        user.restaurantOwnerProfile!.logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: context.responsiveBorderRadius(16),
        child: Image.network(
          user.restaurantOwnerProfile!.logoUrl!,
          width: 32.w,
          height: 32.h,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.store,
              size: 20.sp,
              color: const Color(0xFF424242), // Dark grey
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Icon(
              Icons.store,
              size: 20.sp,
              color: const Color(0xFF424242), // Dark grey
            );
          },
        ),
      );
    }

    // Fallback to default restaurant icon
    return Icon(
      Icons.store,
      size: 20.sp,
      color: const Color(0xFF424242), // Dark grey
    );
  }

  /// Build delivery man image (profile image from delivery_man_profiles table)
  Widget _buildDeliveryManImage(User user) {
    // Check if user has delivery man profile with image
    if (user.deliveryManProfile?.profileImageUrl != null &&
        user.deliveryManProfile!.profileImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: context.responsiveBorderRadius(16),
        child: Image.network(
          user.deliveryManProfile!.profileImageUrl!,
          width: 32.w,
          height: 32.h,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.local_shipping,
              size: 20.sp,
              color: const Color(0xFF424242), // Dark grey
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Icon(
              Icons.local_shipping,
              size: 20.sp,
              color: const Color(0xFF424242), // Dark grey
            );
          },
        ),
      );
    }

    // Fallback to default delivery man icon
    return Icon(
      Icons.local_shipping,
      size: 20.sp,
      color: const Color(0xFF424242), // Dark grey
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate animation progress based on scroll offset
    // Use maxScrollOffset to make animation responsive to device-specific stop point
    // Animation completes at 70% of maxScrollOffset for smooth transition
    final animationThreshold = widget.maxScrollOffset * 0.70;
    final rawProgress =
        (widget.scrollOffset / animationThreshold).clamp(0.0, 1.0);

    // Apply easing curve for smoother transition
    final fadeProgress = Curves.easeInOutCubic.transform(rawProgress);

    // Icons fade out faster, search fab fades in with slight delay for smoother effect
    final iconsOpacity = (1.0 - fadeProgress * 1.2).clamp(0.0, 1.0);
    final searchOpacity = ((fadeProgress - 0.1) * 1.2).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header controls row with animated transition
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: 44.0, // Fixed height for smooth transition
              child: Stack(
                children: [
                  // Icons layer (fades out)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: iconsOpacity,
                    curve: Curves.easeInOut,
                    child: IgnorePointer(
                      ignoring: fadeProgress > 0.5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Role-based navigation button
                          Container(
                            width: 32.w,
                            height: 32.h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: context.responsiveBorderRadius(16),
                            ),
                            child: Selector<AuthService, User?>(
                              selector: (_, authService) =>
                                  authService.currentUser,
                              builder: (context, currentUser, child) {
                                return IconButton(
                                  onPressed: _navigateBasedOnRole,
                                  icon: _buildRoleBasedImage(currentUser),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                );
                              },
                            ),
                          ),

                          const Spacer(),

                          // Language switcher
                          LanguageSwitcher(
                            onLanguageChanged: () {
                              // Refresh the UI when language changes
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Search FAB layer (fades in and expands)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: searchOpacity,
                    curve: Curves.easeInOut,
                    // Only ignore pointer events when opacity is very low to allow interaction when visible
                    child: IgnorePointer(
                      ignoring: searchOpacity < 0.3,
                      child: Center(
                        child: Selector<HomeProvider, String>(
                          selector: (_, provider) =>
                              provider.state.currentSearchQuery,
                          builder: (context, currentSearchQuery, child) {
                            final homeProvider = Provider.of<HomeProvider>(
                                context,
                                listen: false);
                            return SearchFab(
                              visible: fadeProgress > 0.1,
                              expandProgress: fadeProgress,
                              initialQuery: currentSearchQuery,
                              onChanged: (query) {
                                homeProvider.searchRestaurants(query);
                              },
                              onCleared: () {
                                homeProvider.searchRestaurants('');
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MenuTextPill extends StatefulWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _MenuTextPill(
      {required this.value, required this.options, required this.onSelected});

  @override
  State<_MenuTextPill> createState() => _MenuTextPillState();
}

class _MenuTextPillState extends State<_MenuTextPill> {
  final GlobalKey _anchorKey = GlobalKey();
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      key: _anchorKey,
      alignmentOffset: const Offset(0, 8),
      builder: (context, controller, child) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(
                alpha:
                    0.9), // Semi-transparent white for consistency with orange background
            borderRadius:
                BorderRadius.circular(22), // Reduced by 15% from 25.5 to 22
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                    alpha: 0.08), // ✅ APPLIED: Saved screen shadow style
                blurRadius: 12, // ✅ APPLIED: Saved screen shadow blur
                offset:
                    const Offset(0, 4), // ✅ APPLIED: Saved screen shadow offset
                spreadRadius: 0, // ✅ APPLIED: Saved screen shadow spread
              ),
              BoxShadow(
                color: Colors.black.withValues(
                    alpha: 0.04), // ✅ APPLIED: Saved screen second shadow
                blurRadius: 24, // ✅ APPLIED: Saved screen second shadow blur
                offset: const Offset(
                    0, 8), // ✅ APPLIED: Saved screen second shadow offset
                spreadRadius: 0, // ✅ APPLIED: Saved screen second shadow spread
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              _menuOpen = !_menuOpen;
              _menuOpen ? controller.open() : controller.close();
            },
            borderRadius:
                BorderRadius.circular(22), // Reduced by 15% from 25.5 to 22
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7), // Reduced by 15%
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.value,
                    style: GoogleFonts.inter(
                      fontSize: 10, // Reduced by 15% from 12
                      fontWeight: FontWeight
                          .w600, // ✅ APPLIED: Saved screen tab bar style font weight
                      color: Colors
                          .white, // White for better contrast on orange background
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(
                      width:
                          4), // ✅ APPLIED: Saved screen tab bar style spacing
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 12, color: Colors.white), // Reduced by 15% from 14
                ],
              ),
            ),
          ),
        );
      },
      menuChildren: [
        for (final option in widget.options)
          MenuItemButton(
            onPressed: () {
              widget.onSelected(option);
              setState(() => _menuOpen = false);
            },
            child: Text(
              option,
              style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: Colors.black),
            ),
          )
      ],
    );
  }
}
