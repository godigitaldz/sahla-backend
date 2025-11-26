import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/menu_item.dart';
import '../../../../utils/price_formatter.dart';
import '../../../menu_item_full_popup/helpers/special_pack_helper.dart';
import '../edit_review_item_popup/regular_item_review.dart';
import '../edit_review_item_popup/special_pack_review.dart';
import '../review_popup_widget.dart';

/// Unified Menu Item Card Widget
/// Handles both regular menu items and LTO items with appropriate styling and actions
class MenuItemCardWidget extends StatelessWidget {
  final MenuItem item;
  final String? formattedPrice; // Optional for LTO items (will be computed)
  final VoidCallback? onTap;
  final VoidCallback? onToggleAvailability;
  final VoidCallback? onDelete;
  final Function(DateTime startDate, DateTime endDate)?
      onReactivate; // For LTO items

  const MenuItemCardWidget({
    required this.item,
    this.formattedPrice,
    this.onTap,
    this.onToggleAvailability,
    this.onDelete,
    this.onReactivate,
    super.key,
  });

  /// Check if this is an LTO item
  bool get _isLTOItem => item.isOfferActive || item.hasExpiredLTOOffer;

  @override
  Widget build(BuildContext context) {
    if (_isLTOItem) {
      return _buildLTOCard(context);
    } else {
      return _buildRegularCard(context);
    }
  }

  /// Build regular menu item card
  Widget _buildRegularCard(BuildContext context) {
    final price = formattedPrice ??
        PriceFormatter.formatWithSettings(
          context,
          item.price.toString(),
        );

    // PERF: Reusable shadow decoration to avoid recalculating
    final BoxDecoration cardDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          spreadRadius: 0,
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );

