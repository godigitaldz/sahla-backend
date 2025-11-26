import 'package:flutter/services.dart';

import '../models/delivery_man_request.dart';
import '../models/restaurant_request.dart';

class ExportService {
  /// Export restaurant requests to CSV format
  static String exportRestaurantRequestsToCsv(
      List<RestaurantRequest> requests) {
    if (requests.isEmpty) return '';

    // CSV Header
    const csvHeader =
        'ID,Restaurant Name,User Name,User Email,Wilaya,Address,Phone,Description,Status,Applied Date,Reviewed By,Reviewed Date,Rejection Reason,Latitude,Longitude\n';

    // CSV Data
    final csvData = requests.map((request) {
      return [
        request.id,
        _escapeCsvField(request.restaurantName),
        _escapeCsvField(request.userName),
        _escapeCsvField(request.userEmail),
        _escapeCsvField(request.wilaya ?? ''),
        _escapeCsvField(request.restaurantAddress),
        _escapeCsvField(request.restaurantPhone),
        _escapeCsvField(request.restaurantDescription),
        request.status.name,
        _formatDateForCsv(request.createdAt),
        _escapeCsvField(request.reviewedBy ?? ''),
        if (request.reviewedAt != null)
          _formatDateForCsv(request.reviewedAt!)
        else
          '',
        _escapeCsvField(request.rejectionReason ?? ''),
        request.latitude?.toString() ?? '',
        request.longitude?.toString() ?? '',
      ].join(',');
    }).join('\n');

    return csvHeader + csvData;
  }

  /// Export delivery man requests to CSV format
  static String exportDeliveryManRequestsToCsv(
      List<DeliveryManRequest> requests) {
    if (requests.isEmpty) return '';

    // CSV Header
    const csvHeader =
        'ID,Full Name,User Name,User Email,Phone,Address,Vehicle Type,License Number,Has Valid License,Has Vehicle,Availability,Available Weekends,Available Evenings,Experience,Status,Applied Date,Reviewed By,Reviewed Date,Rejection Reason\n';

    // CSV Data
    final csvData = requests.map((request) {
      return [
        request.id,
        _escapeCsvField(request.fullName),
        _escapeCsvField(request.userName),
        _escapeCsvField(request.userEmail),
        _escapeCsvField(request.phone),
        _escapeCsvField(request.address),
        _escapeCsvField(request.vehicleType),
        _escapeCsvField(request.plateNumber),
        if (request.hasValidLicense) 'Yes' else 'No',
        if (request.hasVehicle) 'Yes' else 'No',
        _escapeCsvField(request.availability),
        if (request.isAvailableWeekends) 'Yes' else 'No',
        if (request.isAvailableEvenings) 'Yes' else 'No',
        _escapeCsvField(request.experience ?? ''),
        request.status.name,
        _formatDateForCsv(request.createdAt),
        _escapeCsvField(request.reviewedBy ?? ''),
        if (request.reviewedAt != null)
          _formatDateForCsv(request.reviewedAt!)
        else
          '',
        _escapeCsvField(request.rejectionReason ?? ''),
      ].join(',');
    }).join('\n');

    return csvHeader + csvData;
  }

  /// Export filtered requests with search criteria
  static String exportFilteredRequestsToCsv({
    required List<RestaurantRequest> restaurantRequests,
    required List<DeliveryManRequest> deliveryManRequests,
    String? searchQuery,
    String? wilayaFilter,
    String? statusFilter,
  }) {
    final List<String> csvLines = [];

    // Add metadata header
    csvLines.add('# Export Report');
    csvLines.add('# Generated: ${_formatDateForCsv(DateTime.now())}');
    if (searchQuery != null && searchQuery.isNotEmpty) {
      csvLines.add('# Search Query: $searchQuery');
    }
    if (wilayaFilter != null && wilayaFilter.isNotEmpty) {
      csvLines.add('# Wilaya Filter: $wilayaFilter');
    }
    if (statusFilter != null && statusFilter.isNotEmpty) {
      csvLines.add('# Status Filter: $statusFilter');
    }
    csvLines.add('# Total Restaurant Requests: ${restaurantRequests.length}');
    csvLines
        .add('# Total Delivery Man Requests: ${deliveryManRequests.length}');
    csvLines.add('');

    // Add restaurant requests
    if (restaurantRequests.isNotEmpty) {
      csvLines.add('# Restaurant Requests');
      csvLines.add(exportRestaurantRequestsToCsv(restaurantRequests));
      csvLines.add('');
    }

    // Add delivery man requests
    if (deliveryManRequests.isNotEmpty) {
      csvLines.add('# Delivery Man Requests');
      csvLines.add(exportDeliveryManRequestsToCsv(deliveryManRequests));
    }

    return csvLines.join('\n');
  }

