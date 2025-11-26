import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// HTTP client with ETag support, conditional requests, and request deduplication
class HttpClient {
  final Dio _dio;
  final Map<String, String> _etags = {};
  final Map<String, DateTime> _lastModified = {};
  final Map<String, Completer<Response>> _inflightRequests = {};

  HttpClient({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? '',
            connectTimeout: connectTimeout ?? const Duration(seconds: 8),
            receiveTimeout: receiveTimeout ?? const Duration(seconds: 15),
          ),
        ) {
    // Add interceptors
    _dio.interceptors.add(_LoggingInterceptor());
    _dio.interceptors.add(_CacheInterceptor(_etags, _lastModified));
  }

  /// GET request with ETag/If-None-Match support
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    bool useCache = true,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final cacheKey = uri.toString();

    // Check for inflight request (deduplication)
    if (_inflightRequests.containsKey(cacheKey)) {
      return _inflightRequests[cacheKey]!.future;
    }

    // Build headers with conditional request
    final requestHeaders = <String, String>{};
    if (headers != null) {
      requestHeaders.addAll(headers);
    }

    if (useCache && _etags.containsKey(cacheKey)) {
      requestHeaders['If-None-Match'] = _etags[cacheKey]!;
    }

    // Create completer for deduplication
    final completer = Completer<Response>();
    _inflightRequests[cacheKey] = completer;

    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(headers: requestHeaders),
        cancelToken: cancelToken,
      );

      // Handle 304 Not Modified
      if (response.statusCode == 304) {
        // Return cached data (would need cache storage here)
        completer.complete(response);
        _inflightRequests.remove(cacheKey);
        return response;
      }

      // Store ETag and Last-Modified
      final etag = response.headers.value('etag');
      final lastModified = response.headers.value('last-modified');
      if (etag != null) {
        _etags[cacheKey] = etag;
      }
      if (lastModified != null) {
        _lastModified[cacheKey] = DateTime.parse(lastModified);
      }

      completer.complete(response);
      _inflightRequests.remove(cacheKey);
      return response;
    } catch (e) {
      _inflightRequests.remove(cacheKey);
      if (e is DioException && e.type == DioExceptionType.cancel) {
        throw Exception('Request cancelled');
      }
      rethrow;
    }
  }

  /// POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    return _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(headers: headers),
      cancelToken: cancelToken,
    );
  }

  /// PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    return _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(headers: headers),
      cancelToken: cancelToken,
    );
  }

  /// DELETE request
  Future<Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    return _dio.delete(
      path,
      queryParameters: queryParameters,
      options: Options(headers: headers),
      cancelToken: cancelToken,
    );
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    final uri = Uri.parse(path);
    if (queryParameters != null) {
      return uri.replace(queryParameters: queryParameters);
    }
    return uri;
  }

  /// Clear cache
  void clearCache() {
    _etags.clear();
    _lastModified.clear();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'etags_count': _etags.length,
      'last_modified_count': _lastModified.length,
      'inflight_requests': _inflightRequests.length,
    };
  }
}

/// Logging interceptor for request/response timing
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final startTime = DateTime.now();
    options.extra['start_time'] = startTime;
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final startTime = response.requestOptions.extra['start_time'] as DateTime?;
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      debugPrint(
          'HTTP ${response.requestOptions.method} ${response.requestOptions.path}: ${duration.inMilliseconds}ms');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final startTime = err.requestOptions.extra['start_time'] as DateTime?;
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      debugPrint(
          'HTTP ERROR ${err.requestOptions.method} ${err.requestOptions.path}: ${duration.inMilliseconds}ms - ${err.message}');
    }
    super.onError(err, handler);
  }
}

/// Cache interceptor for ETag/Last-Modified handling
class _CacheInterceptor extends Interceptor {
  final Map<String, String> _etags;
  final Map<String, DateTime> _lastModified;

  _CacheInterceptor(this._etags, this._lastModified);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add conditional headers if available
    final uri = options.uri.toString();
    if (_etags.containsKey(uri)) {
      options.headers['If-None-Match'] = _etags[uri];
    }
    if (_lastModified.containsKey(uri)) {
      options.headers['If-Modified-Since'] =
          _lastModified[uri]!.toUtc().toIso8601String();
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Store ETag and Last-Modified
    final uri = response.requestOptions.uri.toString();
    final etag = response.headers.value('etag');
    final lastModified = response.headers.value('last-modified');
    if (etag != null) {
      _etags[uri] = etag;
    }
    if (lastModified != null) {
      _lastModified[uri] = DateTime.parse(lastModified);
    }
    super.onResponse(response, handler);
  }
}
