import "dart:async";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";

import "../utils/logger.dart";

/// HTTP Client - DISABLED (Using Supabase Direct)
/// All API calls will immediately fail to force Supabase fallbacks
class ApiClient {
  // Backend API disabled
  static final List<String> _baseUrls = [''];

  static String _currentBaseUrl = _baseUrls.first;

  // Check if backend API is disabled
  static bool get _isBackendDisabled => _currentBaseUrl.isEmpty;

  // Force reset to primary URL on first access
  static void _ensurePrimaryUrl() {
    if (_currentBaseUrl != _baseUrls.first) {
      _currentBaseUrl = _baseUrls.first;
      debugPrint('🔄 API Client: Reset to primary URL: $_currentBaseUrl');
    }
  }

  static String get _baseUrl => _currentBaseUrl;

  static const Duration _timeout =
      Duration(seconds: 10); // Reduced for faster response

  // Cache for API responses
  static final Map<String, _CachedResponse> _cache = {};

  // Dio instance for HTTP communication
  static Dio? _dio;

  // Session management removed (stateless authentication)

  /// Try next fallback URL if current one fails
  static void _tryNextUrl() {
    final currentIndex = _baseUrls.indexOf(_currentBaseUrl);
    debugPrint(
        '🔄 API Client: Current URL index: $currentIndex, Total URLs: ${_baseUrls.length}');
    if (currentIndex < _baseUrls.length - 1) {
      _currentBaseUrl = _baseUrls[currentIndex + 1];
      debugPrint('🔄 API Client switching to fallback URL: $_currentBaseUrl');
      // Reinitialize Dio with new base URL
      _dio = null;
    } else {
      debugPrint(
          '❌ API Client: All URLs exhausted, no more fallbacks available');
    }
  }

  /// Reset to primary URL
  static void _resetToPrimaryUrl() {
    _currentBaseUrl = _baseUrls.first;
    debugPrint('🔄 API Client reset to primary URL: $_currentBaseUrl');
    // Reinitialize Dio with primary URL
    _dio = null;
  }

