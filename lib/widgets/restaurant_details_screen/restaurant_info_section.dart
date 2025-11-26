import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/restaurant.dart';
import '../../providers/location_provider.dart';
import '../../utils/price_formatter.dart';
import '../../utils/working_hours_utils.dart';

/// Restaurant info section with social links and delivery info
/// Extracted from RestaurantDetailsScreen for better modularity
class RestaurantInfoSection extends StatelessWidget {
  const RestaurantInfoSection({
    required this.restaurant,
    required this.totalDeliveryTime,
    required this.lowestMenuItemPrice,
    required this.dynamicDeliveryFee,
    super.key,
  });

  final Restaurant restaurant;
  final int totalDeliveryTime;
  final double lowestMenuItemPrice;
  final double? dynamicDeliveryFee;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.0),
              spreadRadius: 0,
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Info cards row (RTL aware)
            Row(
              textDirection: Directionality.of(context),
              children: [
                Expanded(
                  child: _buildInfoCard(
                    context,
                    Icons.delivery_dining,
                    AppLocalizations.of(context)!.delivery,
                    "$totalDeliveryTime ${AppLocalizations.of(context)!.min}",
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _buildInfoCard(
                    context,
                    AppLocalizations.of(context)?.currency ?? "DZD",
                    AppLocalizations.of(context)?.minimumOrderLabel ??
                        "Min Order",
                    PriceFormatter.formatWithSettings(
                        context, lowestMenuItemPrice.toString()),
                  ),
                ),
                const SizedBox(width: 7),
                // Hide delivery fee card if no location permission or service is off
                Consumer<LocationProvider>(
                  builder: (context, locationProvider, child) {
                    final hasPermission = locationProvider.hasPermission;
                    final isLocationEnabled = locationProvider.isLocationEnabled;

                    // Hide delivery fee card if no permission or service is off
                    if (!hasPermission || !isLocationEnabled) {
                      return const SizedBox.shrink();
                    }

                    return Expanded(
                      child: _buildInfoCard(
                        context,
                        Icons.local_shipping,
                        AppLocalizations.of(context)!.deliveryFee,
                        ((dynamicDeliveryFee ?? restaurant.deliveryFee) <= 0)
                            ? AppLocalizations.of(context)!.freeDelivery
                            : PriceFormatter.formatWithSettings(
                                context,
                                (dynamicDeliveryFee ?? restaurant.deliveryFee)
                                    .toString()),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _buildOpenStatusCard(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialBar(BuildContext context) {
    // Enhanced responsive sizing for small screens
    final screenWidth = MediaQuery.of(context).size.width;
    final barHeight = screenWidth < 360 ? 44.0 : 48.0;
    final spacing = screenWidth < 360 ? 5.0 : 7.0;
    final mapsWidth = screenWidth < 360 ? 90.0 : 102.0;
    final mapsHeight = screenWidth < 360 ? 30.0 : 34.0;
    final chipSize = screenWidth < 360 ? 34.0 : 37.0;

    return Container(
      height: barHeight,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: Directionality.of(context),
        children: [
          // Call chip
          _buildActionChip(
            onTap: () => _makePhoneCall(context),
            icon: Icons.phone,
            color: Colors.green[600]!,
            size: chipSize,
          ),

          SizedBox(width: spacing),

          // Google Maps button with image
          GestureDetector(
            onTap: () => _openGoogleMaps(context),
            child: Container(
              width: mapsWidth,
              height: mapsHeight,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/icon/google maps.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          SizedBox(width: spacing),

          // Social media chips
          if (restaurant.instagram != null) ...[
            _buildSocialChip(
              imagePath: 'assets/icon/instagram.png',
              onTap: () =>
                  _openSocialMedia(context, 'instagram', restaurant.instagram!),
              size: chipSize,
            ),
            SizedBox(width: spacing),
          ],
          if (restaurant.facebook != null) ...[
            _buildSocialChip(
              imagePath: 'assets/icon/facebook.png',
              onTap: () =>
                  _openSocialMedia(context, 'facebook', restaurant.facebook!),
              size: chipSize,
            ),
            SizedBox(width: spacing),
          ],
          if (restaurant.tiktok != null)
            _buildSocialChip(
              imagePath: 'assets/icon/tiktok.png',
              onTap: () =>
                  _openSocialMedia(context, 'tiktok', restaurant.tiktok!),
              size: chipSize,
            ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    double size = 37.0,
  }) {
    final iconSize = size * 0.46; // Proportional icon size

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 7,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialChip({
    required String imagePath,
    required VoidCallback onTap,
    double size = 37.0,
  }) {
    final padding = size * 0.23; // Proportional padding

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 7,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    Object icon,
    String label,
    String value,
  ) {
    // Enhanced responsive sizing for small screens
    final screenWidth = MediaQuery.of(context).size.width;

    // Icon size: smaller on very small screens
    final iconSize = screenWidth < 360 ? 15.0 : 17.0;

    // Text icon size: adaptive
    final textIconSize = screenWidth < 360 ? 10.0 : 12.0;

    // Label font size: adaptive (7.2 base)
    final labelFontSize = screenWidth < 360
        ? 6.5
        : screenWidth < 400
            ? 7.0
            : 7.2;

    // Value font size: adaptive (8.5 base)
    final valueFontSize = screenWidth < 360
        ? 7.8
        : screenWidth < 400
            ? 8.2
            : 8.5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon is IconData)
          Icon(
            icon,
            size: iconSize,
            color: Colors.orange[600],
          )
        else
          Text(
            icon as String,
            style: GoogleFonts.poppins(
              fontSize: textIconSize,
              fontWeight: FontWeight.bold,
              color: Colors.orange[600],
            ),
          ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: labelFontSize,
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1.5),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: valueFontSize,
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildOpenStatusCard(BuildContext context) {
    // Get full status text from WorkingHoursUtils
    final fullStatusText =
        WorkingHoursUtils.getStatusText(restaurant.openingHours);

    // Parse the status text to separate status and time
    String statusText = '';
    String timeText = '';
    bool isOpen = false;

    if (fullStatusText.contains('•')) {
      final parts = fullStatusText.split('•');
      statusText = parts[0].trim();
      timeText = parts.length > 1 ? parts[1].trim() : '';
      isOpen = statusText.toLowerCase() == 'open';
    } else {
      statusText = fullStatusText;
      isOpen = fullStatusText.toLowerCase().contains('open');
    }

    // If no working hours available, use restaurant's isOpen flag
    if (fullStatusText == 'Hours not available') {
      isOpen = restaurant.isOpen;
      statusText = isOpen
          ? AppLocalizations.of(context)!.openLabel
          : AppLocalizations.of(context)!.closedLabel;
      timeText = '';
    }

    // Localize the status text
    if (statusText.toLowerCase() == 'open') {
      statusText = AppLocalizations.of(context)!.openLabel;
    } else if (statusText.toLowerCase() == 'closed') {
      statusText = AppLocalizations.of(context)!.closedLabel;
    }

    // Enhanced responsive sizing for small screens
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 360 ? 15.0 : 17.0;
    final labelFontSize = screenWidth < 360
        ? 6.5
        : screenWidth < 400
            ? 7.0
            : 7.2;
    final valueFontSize = screenWidth < 360
        ? 7.8
        : screenWidth < 400
            ? 8.2
            : 8.5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOpen ? Icons.check_circle : Icons.access_time,
          size: iconSize,
          color: isOpen ? Colors.orange[600] : Colors.red[600],
        ),
        const SizedBox(height: 3),
        Text(
          statusText,
          style: GoogleFonts.poppins(
            fontSize: labelFontSize,
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1.5),
        Text(
          timeText.isNotEmpty ? timeText : '-',
          style: GoogleFonts.poppins(
            fontSize: valueFontSize,
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<void> _makePhoneCall(BuildContext context) async {
    final phoneNumber = restaurant.phone;

    if (phoneNumber.isNotEmpty) {
      final url = "tel:$phoneNumber";
      final uri = Uri.parse(url);

      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception("Could not launch phone dialer");
        }
      } on Exception catch (e) {
        debugPrint("Error making phone call: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.error),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.phoneNumberNotAvailable),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _openGoogleMaps(BuildContext context) async {
    final lat = restaurant.latitude;
    final lng = restaurant.longitude;

    if (lat != null && lng != null) {
      final url = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
      final uri = Uri.parse(url);

      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception("Could not launch Google Maps");
        }
      } on Exception catch (e) {
        debugPrint("Error opening Google Maps: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.error),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.notAvailable),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _openSocialMedia(
    BuildContext context,
    String platform,
    String handle,
  ) async {
    String url;

    // Build URL based on platform
    switch (platform) {
      case 'instagram':
        if (handle.startsWith('http')) {
          url = handle;
        } else {
          final username =
              handle.startsWith('@') ? handle.substring(1) : handle;
          url = 'https://www.instagram.com/$username';
        }
        break;
      case 'facebook':
        if (handle.startsWith('http')) {
          url = handle;
        } else {
          url = 'https://www.facebook.com/$handle';
        }
        break;
      case 'tiktok':
        if (handle.startsWith('http')) {
          url = handle;
        } else {
          final username =
              handle.startsWith('@') ? handle.substring(1) : handle;
          url = 'https://www.tiktok.com/@$username';
        }
        break;
      default:
        return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open $platform'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening $platform: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening $platform'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
