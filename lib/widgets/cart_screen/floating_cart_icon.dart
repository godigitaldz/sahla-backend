import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../cart_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../screens/cart_screen.dart';
import '../../services/auth_service.dart';
import '../../services/enhanced_order_tracking_service.dart';
import '../../services/order_service.dart';
import '../../services/transition_service.dart';
import 'order_history_card.dart';

  /// Service for managing active orders with optimized performance and lazy loading
class _ActiveOrdersService {
  static const Duration _autoRefreshInterval = Duration(seconds: 30); // Reduced frequency
  static const Duration _debounceDelay = Duration(milliseconds: 500);

  Timer? _autoRefreshTimer;
  Timer? _debounceTimer;
  RealtimeChannel? _ordersChannel;
  StreamSubscription? _orderStatusSubscription;
  StreamSubscription? _deliveryLocationSubscription;

  // Cached active orders for performance
  List<Order> _cachedActiveOrders = [];
  bool _isLoading = false;
  DateTime? _lastLoadTime;
  static const Duration _minLoadInterval = Duration(seconds: 5); // Prevent rapid reloads

  bool get hasActiveOrders => _cachedActiveOrders.isNotEmpty;
  int get activeOrdersCount => _cachedActiveOrders.length;
  List<Order> get activeOrders => List.unmodifiable(_cachedActiveOrders);

  /// Initialize the service with lazy loading - only subscribe to realtime
  Future<void> initialize(BuildContext context) async {
    // Lazy load: Don't load orders immediately, only when widget becomes visible
    // Just set up realtime subscriptions for updates
    if (!context.mounted) return;

    _subscribeRealtime(context);
    _subscribeEnhancedRealtime(context);
    // Auto-refresh only starts after first manual load
  }

  /// Lazy load active orders - only called when widget is actually visible
  Future<void> loadActiveOrdersIfNeeded(BuildContext context) async {
    // Prevent duplicate loads
    if (_isLoading) return;

    // Throttle: Don't reload if recently loaded
    if (_lastLoadTime != null &&
        DateTime.now().difference(_lastLoadTime!) < _minLoadInterval) {
      return;
    }

    // If we have cached orders, load in background without blocking
    if (_cachedActiveOrders.isNotEmpty) {
      unawaited(_loadActiveOrders(context));
      return;
    }

    // First load: await it
    await _loadActiveOrders(context);

    // Start auto-refresh only after first successful load
    if (_cachedActiveOrders.isNotEmpty && _autoRefreshTimer == null) {
      _startAutoRefresh(context);
    }
  }

