import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/order.dart';

class MapOrderHeader extends StatelessWidget {
  final Order order;
  final LatLng? restaurantLocation;
  final LatLng? deliveryLocation;
  final double? distanceToRestaurant;
  final double? distanceToDelivery;
  final Duration? etaToRestaurant;
  final Duration? etaToDelivery;
  final VoidCallback? onBack;

  const MapOrderHeader({
    required this.order,
    super.key,
    this.restaurantLocation,
    this.deliveryLocation,
    this.distanceToRestaurant,
    this.distanceToDelivery,
    this.etaToRestaurant,
    this.etaToDelivery,
    this.onBack,
  });

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _getTotalDistance() {
    final restaurantDistance = distanceToRestaurant ?? 0.0;
    final deliveryDistance = distanceToDelivery ?? 0.0;
    final total = restaurantDistance + deliveryDistance;
    return total.toStringAsFixed(1);
  }

  String _getTotalTime() {
    final restaurantTime = etaToRestaurant?.inMinutes ?? 0;
    final deliveryTime = etaToDelivery?.inMinutes ?? 0;
    final total = restaurantTime + deliveryTime;
    return total.toString();
  }

  String _getRestaurantLocation() {
    if (order.restaurant == null) return 'Restaurant location';

    final restaurant = order.restaurant!;

    // If we have coordinates, create Google Maps URL
    if (restaurant.latitude != null && restaurant.longitude != null) {
      return 'https://maps.google.com/?q=${restaurant.latitude},${restaurant.longitude}';
    }

    // Fallback to address
    return '${restaurant.addressLine1}, ${restaurant.city}';
  }

  Future<void> _openRestaurantLocation() async {
    if (order.restaurant?.latitude != null &&
        order.restaurant?.longitude != null) {
      final url =
          'https://maps.google.com/?q=${order.restaurant!.latitude},${order.restaurant!.longitude}';
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        // Handle Google Maps opening error silently
        // Error handling can be implemented here if needed
      }
    }
  }

  Widget _buildAvailableHeader() {
    // Restaurant data is available for display

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFd47b00), // Orange 600
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button and order info
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderNumber}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusText(order.status),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Restaurant info under order number/status
          Row(
            children: [
              const Icon(
                Icons.restaurant,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                order.restaurant?.name ?? 'Restaurant',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          GestureDetector(
            onTap: () => _openRestaurantLocation(),
            child: Text(
              _getRestaurantLocation(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
                decoration: order.restaurant?.latitude != null &&
                        order.restaurant?.longitude != null
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Customer info
          Row(
            children: [
              const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Customer',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            order.deliveryAddress.fullAddress,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 20),

          // Counter with total distance and time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.directions,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Total: ${_getTotalDistance()} km • ${_getTotalTime()} min',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveHeader() {
    final isPickedUp = order.status == OrderStatus.pickedUp;
    final targetDistance =
        isPickedUp ? distanceToDelivery : distanceToRestaurant;
    final targetEta = isPickedUp ? etaToDelivery : etaToRestaurant;
    final targetTitle = isPickedUp ? 'Delivery' : 'Restaurant';
    final targetAddress =
        isPickedUp ? order.deliveryAddress.fullAddress : 'Pickup Location';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFd47b00), // Orange 600
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button and order info
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderNumber}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusText(order.status),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Target location info
          Row(
            children: [
              Icon(
                isPickedUp ? Icons.location_on : Icons.restaurant,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                isPickedUp
                    ? targetTitle
                    : (order.restaurant?.name ?? targetTitle),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          GestureDetector(
            onTap: isPickedUp ? null : () => _openRestaurantLocation(),
            child: Text(
              isPickedUp ? targetAddress : _getRestaurantLocation(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
                decoration: !isPickedUp &&
                        order.restaurant?.latitude != null &&
                        order.restaurant?.longitude != null
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          if (targetDistance != null && targetEta != null) ...[
            const SizedBox(height: 20),

            // Distance and time info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${targetDistance.toStringAsFixed(1)} km • ${targetEta.inMinutes} min',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if order is assigned to a delivery person
    final isAssigned = order.deliveryPersonId != null;

    switch (order.status) {
      case OrderStatus.preparing:
        // If preparing and assigned, show active header; if not assigned, show available header
        return isAssigned ? _buildActiveHeader() : _buildAvailableHeader();
      case OrderStatus.ready:
      case OrderStatus.pickedUp:
        return _buildActiveHeader();
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return const SizedBox.shrink();
    }
  }
}
