// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/menu_item_service.dart';
import '../services/restaurant_service.dart';
import '../widgets/restaurant_dashboard_screen/manage_menu_screen.dart';
import '../widgets/restaurant_dashboard_screen/manage_orders_screen.dart';

class RestaurantDashboardScreen extends StatefulWidget {
  const RestaurantDashboardScreen({super.key});

  @override
  State<RestaurantDashboardScreen> createState() =>
      _RestaurantDashboardScreenState();
}

class _RestaurantDashboardScreenState extends State<RestaurantDashboardScreen> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _ensureRestaurantExists();
  }

  Future<void> _ensureRestaurantExists() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        if (mounted) {
          setState(() => _isInitializing = false);
        }
        return;
      }

      final restaurantService =
          Provider.of<RestaurantService>(context, listen: false);
      final restaurant =
          await restaurantService.getRestaurantByOwnerId(currentUser.id);

      if (restaurant == null) {
        // Automatically create a restaurant for the user
        try {
          final menuItemService =
              Provider.of<MenuItemService>(context, listen: false);
          await menuItemService.ensureUserHasRestaurant(currentUser.id);
        } catch (e) {
          debugPrint('Failed to create restaurant: $e');
        }
      }

      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      debugPrint('Error ensuring restaurant exists: $e');
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit Restaurant Dashboard'),
          content: const Text(
              'Are you sure you want to exit the restaurant dashboard?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Exit dashboard
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Stack(
            children: [
              // Main content
              if (_isInitializing)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFd47b00),
                    ),
                  ),
                )
              else
                _buildOrdersView(),
              // Floating Action Buttons
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Orders FAB (top)
                    FloatingActionButton(
                      onPressed: () async {
                        if (!mounted) return;

                        await Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const ManageOrdersScreen(),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              const begin = Offset(1.0, 0.0);
                              const end = Offset.zero;
                              const curve = Curves.easeInOutCubic;

                              final tween = Tween(begin: begin, end: end)
                                  .chain(CurveTween(curve: curve));
                              final offsetAnimation = animation.drive(tween);

                              final fadeAnimation =
                                  Tween<double>(begin: 0.0, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: const Interval(0.0, 0.7,
                                      curve: Curves.easeOut),
                                ),
                              );

                              return SlideTransition(
                                position: offsetAnimation,
                                child: FadeTransition(
                                  opacity: fadeAnimation,
                                  child: child,
                                ),
                              );
                            },
                            transitionDuration:
                                const Duration(milliseconds: 450),
                            reverseTransitionDuration:
                                const Duration(milliseconds: 400),
                          ),
                        );
                      },
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                      elevation: 6,
                      child: const Icon(Icons.receipt_long, size: 28),
                    ),
                    const SizedBox(height: 16),
                    // Menu FAB (bottom)
                    FloatingActionButton(
                      onPressed: () async {
                        if (!mounted) return;

                        await Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const ManageMenuScreen(),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              const begin = Offset(1.0, 0.0);
                              const end = Offset.zero;
                              const curve = Curves.easeInOutCubic;

                              final tween = Tween(begin: begin, end: end)
                                  .chain(CurveTween(curve: curve));
                              final offsetAnimation = animation.drive(tween);

                              final fadeAnimation =
                                  Tween<double>(begin: 0.0, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: const Interval(0.0, 0.7,
                                      curve: Curves.easeOut),
                                ),
                              );

                              return SlideTransition(
                                position: offsetAnimation,
                                child: FadeTransition(
                                  opacity: fadeAnimation,
                                  child: child,
                                ),
                              );
                            },
                            transitionDuration:
                                const Duration(milliseconds: 450),
                            reverseTransitionDuration:
                                const Duration(milliseconds: 400),
                          ),
                        );
                      },
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      elevation: 6,
                      child: const Icon(Icons.restaurant_menu, size: 28),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Restaurant Dashboard',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the floating buttons to manage your menu and orders',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
