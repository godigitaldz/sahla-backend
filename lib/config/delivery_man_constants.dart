import 'package:flutter/material.dart';

class DeliveryManConstants {
  static const primaryColor = Color(0xFFd47b00);
  static const minVehicleYear = 1990;
  static const maxPhoneLength = 15;

  static const List<String> vehicleTypes = [
    'Motorcycle',
    'Bicycle',
    'Car',
    'Scooter',
    'E-bike',
  ];

  static const List<String> availabilityOptions = [
    'Full-time',
    'Part-time',
    'Weekends only',
    'Evenings only',
    'Flexible',
  ];

  // Error messages
  static const Map<String, String> errorMessages = {
    'network_error': 'Please check your internet connection',
    'server_error': 'Service temporarily unavailable. Please try again later',
    'duplicate_application': 'You have already submitted an application',
    'invalid_phone': 'Please enter a valid phone number',
    'invalid_year': 'Please enter a valid year (1990-2030)',
    'missing_license': 'You must have a valid driving license',
    'missing_vehicle': 'You must have a reliable vehicle',
  };

  // Dynamic error messages that need runtime values
  static String getInvalidYearError() {
    return 'Please enter a valid year (1990-${DateTime.now().year + 1})';
  }
}
