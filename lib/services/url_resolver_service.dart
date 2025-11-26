import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class UrlResolverService {
  static final UrlResolverService _instance = UrlResolverService._internal();
  factory UrlResolverService() => _instance;
  UrlResolverService._internal();

  // Cache for resolved URLs to avoid repeated requests
  final Map<String, String> _resolvedUrls = {};

  /// Resolves shortened URLs to their full Google Maps URLs
  Future<String?> resolveGoogleMapsUrl(String shortUrl) async {
    try {
      // Check cache first
      if (_resolvedUrls.containsKey(shortUrl)) {
        debugPrint('Using cached URL: ${_resolvedUrls[shortUrl]}');
        return _resolvedUrls[shortUrl];
      }

      debugPrint('Resolving URL: $shortUrl');

      // Handle different shortened URL services
      if (shortUrl.contains('goo.gl') ||
          shortUrl.contains('maps.app.goo.gl') ||
          shortUrl.contains('bit.ly') ||
          shortUrl.contains('tinyurl.com') ||
          shortUrl.contains('t.co')) {
        final resolvedUrl = await _resolveShortenedUrl(shortUrl);
        if (resolvedUrl != null) {
          // Cache the resolved URL
          _resolvedUrls[shortUrl] = resolvedUrl;
          debugPrint('Successfully resolved: $resolvedUrl');
          return resolvedUrl;
        }
      }

      // If it's already a full Google Maps URL, return as is
      if (shortUrl.contains('maps.google.com') ||
          shortUrl.contains('google.com/maps')) {
        _resolvedUrls[shortUrl] = shortUrl;
        return shortUrl;
      }

      debugPrint('Could not resolve URL: $shortUrl');
      return null;
    } catch (e) {
      debugPrint('Error resolving URL: $e');
      return null;
    }
  }

  /// Resolves shortened URLs using HTTP client
  Future<String?> _resolveShortenedUrl(String shortUrl) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      try {
        final request = await client.getUrl(Uri.parse(shortUrl));
        request.headers.set('User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36');
        request.headers.set('Accept',
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8');
        request.headers.set('Accept-Language', 'en-US,en;q=0.5');
        request.headers.set('Accept-Encoding', 'gzip, deflate');
        request.headers.set('Connection', 'keep-alive');
        request.headers.set('Upgrade-Insecure-Requests', '1');

        final response = await request.close();

        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response headers: ${response.headers}');

        // Handle redirects
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final locationHeader = response.headers.value('location');
          if (locationHeader != null) {
            debugPrint('Found redirect location: $locationHeader');
            return _cleanUrl(locationHeader);
          }
        }

        // Try to extract from HTML content for JavaScript redirects
        if (response.statusCode == 200) {
          final htmlContent = await response.transform(utf8.decoder).join();
          debugPrint('HTML content length: ${htmlContent.length}');

          // Look for Google Maps URLs in the HTML content
          final googleMapsPattern = RegExp(
              r'https://maps\.google\.com[^\s"<>]*|https://www\.google\.com/maps[^\s"<>]*');
          final match = googleMapsPattern.firstMatch(htmlContent);
          if (match != null) {
            final extractedUrl = match.group(0);
            if (extractedUrl != null) {
              final cleanedUrl = _cleanUrl(extractedUrl);
              debugPrint('Extracted URL from HTML: $cleanedUrl');
              return cleanedUrl;
            }
          }
        }

        debugPrint('Could not resolve shortened URL');
        return null;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Error resolving shortened URL: $e');
      return null;
    }
  }

  /// Cleans and normalizes URLs
  String _cleanUrl(String url) {
    var cleaned = url;
    // Remove any JavaScript or HTML artifacts
    cleaned = cleaned.replaceAll(RegExp('javascript:'), '');

    // Remove quotes from start and end
    if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    if (cleaned.startsWith("'") && cleaned.endsWith("'")) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }

    cleaned = cleaned.trim();

    // Ensure it's a proper URL
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'https://$cleaned';
    }

    return cleaned;
  }

  /// Check if URL is a shortened URL that needs resolution
  bool isShortenedUrl(String url) {
    return url.contains('goo.gl') ||
        url.contains('maps.app.goo.gl') ||
        url.contains('bit.ly') ||
        url.contains('tinyurl.com') ||
        url.contains('t.co') ||
        url.contains('short.link') ||
        url.contains('is.gd') ||
        url.contains('v.gd');
  }

  /// Check if URL is a valid Google Maps URL
  bool isGoogleMapsUrl(String url) {
    return url.contains('maps.google.com') ||
        url.contains('google.com/maps') ||
        url.contains('maps.apple.com') ||
        url.contains('maps.app.goo.gl');
  }

  /// Clear the URL cache
  void clearCache() {
    _resolvedUrls.clear();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_urls': _resolvedUrls.length,
      'cached_urls_list': _resolvedUrls.keys.toList(),
    };
  }
}
