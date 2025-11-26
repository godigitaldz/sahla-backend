import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/error_logging_service.dart';
import '../../services/geolocation_service.dart';

/// Widget that provides direct access to GeolocationService functionality
class GeolocationServiceWidget extends StatefulWidget {
  final Widget child;
  final bool showDebugInfo;
  final VoidCallback? onLocationUpdate;
  final Function(String)? onError;

  const GeolocationServiceWidget({
    required this.child,
    super.key,
    this.showDebugInfo = false,
    this.onLocationUpdate,
    this.onError,
  });

  @override
  State<GeolocationServiceWidget> createState() =>
      _GeolocationServiceWidgetState();
}

class _GeolocationServiceWidgetState extends State<GeolocationServiceWidget> {
  late GeolocationService _geolocationService;
  late ErrorLoggingService _errorLogger;
  StreamSubscription<LocationData>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize services asynchronously to prevent blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  void _initializeServices() {
    try {
      _geolocationService =
          Provider.of<GeolocationService>(context, listen: false);
      _errorLogger = Provider.of<ErrorLoggingService>(context, listen: false);

      // Log service initialization (asynchronously to prevent blocking)
      Future.microtask(() {
        try {
          _errorLogger.logInfo(
            'GeolocationServiceWidget initialized',
            context: 'GeolocationServiceWidget._initializeServices',
            additionalData: {
              'show_debug_info': widget.showDebugInfo,
            },
          );
        } catch (e) {
          // Ignore logging errors to prevent blocking
        }
      });

      // Start listening to location updates if callback provided (asynchronously)
      if (widget.onLocationUpdate != null) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _startLocationUpdates();
          }
        });
      }
    } catch (e) {
      debugPrint(
          '❌ GeolocationServiceWidget: Failed to initialize services: $e');
      widget.onError?.call('Failed to initialize location service: $e');
    }
  }

  void _startLocationUpdates() {
    try {
      _locationSubscription = _geolocationService.locationStream.listen(
        (locationData) {
          // Location update received
          widget.onLocationUpdate?.call();

          // Log location update (asynchronously to prevent blocking)
          Future.microtask(() {
            try {
              _errorLogger.logInfo(
                'Location update received',
                context: 'GeolocationServiceWidget._startLocationUpdates',
                additionalData: {
                  'latitude': locationData.latitude,
                  'longitude': locationData.longitude,
                  'accuracy': locationData.accuracy,
                },
              );
            } catch (e) {
              // Ignore logging errors to prevent blocking
            }
          });
        },
        onError: (error) {
          // Handle location update error silently
          widget.onError?.call('Location update error: $error');

          // Log location error
          _errorLogger.logError(
            'Location update error',
            context: 'GeolocationServiceWidget._startLocationUpdates',
            additionalData: {
              'error': error.toString(),
            },
          );
        },
      );
    } catch (e) {
      // Handle location updates error silently
      widget.onError?.call('Failed to start location updates: $e');
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();

    // Log widget disposal
    _errorLogger.logInfo(
      'GeolocationServiceWidget disposed',
      context: 'GeolocationServiceWidget.dispose',
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GeolocationService>(
      builder: (context, geolocationService, child) {
        return Stack(
          children: [
            widget.child,

            // Debug info overlay
            if (widget.showDebugInfo)
              Positioned(
                top: 50.h,
                right: 16.w,
                child: _buildDebugInfo(geolocationService),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDebugInfo(GeolocationService geolocationService) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'GeolocationService Debug',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8.h),

          // Performance metrics
          Consumer<ErrorLoggingService>(
            builder: (context, errorLogger, child) {
              final metrics = geolocationService.getPerformanceMetrics();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cache: ${metrics['cache_stats']['total_entries']} entries',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'Stream: ${metrics['is_location_stream_active'] ? 'Active' : 'Inactive'}',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'Status: ${metrics['service_status']}',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: Colors.white70,
                    ),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: 8.h),

          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => geolocationService.logPerformanceMetrics(),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    'Log Metrics',
                    style: GoogleFonts.inter(
                      fontSize: 8.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => geolocationService.clearGeocodingCache(),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    'Clear Cache',
                    style: GoogleFonts.inter(
                      fontSize: 8.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Convenience widget for wrapping screens with GeolocationService
class GeolocationServiceWrapper extends StatelessWidget {
  final Widget child;
  final bool enableDebugMode;
  final VoidCallback? onLocationUpdate;
  final Function(String)? onError;

  const GeolocationServiceWrapper({
    required this.child,
    super.key,
    this.enableDebugMode = false,
    this.onLocationUpdate,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return GeolocationServiceWidget(
      showDebugInfo: enableDebugMode,
      onLocationUpdate: onLocationUpdate,
      onError: onError,
      child: child,
    );
  }
}

/// Widget for displaying GeolocationService status
class GeolocationServiceStatusWidget extends StatelessWidget {
  const GeolocationServiceStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GeolocationService>(
      builder: (context, geolocationService, child) {
        final metrics = geolocationService.getPerformanceMetrics();
        final cacheStats = metrics['cache_stats'] as Map<String, int>;

        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Colors.orange,
                    size: 20.w,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Location Service Status',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                'Cache Entries: ${cacheStats['total_entries']}',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Stream Status: ${metrics['is_location_stream_active'] ? 'Active' : 'Inactive'}',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Service Status: ${metrics['service_status']}',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
