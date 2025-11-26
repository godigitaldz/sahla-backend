import 'dart:async';

import 'package:flutter/foundation.dart';
// import '../models/booking.dart'; // Removed missing import

class AvailabilityService extends ChangeNotifier {
  // Singleton pattern
  static final AvailabilityService _instance = AvailabilityService._internal();
  factory AvailabilityService() => _instance;
  AvailabilityService._internal();

  // Mock booking data - in real app, this would come from a database
  final List<dynamic> _bookings = [];
  final Map<String, List<DateTime>> _carMaintenanceDates = {};
  final Map<String, List<DateTime>> _carBlockedDates = {};

  // Stream controllers for real-time updates
  final StreamController<Map<String, bool>> _availabilityController =
      StreamController<Map<String, bool>>.broadcast();

  Stream<Map<String, bool>> get availabilityStream =>
      _availabilityController.stream;

  // Initialize with mock data
  void initialize() {
    _initializeMockBookings();
    _initializeMaintenanceDates();
    _initializeBlockedDates();

    // Start periodic availability updates
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateAvailability();
    });
  }

  void _initializeMockBookings() {
    final now = DateTime.now();

    // Add some existing bookings
    _bookings.addAll([
      // BMW X5 booked for next weekend
      {
        'id': 'booking_001',
        'carId': 'bmw_x5',
        'userId': 'user_001',
        'hostId': 'host_001',
        'startDate': now.add(const Duration(days: 7)), // Next Saturday
        'endDate': now.add(const Duration(days: 9)), // Next Monday
        'totalPrice': 3600.0,
        'status': 'confirmed',
        'createdAt': now.subtract(const Duration(days: 2)),
        'updatedAt': now.subtract(const Duration(days: 2)),
      },

      // Tesla Model 3 booked for a week starting in 3 days
      {
        'id': 'booking_002',
        'carId': 'tesla_model_3',
        'userId': 'user_002',
        'hostId': 'host_002',
        'startDate': now.add(const Duration(days: 3)),
        'endDate': now.add(const Duration(days: 10)),
        'totalPrice': 8800.0,
        'status': 'confirmed',
        'createdAt': now.subtract(const Duration(days: 1)),
        'updatedAt': now.subtract(const Duration(days: 1)),
      },

      // Audi A4 currently active booking
      {
        'id': 'booking_003',
        'carId': 'audi_a4',
        'userId': 'user_003',
        'hostId': 'host_003',
        'startDate': now.subtract(const Duration(days: 1)),
        'endDate': now.add(const Duration(days: 2)),
        'totalPrice': 3800.0,
        'status': 'active',
        'createdAt': now.subtract(const Duration(days: 3)),
        'updatedAt': now.subtract(const Duration(days: 3)),
      },

      // Range Rover booked for next month
      {
        'id': 'booking_004',
        'carId': 'range_rover',
        'userId': 'user_004',
        'hostId': 'host_004',
        'startDate': now.add(const Duration(days: 25)),
        'endDate': now.add(const Duration(days: 30)),
        'totalPrice': 9000.0,
        'status': 'confirmed',
        'createdAt': now.subtract(const Duration(days: 5)),
        'updatedAt': now.subtract(const Duration(days: 5)),
      },
    ]);
  }

  void _initializeMaintenanceDates() {
    final now = DateTime.now();

    // BMW X5 maintenance next week
    _carMaintenanceDates['bmw_x5'] = [
      now.add(const Duration(days: 12)), // Maintenance day
    ];

    // Tesla Model 3 maintenance in 2 weeks
    _carMaintenanceDates['tesla_model_3'] = [
      now.add(const Duration(days: 15)),
      now.add(const Duration(days: 16)),
    ];
  }

  void _initializeBlockedDates() {
    final now = DateTime.now();

    // Host blocked dates for personal use
    _carBlockedDates['mercedes_c'] = [
      now.add(const Duration(days: 20)), // Host personal use
      now.add(const Duration(days: 21)),
    ];
  }

  // Helper method to check if a booking conflicts with given dates
  bool _bookingConflictsWith(
      dynamic booking, DateTime startDate, DateTime endDate) {
    return booking['startDate'].isBefore(endDate) &&
        booking['endDate'].isAfter(startDate);
  }

  // Check if a car is available for given dates
  bool isCarAvailable(String carId, DateTime startDate, DateTime endDate) {
    // Check for booking conflicts
    final conflictingBookings = _bookings.where((booking) {
      return booking['carId'] == carId &&
          booking['status'] != 'cancelled' &&
          _bookingConflictsWith(booking, startDate, endDate);
    }).toList();

    if (conflictingBookings.isNotEmpty) {
      return false;
    }

    // Check for maintenance dates
    final maintenanceDates = _carMaintenanceDates[carId] ?? [];
    for (final maintenanceDate in maintenanceDates) {
      if (startDate.isBefore(maintenanceDate.add(const Duration(days: 1))) &&
          endDate.isAfter(maintenanceDate.subtract(const Duration(days: 1)))) {
        return false;
      }
    }

    // Check for blocked dates
    final blockedDates = _carBlockedDates[carId] ?? [];
    for (final blockedDate in blockedDates) {
      if (startDate.isBefore(blockedDate.add(const Duration(days: 1))) &&
          endDate.isAfter(blockedDate.subtract(const Duration(days: 1)))) {
        return false;
      }
    }

    return true;
  }

  // Get availability status for multiple cars
  Map<String, bool> getCarsAvailability(
      List<String> carIds, DateTime startDate, DateTime endDate) {
    final availability = <String, bool>{};

    for (final carId in carIds) {
      availability[carId] = isCarAvailable(carId, startDate, endDate);
    }

    return availability;
  }

  // Get detailed availability information for a car
  CarAvailabilityInfo getCarAvailabilityInfo(
      String carId, DateTime startDate, DateTime endDate) {
    final conflictingBookings = _bookings.where((booking) {
      return booking['carId'] == carId &&
          booking['status'] != 'cancelled' &&
          _bookingConflictsWith(booking, startDate, endDate);
    }).toList();

    final maintenanceDates = _carMaintenanceDates[carId] ?? [];
    final blockedDates = _carBlockedDates[carId] ?? [];

    final isAvailable = isCarAvailable(carId, startDate, endDate);

    return CarAvailabilityInfo(
      carId: carId,
      isAvailable: isAvailable,
      conflictingBookings: conflictingBookings,
      maintenanceDates: maintenanceDates,
      blockedDates: blockedDates,
      nextAvailableDate: _getNextAvailableDate(carId, startDate),
    );
  }

  // Get next available date for a car
  DateTime? _getNextAvailableDate(String carId, DateTime fromDate) {
    DateTime checkDate = fromDate;
    const maxDaysToCheck = 90; // Check up to 3 months ahead

    for (int i = 0; i < maxDaysToCheck; i++) {
      if (isCarAvailable(
          carId, checkDate, checkDate.add(const Duration(days: 1)))) {
        return checkDate;
      }
      checkDate = checkDate.add(const Duration(days: 1));
    }

    return null;
  }

  // Add a new booking
  Future<bool> addBooking(dynamic booking) async {
    // Check if the car is available for the booking dates
    if (!isCarAvailable(
        booking['carId'], booking['startDate'], booking['endDate'])) {
      return false;
    }

    // In a real app, this would be a database operation
    _bookings.add(booking);

    // Notify listeners about availability changes
    _updateAvailability();

    return true;
  }

  // Cancel a booking
  Future<bool> cancelBooking(String bookingId) async {
    final bookingIndex =
        _bookings.indexWhere((booking) => booking['id'] == bookingId);

    if (bookingIndex == -1) {
      return false;
    }

    // Update booking status to cancelled
    final booking = _bookings[bookingIndex];
    final updatedBooking = {
      'id': booking['id'],
      'carId': booking['carId'],
      'userId': booking['userId'],
      'hostId': booking['hostId'],
      'startDate': booking['startDate'],
      'endDate': booking['endDate'],
      'totalPrice': booking['totalPrice'],
      'status': 'cancelled',
      'notes': booking['notes'],
      'createdAt': booking['createdAt'],
      'updatedAt': DateTime.now(),
    };

    _bookings[bookingIndex] = updatedBooking;

    // Notify listeners about availability changes
    _updateAvailability();

    return true;
  }

  // Get all bookings for a car
  List<dynamic> getCarBookings(String carId) {
    return _bookings.where((booking) => booking['carId'] == carId).toList();
  }

  // Get upcoming bookings for a car
  List<dynamic> getUpcomingBookings(String carId) {
    final now = DateTime.now();
    return _bookings.where((booking) {
      return booking['carId'] == carId &&
          booking['status'] == 'confirmed' &&
          booking['startDate'].isAfter(now);
    }).toList();
  }

  // Get active bookings for a car
  List<dynamic> getActiveBookings(String carId) {
    return _bookings.where((booking) {
      return booking['carId'] == carId && booking['isActive'];
    }).toList();
  }

  // Add maintenance date
  void addMaintenanceDate(String carId, DateTime date) {
    _carMaintenanceDates[carId] ??= [];
    _carMaintenanceDates[carId]!.add(date);
    _updateAvailability();
  }

  // Remove maintenance date
  void removeMaintenanceDate(String carId, DateTime date) {
    _carMaintenanceDates[carId]?.remove(date);
    _updateAvailability();
  }

  // Add blocked date
  void addBlockedDate(String carId, DateTime date) {
    _carBlockedDates[carId] ??= [];
    _carBlockedDates[carId]!.add(date);
    _updateAvailability();
  }

  // Remove blocked date
  void removeBlockedDate(String carId, DateTime date) {
    _carBlockedDates[carId]?.remove(date);
    _updateAvailability();
  }

  // Update availability and notify listeners
  void _updateAvailability() {
    // In a real app, this would check current bookings and update availability
    // For now, we'll just notify listeners that availability has changed
    notifyListeners();

    // Emit availability stream update
    final allCarIds = <String>{};
    allCarIds.addAll(_bookings.map((b) => b['carId']));
    allCarIds.addAll(_carMaintenanceDates.keys);
    allCarIds.addAll(_carBlockedDates.keys);

    final availability = <String, bool>{};
    for (final carId in allCarIds) {
      // For demo purposes, we'll just emit a simple availability status
      availability[carId] =
          true; // This would be calculated based on current state
    }

    _availabilityController.add(availability);
  }

  // Get availability calendar for a car (next 30 days)
  Map<DateTime, bool> getAvailabilityCalendar(String carId, {int days = 30}) {
    final calendar = <DateTime, bool>{};
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = now.add(Duration(days: i));
      calendar[date] =
          isCarAvailable(carId, date, date.add(const Duration(days: 1)));
    }

    return calendar;
  }

  @override
  void dispose() {
    _availabilityController.close();
    super.dispose();
  }
}