    return GestureDetector(
      onTap: onTap ?? () => _showRegularItemDetails(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: cardDecoration,
        child: Row(
          children: [
            // Enhanced menu item image with review chip
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    item.image,
                    width: 50,
                    height: 60,
                    fit: BoxFit.cover,
                    cacheWidth: 100, // 2x for retina displays
                    cacheHeight: 120,
                    // PERF: Use low filter quality for thumbnails
                    filterQuality: FilterQuality.low,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 50,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 50,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.restaurant, color: Colors.grey),
                    ),
                  ),
                ),
                // Yellow review chip in top left
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber[600],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 10,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          item.rating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),

            // Menu item content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // First row: name and price
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // PERF: Use pre-formatted price passed from parent
                      Text(
                        price,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Second row: availability and action buttons
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Availability status (left side)
                      Text(
                        item.isAvailable
                            ? AppLocalizations.of(context)!.available
                            : AppLocalizations.of(context)!.unavailable,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),

                      const Spacer(),

                      // Action buttons positioned under price (right side, smaller height)
                      SizedBox(
                        height:
                            28, // Reduced height to prevent card height increase
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Hide/Show button
                            if (onToggleAvailability != null)
                              GestureDetector(
                                onTap: onToggleAvailability,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: item.isAvailable
                                        ? Colors.orange.withOpacity(0.1)
                                        : Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    item.isAvailable
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 14,
                                    color: item.isAvailable
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                ),
                              ),
                            if (onToggleAvailability != null &&
                                onDelete != null)
                              const SizedBox(width: 4),
                            // Delete button
                            if (onDelete != null)
                              GestureDetector(
                                onTap: onDelete,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    size: 14,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build LTO item card
  Widget _buildLTOCard(BuildContext context) {
    final discountedPrice = item.price;
    final originalPrice = item.originalPrice;

    final formattedPrice = PriceFormatter.formatWithSettings(
      context,
      discountedPrice.toString(),
    );

    final isActive = item.isOfferActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Tappable area (image + info)
          Expanded(
            child: GestureDetector(
              onTap: onTap ?? () => _showLTOReview(context),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  // LTO item image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.image,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      // PERF: Add cache dimensions for thumbnail optimization
                      cacheWidth: 120, // 2x for retina displays
                      cacheHeight: 120,
                      // PERF: Use low filter quality for thumbnails
                      filterQuality: FilterQuality.low,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child:
                            const Icon(Icons.local_offer, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // LTO item info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              formattedPrice,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFd47b00),
                              ),
                            ),
                            if (originalPrice != null &&
                                originalPrice > discountedPrice) ...[
                              const SizedBox(width: 8),
                              Text(
                                PriceFormatter.formatWithSettings(
                                  context,
                                  originalPrice.toString(),
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFFd47b00)
                                    : Colors.grey[400],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Expired',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.effectiveAvailability
                                  ? 'Available'
                                  : 'Unavailable',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions (separate from tappable area)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reactivate button (only for expired LTO items)
              if (item.hasExpiredLTOOffer &&
                  !item.isOfferActive &&
                  onReactivate != null)
                GestureDetector(
                  onTap: () {
                    _showReactivateDialog(context);
                  },
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {}, // Stop event propagation
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFd47b00).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      size: 16,
                      color: Color(0xFFd47b00),
                    ),
                  ),
                ),
              if (item.hasExpiredLTOOffer &&
                  !item.isOfferActive &&
                  onReactivate != null &&
                  (onToggleAvailability != null || onDelete != null))
                const SizedBox(width: 4),
              // Hide/Show button
              if (onToggleAvailability != null)
                GestureDetector(
                  onTap: () {
                    if (onToggleAvailability != null) {
                      onToggleAvailability!();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {}, // Stop event propagation
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      item.effectiveAvailability
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              if (onToggleAvailability != null && onDelete != null)
                const SizedBox(width: 4),
              // Delete button
              if (onDelete != null)
                GestureDetector(
                  onTap: () {
                    if (onDelete != null) {
                      onDelete!();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {}, // Stop event propagation
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.delete,
                      size: 16,
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Show regular item details
  void _showRegularItemDetails(BuildContext context) {
    // Check if this is a special pack
    final isSpecialPack = SpecialPackHelper.isSpecialPack(item);

    if (isSpecialPack) {
      // Open special pack review for special pack items
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext builderContext) {
          return LTOSpecialPackReview(
            ltoItem: item,
          );
        },
      );
    } else {
      // Open regular item review for non-special pack items
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext builderContext) {
          return RegularItemReview(
            ltoItem: item,
          );
        },
      );
    }
  }

  /// Show LTO review
  void _showLTOReview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext builderContext) {
        return ReviewPopupWidget(ltoItem: item);
      },
    );
  }

  /// Show reactivate dialog for expired LTO items
  Future<void> _showReactivateDialog(BuildContext context) async {
    // Find the expired LTO pricing option
    DateTime? currentStartDate;
    DateTime? currentEndDate;

    for (final pricing in item.pricingOptions) {
      if (pricing['is_limited_offer'] == true) {
        final startAt = pricing['offer_start_at'];
        final endAt = pricing['offer_end_at'];

        if (startAt != null) {
          try {
            currentStartDate = DateTime.parse(startAt.toString());
          } catch (e) {
            // Ignore parse errors
          }
        }

        if (endAt != null) {
          try {
            currentEndDate = DateTime.parse(endAt.toString());
          } catch (e) {
            // Ignore parse errors
          }
        }
        break; // Use first expired LTO
      }
    }

    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => _ReactivateLTODialog(
        itemName: item.name,
        currentStartDate: currentStartDate,
        currentEndDate: currentEndDate,
      ),
    );

    if (result != null && onReactivate != null) {
      final startDate = result['startDate']!;
      final endDate = result['endDate']!;
      onReactivate!(startDate, endDate);
    }
  }
}

/// Dialog for reactivating expired LTO items with new dates
class _ReactivateLTODialog extends StatefulWidget {
  final String itemName;
  final DateTime? currentStartDate;
  final DateTime? currentEndDate;

  const _ReactivateLTODialog({
    required this.itemName,
    this.currentStartDate,
    this.currentEndDate,
  });

  @override
  State<_ReactivateLTODialog> createState() => _ReactivateLTODialogState();
}

class _ReactivateLTODialogState extends State<_ReactivateLTODialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    // Set default dates: start now, end in 7 days
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 7));
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFd47b00),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startDate ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFd47b00),
                onPrimary: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null && mounted) {
        setState(() {
          _startDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFd47b00),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_endDate ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFd47b00),
                onPrimary: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null && mounted) {
        setState(() {
          _endDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Reactivate LTO',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Item: ${widget.itemName}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Start Date & Time',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectStartDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _startDate != null
                          ? _dateFormat.format(_startDate!)
                          : 'Select start date',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'End Date & Time',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectEndDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _endDate != null
                          ? _dateFormat.format(_endDate!)
                          : 'Select end date',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _startDate != null &&
                  _endDate != null &&
                  _endDate!.isAfter(_startDate!)
              ? () => Navigator.of(context).pop({
                    'startDate': _startDate!,
                    'endDate': _endDate!,
                  })
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFd47b00),
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Reactivate',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
