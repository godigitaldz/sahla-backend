import 'package:flutter/foundation.dart';

class FormAnalytics {
  static void trackFormStep(String stepName) {
    // Track user progress through form steps
    _logEvent('form_step_viewed', {
      'step_name': stepName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackValidationError(String fieldName, String errorType) {
    _logEvent('form_validation_error', {
      'field_name': fieldName,
      'error_type': errorType,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackFormSubmission(String formType,
      {required bool success, String? errorMessage}) {
    _logEvent('form_submission', {
      'form_type': formType,
      'success': success,
      'error_message': errorMessage,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackLocationMethod(String method, {required bool success}) {
    _logEvent('location_method_used', {
      'method': method, // 'gps', 'map', 'url'
      'success': success,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackImageUpload(String imageType,
      {required bool success, String? errorMessage}) {
    _logEvent('image_upload', {
      'image_type': imageType, // 'logo', 'photo'
      'success': success,
      'error_message': errorMessage,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackWorkingHoursConfiguration(String mode, int daysSelected) {
    _logEvent('working_hours_configuration', {
      'mode': mode, // 'common', 'different'
      'days_selected': daysSelected,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackSectorSelection(String sector) {
    _logEvent('sector_selection', {
      'sector': sector,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackFormAbandonment(
      String stepName, Map<String, dynamic> formData) {
    _logEvent('form_abandonment', {
      'step_name': stepName,
      'form_data': formData,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackFormCompletion(String formType, Duration completionTime) {
    _logEvent('form_completion', {
      'form_type': formType,
      'completion_time_seconds': completionTime.inSeconds,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackError(String errorType, String errorMessage,
      {Map<String, dynamic>? context}) {
    _logEvent('form_error', {
      'error_type': errorType,
      'error_message': errorMessage,
      'context': context,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackUserInteraction(String interactionType, String target) {
    _logEvent('user_interaction', {
      'interaction_type': interactionType, // 'tap', 'swipe', 'scroll'
      'target': target,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackPerformanceMetric(
      String metricName, int value, String unit) {
    _logEvent('performance_metric', {
      'metric_name': metricName,
      'value': value,
      'unit': unit,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackAccessibilityEvent(String eventType, String description) {
    _logEvent('accessibility_event', {
      'event_type': eventType,
      'description': description,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackSecurityEvent(String eventType, String description) {
    _logEvent('security_event', {
      'event_type': eventType,
      'description': description,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void _logEvent(String eventName, Map<String, dynamic> parameters) {
    // In a real implementation, this would send data to an analytics service
    // For now, we'll just print to debug console
    debugPrint('📊 Analytics Event: $eventName');
    debugPrint('📊 Parameters: $parameters');

    // Example of how you might integrate with Firebase Analytics:
    // FirebaseAnalytics.instance.logEvent(
    //   name: eventName,
    //   parameters: parameters,
    // );

    // Example of how you might integrate with other analytics services:
    // AnalyticsService.trackEvent(eventName, parameters);
  }
}

class FormPerformanceTracker {
  static final Map<String, DateTime> _startTimes = {};

  static void startTracking(String operation) {
    _startTimes[operation] = DateTime.now();
  }

  static void endTracking(String operation) {
    final startTime = _startTimes[operation];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      FormAnalytics.trackPerformanceMetric(
          operation, duration.inMilliseconds, 'ms');
      _startTimes.remove(operation);
    }
  }

  static void trackFormLoadTime() {
    startTracking('form_load');
  }

  static void trackValidationTime() {
    startTracking('validation');
  }

  static void trackSubmissionTime() {
    startTracking('submission');
  }

  static void trackImageUploadTime() {
    startTracking('image_upload');
  }

  static void trackLocationDetectionTime() {
    startTracking('location_detection');
  }
}