  /// Load active orders with caching and error handling
  Future<void> _loadActiveOrders(BuildContext context) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final orderService = Provider.of<OrderService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        _cachedActiveOrders = [];
        _lastLoadTime = DateTime.now();
        return;
      }

      final userOrders = await orderService.getOrdersByUserId(currentUser.id);
      final activeOrders = userOrders
          .where((order) =>
              order.status != OrderStatus.delivered &&
              order.status != OrderStatus.cancelled)
          .toList();

      _cachedActiveOrders = activeOrders;
      _lastLoadTime = DateTime.now();
    } catch (e) {
      debugPrint('❌ Error loading active orders: $e');
      // Keep existing cached orders on error
    } finally {
      _isLoading = false;
    }
  }

  /// Subscribe to real-time order updates with debouncing
  void _subscribeRealtime(BuildContext context) {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      _ordersChannel?.unsubscribe();
      final client = Supabase.instance.client;
      _ordersChannel =
          client.channel('realtime:orders:user:$userId').onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'orders',
                callback: (payload) {
                  // Debounce realtime updates to prevent excessive reloads
                  _debounceTimer?.cancel();
                  _debounceTimer = Timer(_debounceDelay, () {
                    if (context.mounted) {
                      unawaited(_loadActiveOrders(context));
                    }
                  });
                },
              )..subscribe();
    } catch (e) {
      debugPrint('❌ Realtime subscription error: $e');
    }
  }

  /// Subscribe to enhanced real-time updates
  void _subscribeEnhancedRealtime(BuildContext context) {
    try {
      final enhancedTrackingService =
          Provider.of<EnhancedOrderTrackingService>(context, listen: false);

      _orderStatusSubscription?.cancel();
      _deliveryLocationSubscription?.cancel();

      _orderStatusSubscription =
          enhancedTrackingService.deliveryStatusStream.listen((data) {
        if (context.mounted) {
          _handleEnhancedOrderStatusUpdate(data, context);
        }
      });

      _deliveryLocationSubscription =
          enhancedTrackingService.deliveryLocationStream.listen((data) {
        if (context.mounted) {
          _handleEnhancedDeliveryLocationUpdate(data, context);
        }
      });
    } catch (e) {
      debugPrint('❌ Enhanced realtime subscription error: $e');
    }
  }

  /// Handle enhanced order status updates - update cache directly without reload
  void _handleEnhancedOrderStatusUpdate(
      Map<String, dynamic> data, BuildContext context) {
    try {
      final orderId = data['orderId'] as String;
      final status = data['status'] as String;

      final orderIndex =
          _cachedActiveOrders.indexWhere((order) => order.id == orderId);
      if (orderIndex == -1) return;

      if (status == 'delivered' || status == 'cancelled') {
        _cachedActiveOrders.removeAt(orderIndex);
      }
      // Don't reload all orders just for status update - update cache directly
    } catch (e) {
      debugPrint('❌ Enhanced order status update error: $e');
    }
  }

  /// Handle enhanced delivery location updates - no need to reload orders
  void _handleEnhancedDeliveryLocationUpdate(
      Map<String, dynamic> data, BuildContext context) {
    // Location updates don't require reloading orders list
    // Just update the specific order's location if needed
  }

  /// Start auto-refresh with lifecycle awareness - only if needed
  void _startAutoRefresh(BuildContext context) {
    _autoRefreshTimer?.cancel();
    // Only refresh if we have active orders
    if (_cachedActiveOrders.isEmpty) return;

    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) async {
      if (context.mounted && _cachedActiveOrders.isNotEmpty) {
        await _loadActiveOrders(context);
      } else {
        _autoRefreshTimer?.cancel();
      }
    });
  }

  /// Force refresh active orders
  Future<void> refreshActiveOrders(BuildContext context) async {
    await _loadActiveOrders(context);
  }

  /// Clean up all subscriptions and timers
  void dispose() {
    _autoRefreshTimer?.cancel();
    _debounceTimer?.cancel();
    _ordersChannel?.unsubscribe();
    _orderStatusSubscription?.cancel();
    _deliveryLocationSubscription?.cancel();
  }
}

/// Optimized floating cart icon with performance enhancements
class FloatingCartIcon extends StatelessWidget {
  const FloatingCartIcon({super.key});

  static const _cartIconSize = 65.0; // Increased by 10% from 58.5, matched to floating icon card
  static const _badgeSize = 20.0; // Increased by 10% from 18.0, matched to floating icon card
  static const _iconSize = 32.0; // Increased by 10% from 28.8, matched to floating icon card
  static const _badgeFontSize = 12.0; // Increased by 10% from 10.8, matched to floating icon card

  // Pre-calculated shadow for better performance
  static const _optimizedShadow = BoxShadow(
    color: Color(0x26000000), // black.withValues(alpha: 0.15)
    spreadRadius: 2,
    blurRadius: 8,
    offset: Offset(0, 4),
  );

