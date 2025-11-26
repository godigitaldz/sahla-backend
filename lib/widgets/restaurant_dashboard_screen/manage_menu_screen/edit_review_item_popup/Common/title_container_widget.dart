import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../l10n/app_localizations.dart';

/// LTO Title and Container Widget
/// Displays the title with edit button and the info container with all sections
class LTOTitleContainerWidget extends StatelessWidget {
  final String title;
  final double titleFontSize;
  final bool isActive;
  final bool hasExpired;
  final double rating;
  final bool availability;
  final DateTime? startDate;
  final DateTime? endDate;
  final int prepTime;
  final bool isUpdating;
  final VoidCallback onEditName;
  final VoidCallback onEditAvailability;
  final VoidCallback onEditStartDate;
  final VoidCallback onEditEndDate;
  final VoidCallback onEditPrepTime;
  final String?
      statusLabel; // Optional custom status label (e.g., "Active LTO Pack")

  const LTOTitleContainerWidget({
    required this.title,
    required this.titleFontSize,
    required this.isActive,
    required this.hasExpired,
    required this.rating,
    required this.availability,
    required this.prepTime,
    required this.isUpdating,
    required this.onEditName,
    required this.onEditAvailability,
    required this.onEditStartDate,
    required this.onEditEndDate,
    required this.onEditPrepTime,
    this.startDate,
    this.endDate,
    this.statusLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // Name row with edit button
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.edit,
                size: 18,
                color: Color(0xFFd47b00),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: isUpdating ? null : onEditName,
              tooltip: 'Edit name',
            ),
          ],
        ),

        const SizedBox(height: 12),

        // LTO Status and Quick info - in one white container with light grey border (vertical layout)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LTO Status badge
              Row(
                children: [
                  Icon(
                    isActive ? Icons.local_offer : Icons.timer_off,
                    size: 16,
                    color: isActive
                        ? const Color(0xFFd47b00)
                        : hasExpired
                            ? Colors.grey[600]
                            : Colors.orange[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusLabel ??
                        (isActive
                            ? 'Active LTO'
                            : hasExpired
                                ? 'Expired'
                                : 'Pending'),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const Divider(
                color: Colors.grey,
                thickness: 0.5,
                height: 20,
              ),
              // Rating
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber[700], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    rating.toStringAsFixed(1),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const Divider(
                color: Colors.grey,
                thickness: 0.5,
                height: 20,
              ),
              // Availability
              Row(
                children: [
                  Icon(
                    availability ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: availability ? Colors.green[700] : Colors.red[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      availability
                          ? AppLocalizations.of(context)!.available
                          : AppLocalizations.of(context)!.unavailable,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      size: 16,
                      color: Color(0xFFd47b00),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: isUpdating ? null : onEditAvailability,
                    tooltip: 'Toggle availability',
                  ),
                ],
              ),
              // Start Date
              if (startDate != null) ...[
                const Divider(
                  color: Colors.grey,
                  thickness: 0.5,
                  height: 20,
                ),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Start: ${DateFormat('MMM dd, yyyy HH:mm').format(startDate!)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Color(0xFFd47b00),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: isUpdating ? null : onEditStartDate,
                      tooltip: 'Edit start date',
                    ),
                  ],
                ),
              ],
              // End Date
              if (endDate != null) ...[
                const Divider(
                  color: Colors.grey,
                  thickness: 0.5,
                  height: 20,
                ),
                Row(
                  children: [
                    Icon(Icons.event, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'End: ${DateFormat('MMM dd, yyyy HH:mm').format(endDate!)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Color(0xFFd47b00),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: isUpdating ? null : onEditEndDate,
                      tooltip: 'Edit end date',
                    ),
                  ],
                ),
              ],
              const Divider(
                color: Colors.grey,
                thickness: 0.5,
                height: 20,
              ),
              // Prep time
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$prepTime min',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      size: 16,
                      color: Color(0xFFd47b00),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: isUpdating ? null : onEditPrepTime,
                    tooltip: 'Edit preparation time',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