  /// Export admin activity log
  static String exportAdminActivityToCsv(
      List<Map<String, dynamic>> activities) {
    if (activities.isEmpty) return '';

    const csvHeader =
        'Timestamp,Admin User,Action,Target Type,Target ID,Details,IP Address,User Agent\n';

    final csvData = activities.map((activity) {
      return [
        _formatDateForCsv(DateTime.parse(activity['timestamp'])),
        _escapeCsvField(activity['admin_user'] ?? ''),
        _escapeCsvField(activity['action'] ?? ''),
        _escapeCsvField(activity['target_type'] ?? ''),
        _escapeCsvField(activity['target_id'] ?? ''),
        _escapeCsvField(activity['details'] ?? ''),
        _escapeCsvField(activity['ip_address'] ?? ''),
        _escapeCsvField(activity['user_agent'] ?? ''),
      ].join(',');
    }).join('\n');

    return csvHeader + csvData;
  }

  /// Export statistics summary
  static String exportStatisticsToCsv(Map<String, dynamic> stats) {
    final List<String> csvLines = [];

    csvLines.add('# Statistics Report');
    csvLines.add('# Generated: ${_formatDateForCsv(DateTime.now())}');
    csvLines.add('');

    // Restaurant statistics
    csvLines.add('# Restaurant Requests');
    csvLines.add('Metric,Count');
    csvLines.add('Total Requests,${stats['restaurant_total'] ?? 0}');
    csvLines.add('Pending Requests,${stats['restaurant_pending'] ?? 0}');
    csvLines.add('Approved Requests,${stats['restaurant_approved'] ?? 0}');
    csvLines.add('Rejected Requests,${stats['restaurant_rejected'] ?? 0}');
    csvLines.add('');

    // Delivery man statistics
    csvLines.add('# Delivery Man Requests');
    csvLines.add('Metric,Count');
    csvLines.add('Total Requests,${stats['delivery_total'] ?? 0}');
    csvLines.add('Pending Requests,${stats['delivery_pending'] ?? 0}');
    csvLines.add('Approved Requests,${stats['delivery_approved'] ?? 0}');
    csvLines.add('Rejected Requests,${stats['delivery_rejected'] ?? 0}');
    csvLines.add('');

    // Performance metrics
    csvLines.add('# Performance Metrics');
    csvLines.add('Metric,Value');
    csvLines.add(
        'Average Processing Time,${stats['avg_processing_time'] ?? 'N/A'}');
    csvLines.add('Requests Today,${stats['requests_today'] ?? 0}');
    csvLines.add('Requests This Week,${stats['requests_this_week'] ?? 0}');
    csvLines.add('Requests This Month,${stats['requests_this_month'] ?? 0}');

    return csvLines.join('\n');
  }

  /// Copy CSV data to clipboard
  static Future<void> copyToClipboard(String csvData) async {
    await Clipboard.setData(ClipboardData(text: csvData));
  }

  /// Generate filename with timestamp
  static String generateFilename(String prefix, String type) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return '${prefix}_${type}_$timestamp.csv';
  }

  /// Escape CSV field to handle commas, quotes, and newlines
  static String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      // Escape quotes by doubling them and wrap in quotes
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Format date for CSV export
  static String _formatDateForCsv(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  /// Validate CSV data before export
  static bool validateCsvData(String csvData) {
    if (csvData.isEmpty) return false;

    // Check for basic CSV structure
    final lines = csvData.split('\n');
    if (lines.length < 2) return false; // Need at least header + 1 data row

    // Check header format
    final header = lines.first;
    if (!header.contains(',')) return false;

    return true;
  }

  /// Get export statistics
  static Map<String, dynamic> getExportStats(String csvData) {
    final lines = csvData.split('\n');
    final dataLines = lines
        .where((line) =>
            line.isNotEmpty && !line.startsWith('#') && line.contains(','))
        .toList();

    return {
      'total_lines': lines.length,
      'data_lines': dataLines.length,
      'file_size_bytes': csvData.length,
      'file_size_kb': (csvData.length / 1024).toStringAsFixed(2),
      'has_header': lines.isNotEmpty && lines.first.contains(','),
    };
  }
}