  static const _optimizedBadgeShadow = BoxShadow(
    color: Color(0x0A000000), // black.withValues(alpha: 0.05)
    spreadRadius: 1,
    blurRadius: 4,
    offset: Offset(0, 2),
  );

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        // Only show the cart icon when there are items in the cart
        if (cartProvider.isEmpty) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => _navigateToCart(context),
          child: Container(
            width: _cartIconSize,
            height: _cartIconSize,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [_optimizedShadow, _optimizedBadgeShadow],
            ),
            child: Stack(
              children: [
                // Cart Icon
                const Center(
                  child: Icon(
                    Icons.shopping_cart,
                    color: Colors.black,
                    size: _iconSize,
                  ),
                ),

                // Item Count Badge - always show when cart has items (RTL aware)
                PositionedDirectional(
                  top: 8.0,
                  end: 8.0,
                  child: Container(
                    padding: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.0,
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: _badgeSize,
                      minHeight: _badgeSize,
                    ),
                    child: Text(
                      '${cartProvider.itemCount}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: _badgeFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToCart(BuildContext context) {
    Navigator.push(
      context,
      TransitionService.cartTransition(const CartScreen()),
    );
  }
}

/// Optimized floating active orders icon with performance enhancements
class FloatingActiveOrdersIcon extends StatefulWidget {
  const FloatingActiveOrdersIcon({super.key});

  @override
  State<FloatingActiveOrdersIcon> createState() =>
      _FloatingActiveOrdersIconState();
}

/// Optimized state with performance mixins
class _FloatingActiveOrdersIconState extends State<FloatingActiveOrdersIcon> {
  // Use the dedicated service for all business logic
  late final _ActiveOrdersService _ordersService;

  // Performance optimizations
  static const _iconSize = 65.0;
  static const _badgeSize = 20.0;
  static const _deliveryIconSize = 32.0;
  static const _badgeFontSize = 12.0;

  // Pre-calculated shadows for better performance
  static const _optimizedShadow = BoxShadow(
    color: Color(0x26000000), // black.withValues(alpha: 0.15)
    spreadRadius: 2,
    blurRadius: 8,
    offset: Offset(0, 4),
  );

  static const _optimizedBadgeShadow = BoxShadow(
    color: Color(0x0A000000), // black.withValues(alpha: 0.05)
    spreadRadius: 1,
    blurRadius: 4,
    offset: Offset(0, 2),
  );

  @override
  void initState() {
    super.initState();
    _ordersService = _ActiveOrdersService();
    // Lazy initialization - don't load orders until widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeService();
      }
    });
  }

  /// Initialize service with lazy loading
  Future<void> _initializeService() async {
    try {
      await _ordersService.initialize(context);
      // Lazy load orders only when widget is visible
      await _ordersService.loadActiveOrdersIfNeeded(context);
      if (mounted) setState(() {});
    } catch (e) {
      // Silently fail - orders will load when needed
    }
  }

  /// Optimized refresh with debouncing
  Future<void> _refreshActiveOrders() async {
    if (!mounted) return;
    try {
      await _ordersService.refreshActiveOrders(context);
      if (mounted) setState(() {}); // Minimal rebuild
    } catch (e) {
      debugPrint('❌ Failed to refresh active orders: $e');
    }
  }

