import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Error severity levels
enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

class ErrorHandlingService {
  // Error types
  static const String networkError = 'network_error';
  static const String serverError = 'server_error';
  static const String dataError = 'data_error';
  static const String authError = 'auth_error';
  static const String unknownError = 'unknown_error';

  // Handle error
  void handleError(String error, {String? context}) {
    debugPrint('Error handled: $error${context != null ? ' in $context' : ''}');
  }

  // Get error statistics
  Map<String, dynamic> getErrorStats() {
    return {
      'totalErrors': 0,
      'errorTypes': {},
    };
  }

  // Clear error statistics
  void clearStats() {
    debugPrint('Error stats cleared');
  }

  // Get user-friendly error message
  static String getErrorMessage(String errorType, {String? customMessage}) {
    switch (errorType) {
      case networkError:
        return customMessage ??
            'No internet connection. Please check your network and try again.';
      case serverError:
        return customMessage ??
            'Server is temporarily unavailable. Please try again later.';
      case dataError:
        return customMessage ??
            'Unable to load data. Please refresh and try again.';
      case authError:
        return customMessage ?? 'Authentication failed. Please log in again.';
      case unknownError:
        return customMessage ?? 'Something went wrong. Please try again.';
      default:
        return customMessage ??
            'An unexpected error occurred. Please try again.';
    }
  }

  // Get error icon
  static IconData getErrorIcon(String errorType) {
    switch (errorType) {
      case networkError:
        return LucideIcons.wifiOff;
      case serverError:
        return LucideIcons.server;
      case dataError:
        return LucideIcons.database;
      case authError:
        return LucideIcons.lock;
      case unknownError:
        return LucideIcons.alertCircle;
      default:
        return LucideIcons.alertTriangle;
    }
  }

  // Get error color
  static Color getErrorColor(String errorType) {
    switch (errorType) {
      case networkError:
        return Colors.orange;
      case serverError:
        return Colors.red;
      case dataError:
        return Colors.blue;
      case authError:
        return Colors.purple;
      case unknownError:
        return Colors.grey;
      default:
        return Colors.red;
    }
  }

  // Build error widget
  static Widget buildErrorWidget({
    required String errorType,
    required VoidCallback onRetry,
    String? customMessage,
    String? customTitle,
    bool showRetryButton = true,
    bool showIcon = true,
    double? width,
    double? height,
  }) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: getErrorColor(errorType).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                getErrorIcon(errorType),
                size: 40,
                color: getErrorColor(errorType),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            customTitle ?? _getErrorTitle(errorType),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            getErrorMessage(errorType, customMessage: customMessage),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (showRetryButton) ...[
            const SizedBox(height: 24),
            _buildRetryButton(onRetry, errorType),
          ],
        ],
      ),
    );
  }

  // Build retry button
  static Widget _buildRetryButton(VoidCallback onRetry, String errorType) {
    return ElevatedButton.icon(
      onPressed: onRetry,
      icon: const Icon(LucideIcons.refreshCw, size: 16),
      label: Text(
        'Try Again',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: getErrorColor(errorType),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Get error title
  static String _getErrorTitle(String errorType) {
    switch (errorType) {
      case networkError:
        return 'No Connection';
      case serverError:
        return 'Server Error';
      case dataError:
        return 'Data Error';
      case authError:
        return 'Authentication Error';
      case unknownError:
        return 'Something Went Wrong';
      default:
        return 'Error';
    }
  }

  // Build loading error widget
  static Widget buildLoadingErrorWidget({
    required String errorType,
    required VoidCallback onRetry,
    String? customMessage,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: getErrorColor(errorType).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              getErrorIcon(errorType),
              size: 24,
              color: getErrorColor(errorType),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getErrorTitle(errorType),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  getErrorMessage(errorType, customMessage: customMessage),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onRetry,
            icon: Icon(
              LucideIcons.refreshCw,
              color: getErrorColor(errorType),
              size: 20,
            ),
            tooltip: 'Retry',
          ),
        ],
      ),
    );
  }

  // Build empty state widget
  static Widget buildEmptyStateWidget({
    required String title,
    required String message,
    required IconData icon,
    Color? iconColor,
    VoidCallback? onAction,
    String? actionText,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: (iconColor ?? Colors.grey).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: iconColor ?? Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionText != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF593CFB),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                actionText,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Show error snackbar
  static void showErrorSnackBar(
    BuildContext context,
    String errorType, {
    String? customMessage,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              getErrorIcon(errorType),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                getErrorMessage(errorType, customMessage: customMessage),
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: getErrorColor(errorType),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Show success snackbar
  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              LucideIcons.checkCircle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Handle async errors with retry mechanism
  static Future<T> handleAsyncError<T>({
    required Future<T> Function() operation,
    required String errorType,
    required BuildContext context,
    String? customMessage,
    int maxRetries = 3,
  }) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        retryCount++;

        if (retryCount >= maxRetries) {
          // Show final error
          if (context.mounted) {
            showErrorSnackBar(context, errorType, customMessage: customMessage);
          }
          rethrow;
        } else {
          // Show retry message
          if (context.mounted) {
            showErrorSnackBar(
              context,
              errorType,
              customMessage: 'Retrying... ($retryCount/$maxRetries)',
              duration: const Duration(seconds: 2),
            );
          }

          // Wait before retry
          await Future.delayed(Duration(seconds: retryCount));
        }
      }
    }

    throw Exception('Operation failed after $maxRetries retries');
  }

  // Build network error widget
  static Widget buildNetworkErrorWidget({
    required VoidCallback onRetry,
    String? customMessage,
  }) {
    return buildErrorWidget(
      errorType: networkError,
      onRetry: onRetry,
      customMessage: customMessage,
    );
  }

  // Build server error widget
  static Widget buildServerErrorWidget({
    required VoidCallback onRetry,
    String? customMessage,
  }) {
    return buildErrorWidget(
      errorType: serverError,
      onRetry: onRetry,
      customMessage: customMessage,
    );
  }

  // Build data error widget
  static Widget buildDataErrorWidget({
    required VoidCallback onRetry,
    String? customMessage,
  }) {
    return buildErrorWidget(
      errorType: dataError,
      onRetry: onRetry,
      customMessage: customMessage,
    );
  }
}
