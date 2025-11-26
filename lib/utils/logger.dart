import 'package:flutter/foundation.dart';

/// Simple logger utility for the favorites service
class Logger {
  static void info(String message) {
    if (kDebugMode) {
      print('ℹ️ [INFO] $message');
    }
  }

  static void error(String message) {
    if (kDebugMode) {
      print('❌ [ERROR] $message');
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      print('⚠️ [WARNING] $message');
    }
  }

  static void debug(String message) {
    if (kDebugMode) {
      print('🐛 [DEBUG] $message');
    }
  }
}