  @override
  void dispose() {
    _ordersService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lazy load orders when widget becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ordersService.loadActiveOrdersIfNeeded(context).then((_) {
          if (mounted) setState(() {});
        });
      }
    });

    // Early return optimization - no active orders
    if (!_ordersService.hasActiveOrders) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _showActiveOrdersDialog(context),
      child: Container(
        width: _iconSize,
        height: _iconSize,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [_optimizedShadow, _optimizedBadgeShadow],
        ),
        child: Stack(
          children: [
            // Delivery Icon - optimized
            const Center(
              child: Icon(
                Icons.delivery_dining,
                color: Colors.orange,
                size: _deliveryIconSize,
              ),
            ),

            // Order Count Badge - optimized (RTL aware)
            PositionedDirectional(
              top: 8.0,
              end: 8.0,
              child: Container(
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2.0,
                  ),
                ),
                constraints: const BoxConstraints(
                  minWidth: _badgeSize,
                  minHeight: _badgeSize,
                ),
                child: Text(
                  '${_ordersService.activeOrdersCount}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: _badgeFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Optimized dialog with performance enhancements
  void _showActiveOrdersDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {}, // Prevent tap from bubbling up
            child: DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) =>
                  _ActiveOrdersDialogContent(
                ordersService: _ordersService,
                scrollController: scrollController,
                onRefresh: _refreshActiveOrders,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dedicated dialog content widget for better performance and reusability
class _ActiveOrdersDialogContent extends StatefulWidget {
  final _ActiveOrdersService ordersService;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  const _ActiveOrdersDialogContent({
    required this.ordersService,
    required this.scrollController,
    required this.onRefresh,
  });

  @override
  State<_ActiveOrdersDialogContent> createState() =>
      _ActiveOrdersDialogContentState();
}

/// Optimized dialog content state
class _ActiveOrdersDialogContentState
    extends State<_ActiveOrdersDialogContent> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle - optimized
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40.0,
            height: 4.0,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header - optimized layout
          Padding(
            padding: const EdgeInsets.all(20),
            child: _DialogHeader(
              ordersService: widget.ordersService,
              onRefresh: widget.onRefresh,
            ),
          ),

          // Orders List - optimized with ListView.builder
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.ordersService.activeOrders.length,
              itemBuilder: (context, index) {
                return _OrderListItem(
                  orderIndex: index,
                  ordersService: widget.ordersService,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized dialog header
class _DialogHeader extends StatelessWidget {
  final _ActiveOrdersService ordersService;
  final Future<void> Function() onRefresh;

  const _DialogHeader({
    required this.ordersService,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Use constants from dialog content state
    const iconSize = 28.0;
    const spacing = 12.0;
    const titleFontSize = 20.0;
    const badgeFontSize = 14.0;
    const buttonSize = 40.0;

    return Row(
      children: [
        // Delivery Icon
        Icon(
          Icons.delivery_dining,
          color: Colors.orange.shade600,
          size: iconSize,
        ),
        const SizedBox(width: spacing),

        // Title and badge
        Expanded(
          child: Row(
            children: [
              Text(
                AppLocalizations.of(context)!.activeOrders,
                style: GoogleFonts.poppins(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${ordersService.activeOrdersCount}',
                  style: GoogleFonts.poppins(
                    fontSize: badgeFontSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Refresh button
        SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: AppLocalizations.of(context)!.refreshLocation,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

/// Optimized order list item with dynamic order updates
class _OrderListItem extends StatefulWidget {
  final int orderIndex;
  final _ActiveOrdersService ordersService;

  const _OrderListItem({
    required this.orderIndex,
    required this.ordersService,
  });

  @override
  State<_OrderListItem> createState() => _OrderListItemState();
}

class _OrderListItemState extends State<_OrderListItem> {
  @override
  Widget build(BuildContext context) {
    // Get the current order from the service (this will be reactive)
    final order = widget.ordersService.activeOrders[widget.orderIndex];

    return OrderHistoryCard(
      order: order,
      onUpdated: () async {
        await widget.ordersService.refreshActiveOrders(context);
        // Close dialog if no active orders remain
        if (context.mounted && !widget.ordersService.hasActiveOrders) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

class FloatingCartIconWrapper extends StatelessWidget {
  final Widget child;

  const FloatingCartIconWrapper({
    required this.child,
    super.key,
  });

  // Constants for positioning
  static const _bottomPadding = 20.0;
  static const _iconSize = 65.0;
  static const _iconSpacing = 15.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // Cart Icon positioned at bottom right (RTL aware)
        const PositionedDirectional(
          end: 8.0,
          bottom: _bottomPadding,
          child: FloatingCartIcon(),
        ),
        // Active Orders Icon positioned above cart icon (RTL aware)
        const PositionedDirectional(
          end: 8.0,
          bottom: _bottomPadding + _iconSize + _iconSpacing,
          child: FloatingActiveOrdersIcon(),
        ),
      ],
    );
  }
}