// Detailed availability information for a car
class CarAvailabilityInfo {
  final String carId;
  final bool isAvailable;
  final List<dynamic> conflictingBookings;
  final List<DateTime> maintenanceDates;
  final List<DateTime> blockedDates;
  final DateTime? nextAvailableDate;

  CarAvailabilityInfo({
    required this.carId,
    required this.isAvailable,
    required this.conflictingBookings,
    required this.maintenanceDates,
    required this.blockedDates,
    this.nextAvailableDate,
  });

  String get availabilityMessage {
    if (isAvailable) {
      return 'Available for your selected dates';
    }

    if (conflictingBookings.isNotEmpty) {
      return 'Not available - conflicting bookings';
    }

    if (maintenanceDates.isNotEmpty) {
      return 'Not available - scheduled maintenance';
    }

    if (blockedDates.isNotEmpty) {
      return 'Not available - blocked by host';
    }

    return 'Not available';
  }

  String get nextAvailableMessage {
    if (nextAvailableDate != null) {
      final daysUntilAvailable =
          nextAvailableDate!.difference(DateTime.now()).inDays;
      if (daysUntilAvailable == 0) {
        return 'Available today';
      } else if (daysUntilAvailable == 1) {
        return 'Available tomorrow';
      } else {
        return 'Available in $daysUntilAvailable days';
      }
    }
    return 'No availability in the next 3 months';
  }
}
