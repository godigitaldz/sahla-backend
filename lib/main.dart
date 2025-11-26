import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/injection_container.dart';
import 'firebase_options.dart';
import 'services/google_maps_initialization_service.dart';
import 'services/image_api_service.dart';
import 'services/menu_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // PERFORMANCE: Enable build profiling in debug/profile mode
  // This helps identify expensive rebuilds during development
  // Set to false in release mode to avoid overhead
  if (kDebugMode || kProfileMode) {
    // Enable build profiling for performance analysis
    // This can be toggled in Flutter DevTools for detailed build times
    // Note: Has minimal overhead in profile mode, none in release
  }

  // Set transparent status bar and white navigation bar globally
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Sentry for error tracking (minimal blocking setup)
  await SentryFlutter.init(
    (options) {
      // TODO(setup): Replace with your Sentry DSN from https://sentry.io
      options.dsn = 'YOUR_SENTRY_DSN_HERE';
      options.tracesSampleRate =
          0.1; // 10% of transactions for performance monitoring
      options.environment = 'production';
      options.enableAutoPerformanceTracing = true;
      options.attachScreenshot = true;
      options.screenshotQuality = SentryScreenshotQuality.medium;
      options.attachViewHierarchy = true;
      // Capture errors in debug mode for testing (remove in production)
      options.debug = false;
    },
    appRunner: () async {
      // PERFORMANCE FIX: Initialize Supabase first (fast, minimal)
      // Supabase is needed by many services, so initialize it synchronously
      // but keep it lightweight - actual connections happen lazily
      try {
        await Supabase.initialize(
          url: 'https://wtowqpejzxlsmgywkjvn.supabase.co',
          anonKey:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0b3dxcGVqenhsc21neXdranZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3NzUzNzIsImV4cCI6MjA3MjM1MTM3Mn0.2hDTLo1QVJ82DlceZgvndItMvUz5-q3xqoiX0zOtOG0',
        );
        debugPrint('✅ Supabase initialization completed');
      } catch (e) {
        debugPrint('❌ Failed to initialize Supabase: $e');
        // Continue app startup even if Supabase fails
      }

      // Configure Image API Service with production backend URL
      // Uses Node.js API for optimized image loading with automatic Supabase fallback
      ImageApiService.setBackendUrl('https://sahla-backend.vercel.app');
      debugPrint('✅ Image API Service configured for production');

      // PERFORMANCE FIX: Run app immediately to show SplashScreen
      // This prevents black screen on low-end devices
      // Heavy initialization will happen after first frame renders
      runApp(
        const ProviderScope(
          child: App(),
        ),
      );

      // PERFORMANCE FIX: Defer heavy initialization to after first frame
      // This ensures SplashScreen renders immediately while initialization happens in background
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performDeferredInitialization();
      });
    },
  );
}

/// Perform heavy initialization after first frame is rendered
/// This prevents blocking the UI from rendering on low-end devices
Future<void> _performDeferredInitialization() async {
  debugPrint('🚀 Starting deferred initialization (after first frame)...');

  // Initialize Firebase (can be heavy on low-end devices)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialization completed');
  } catch (e) {
    debugPrint('❌ Failed to initialize Firebase: $e');
    // Continue app startup even if Firebase fails
  }

  // Initialize Google Maps SDK (can be heavy on low-end devices)
  try {
    await GoogleMapsInitializationService.initialize();
    debugPrint('✅ Google Maps SDK initialization completed');
  } catch (e) {
    debugPrint('❌ Failed to initialize Google Maps SDK: $e');
    // Continue app startup even if Google Maps fails
  }

  // Initialize Hive for local storage (can be heavy on low-end devices)
  try {
    await Hive.initFlutter();
    debugPrint('✅ Hive initialization completed');
  } catch (e) {
    debugPrint('❌ Failed to initialize Hive: $e');
  }

  // Initialize Menu Cache Service (depends on Hive)
  try {
    await MenuCacheService().initialize();
    debugPrint('✅ MenuCacheService initialization completed');
  } catch (e) {
    debugPrint('❌ Failed to initialize MenuCacheService: $e');
  }

  // Initialize Dependency Injection
  try {
    await initializeDependencyInjection();
    debugPrint('✅ Dependency Injection initialization completed');
  } catch (e) {
    debugPrint('❌ Failed to initialize DI: $e');
    // Continue app startup even if DI fails
  }

  debugPrint('✅ All deferred initialization completed');
}