  /// Initialize Dio client
  static Future<void> _initializeDio() async {
    // Ensure we start with primary URL
    _ensurePrimaryUrl();

    // Always reinitialize to ensure correct base URL
    if (_dio != null) {
      _dio!.close();
      _dio = null;
    }

    debugPrint('🔄 API Client initializing with base URL: $_baseUrl');
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      // Do not throw DioException for non-2xx so we can handle gracefully
      validateStatus: (status) => true,
    ));

    // Add minimal logging interceptor in debug mode
    if (kDebugMode) {
      _dio!.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
        logPrint: (obj) {
          // Only log essential info to reduce noise
          if (obj.toString().contains('*** Request ***') ||
              obj.toString().contains('*** Response ***')) {
            Logger.info("Dio: $obj");
          }
        },
      ));
    }

    Logger.info("✅ Dio client initialized with cookie management");
  }

  /// Set session cookies - NO-OP (session management removed)
  static void setSessionCookies(Map<String, String> cookies) {
    Logger.info('ℹ️ Session cookies ignored (stateless auth)');
  }

  /// Get current session ID - always null (stateless)
  static String? get sessionId => null;

  /// Get current session cookies - always null (stateless)
  static Map<String, String>? get sessionCookies => null;

  /// Set session ID - NO-OP (session management removed)
  static void setSessionId(String? sessionId) {
    Logger.info("ℹ️ Session ID ignored (stateless auth)");
  }

  /// Clear session data - NO-OP (session management removed)
  static void clearSession() {
    Logger.info("ℹ️ Session clear ignored (stateless auth)");
  }

  /// GET request with session support (recommended)
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool useCache = false,
    Duration? cacheDuration,
  }) async {
    // Use session-aware method by default
    return getWithSession(
      endpoint,
      queryParameters: queryParameters,
      useCache: useCache,
      cacheDuration: cacheDuration,
    );
  }

  /// POST request with session support (recommended)
  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? data,
    Map<String, String>? queryParameters,
  }) async {
    // Use session-aware method by default
    return postWithSession(
      endpoint,
      data: data,
      queryParameters: queryParameters,
    );
  }

  /// PUT request with session support (recommended)
  static Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? data,
    Map<String, String>? queryParameters,
  }) async {
    // Use session-aware method by default
    return putWithSession(
      endpoint,
      data: data,
      queryParameters: queryParameters,
    );
  }

  /// DELETE request with session support (recommended)
  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async {
    // Use session-aware method by default
    return deleteWithSession(
      endpoint,
      queryParameters: queryParameters,
    );
  }

  /// Clear cache
  static void clearCache() {
    _cache.clear();
    Logger.info("API cache cleared");
  }

  /// Session-aware GET request using Dio
  static Future<Map<String, dynamic>> getWithSession(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool useCache = false,
    Duration? cacheDuration,
  }) async {
    // Backend API disabled - immediately fail to force Supabase fallback
    if (_isBackendDisabled) {
      Logger.info('🚫 Backend API disabled - use Supabase direct connection');
      return {
        'success': false,
        'error': 'Backend API disabled - use Supabase',
        'statusCode': 503,
      };
    }

    // Ensure we start with primary URL for each request
    _ensurePrimaryUrl();

    for (int attempt = 0; attempt < _baseUrls.length; attempt++) {
      try {
        await _initializeDio();

        final response = await _dio!.get(
          endpoint,
          queryParameters: queryParameters,
        );

        // If successful, reset to primary URL for next requests
        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          if (_currentBaseUrl != _baseUrls.first) {
            _resetToPrimaryUrl();
          }
          return _handleDioResponse(response, endpoint,
              cacheDuration: cacheDuration);
        }

        // If not successful and not the last URL, try next
        if (attempt < _baseUrls.length - 1) {
          Logger.warning(
              "GET request failed with status ${response.statusCode}, trying fallback...");
          _tryNextUrl();
        }
      } on DioException catch (e) {
        Logger.error(
            "Dio GET Error for $endpoint (attempt ${attempt + 1}): $e");
        if (attempt < _baseUrls.length - 1) {
          _tryNextUrl();
        } else {
          return _handleDioError(e, endpoint);
        }
      } on Exception catch (e) {
        Logger.error(
            "Unexpected GET Error for $endpoint (attempt ${attempt + 1}): $e");
        if (attempt < _baseUrls.length - 1) {
          _tryNextUrl();
        } else {
          return _handleGenericError(e, endpoint);
        }
      }
    }

    return _handleGenericError(Exception("All URLs failed"), endpoint);
  }

  /// Session-aware POST request using Dio
  static Future<Map<String, dynamic>> postWithSession(
    String endpoint, {
    Map<String, dynamic>? data,
    Map<String, String>? queryParameters,
  }) async {
    // Backend API disabled - immediately fail to force Supabase fallback
    if (_isBackendDisabled) {
      Logger.info('🚫 Backend API disabled - use Supabase direct connection');
      return {
        'success': false,
        'error': 'Backend API disabled - use Supabase',
        'statusCode': 503,
      };
    }

    // Ensure we start with primary URL for each request
    _ensurePrimaryUrl();

    for (int attempt = 0; attempt < _baseUrls.length; attempt++) {
      try {
        await _initializeDio();

        final response = await _dio!.post(
          endpoint,
          data: data,
          queryParameters: queryParameters,
        );

        // If successful, reset to primary URL for next requests
        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          if (_currentBaseUrl != _baseUrls.first) {
            _resetToPrimaryUrl();
          }
          return _handleDioResponse(response, endpoint);
        }

        // If not successful and not the last URL, try next
        if (attempt < _baseUrls.length - 1) {
          Logger.warning(
              "POST request failed with status ${response.statusCode}, trying fallback...");
          _tryNextUrl();
        }
      } on DioException catch (e) {
        Logger.error(
            "Dio POST Error for $endpoint (attempt ${attempt + 1}): $e");
        if (attempt < _baseUrls.length - 1) {
          _tryNextUrl();
        } else {
          return _handleDioError(e, endpoint);
        }
      } on Exception catch (e) {
        Logger.error(
            "Unexpected POST Error for $endpoint (attempt ${attempt + 1}): $e");
        if (attempt < _baseUrls.length - 1) {
          _tryNextUrl();
        } else {
          return _handleGenericError(e, endpoint);
        }
      }
    }

    return _handleGenericError(Exception("All URLs failed"), endpoint);
  }

  /// Session-aware PUT request using Dio
  static Future<Map<String, dynamic>> putWithSession(
    String endpoint, {
    Map<String, dynamic>? data,
    Map<String, String>? queryParameters,
  }) async {
    // Backend API disabled - immediately fail to force Supabase fallback
    if (_isBackendDisabled) {
      Logger.info('🚫 Backend API disabled - use Supabase direct connection');
      return {
        'success': false,
        'error': 'Backend API disabled - use Supabase',
        'statusCode': 503,
      };
    }

    try {
      await _initializeDio();

      final response = await _dio!.put(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );

      return _handleDioResponse(response, endpoint);
    } on DioException catch (e) {
      Logger.error("Dio PUT Error for $endpoint: $e");
      return _handleDioError(e, endpoint);
    } on Exception catch (e) {
      Logger.error("Unexpected PUT Error for $endpoint: $e");
      return _handleGenericError(e, endpoint);
    }
  }

  /// Session-aware DELETE request using Dio
  static Future<Map<String, dynamic>> deleteWithSession(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async {
    // Backend API disabled - immediately fail to force Supabase fallback
    if (_isBackendDisabled) {
      Logger.info('🚫 Backend API disabled - use Supabase direct connection');
      return {
        'success': false,
        'error': 'Backend API disabled - use Supabase',
        'statusCode': 503,
      };
    }

    try {
      await _initializeDio();

      final response = await _dio!.delete(
        endpoint,
        queryParameters: queryParameters,
      );

      return _handleDioResponse(response, endpoint);
    } on DioException catch (e) {
      Logger.error("Dio DELETE Error for $endpoint: $e");
      return _handleDioError(e, endpoint);
    } on Exception catch (e) {
      Logger.error("Unexpected DELETE Error for $endpoint: $e");
      return _handleGenericError(e, endpoint);
    }
  }

  /// Handle Dio response
  static Map<String, dynamic> _handleDioResponse(
    Response response,
    String endpoint, {
    Duration? cacheDuration,
  }) {
    final Map<String, dynamic> responseData = {
      "statusCode": response.statusCode,
      "success": response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300,
    };

    try {
      final decodedBody = response.data;
      // Reduced logging to prevent terminal spam
      // Logger.info("📋 DIO DECODED RESPONSE BODY: $decodedBody");

      if (decodedBody is Map<String, dynamic>) {
        responseData.addAll(decodedBody);
      } else {
        responseData["data"] = decodedBody;
      }

      // Extract session ID from response if available
      if (decodedBody is Map<String, dynamic>) {
        final sessionId = decodedBody["sessionId"];
        if (sessionId != null) {
          setSessionId(sessionId);
        }
      }

      // Reduced logging to prevent terminal spam
      // Logger.info("📋 DIO FINAL RESPONSE DATA: success=${responseData["success"]}, statusCode=${responseData["statusCode"]}");
    } on Exception catch (e) {
      responseData["error"] = "Failed to parse response";
      Logger.error("❌ DIO Response parsing error for $endpoint: $e");
    }

    // Reduced logging to prevent terminal spam
    // Logger.info("✅ DIO API Response: ${response.statusCode} for $endpoint");
    return responseData;
  }

  /// Handle Dio errors
  static Map<String, dynamic> _handleDioError(
      DioException error, String endpoint) {
    String errorMessage = "Unknown error";
    int statusCode = 500;

    if (error.response != null) {
      statusCode = error.response!.statusCode ?? 500;
      errorMessage =
          error.response!.data?["error"] ?? error.message ?? "Server error";
    } else if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      errorMessage = "Request timeout. Please try again.";
    } else if (error.type == DioExceptionType.connectionError) {
      errorMessage =
          "Network connection error. Please check your internet connection.";
    } else {
      errorMessage = error.message ?? "Unknown error";
    }

    return {
      "success": false,
      "statusCode": statusCode,
      "error": errorMessage,
      "endpoint": endpoint,
    };
  }

  /// Handle generic errors
  static Map<String, dynamic> _handleGenericError(
      Exception error, String endpoint) {
    return {
      "success": false,
      "statusCode": 500,
      "error": "Unexpected error: ${error.toString()}",
      "endpoint": endpoint,
    };
  }

  /// Health check
  static Future<bool> healthCheck() async {
    try {
      final response = await get("/api/business/health");
      return response["success"] == true;
    } on Exception catch (e) {
      Logger.error("Health check failed: $e");
      return false;
    }
  }
}

/// Cached response wrapper
class _CachedResponse {
  const _CachedResponse({
    required this.data,
    required this.expiry,
  });

  final Map<String, dynamic> data;
  final DateTime expiry;
}
