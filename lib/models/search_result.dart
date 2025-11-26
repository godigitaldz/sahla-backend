import '../services/performance_monitoring_service.dart';

/// 🔍 Enhanced Search Result Model for Smart Search with Adaptive Loading
class SearchResult {
  final String id;
  final SearchResultType type;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final double? price;
  final double? rating;
  final double? distance;
  final double? discount;
  final bool isAvailable;
  final Map<String, dynamic>? data;

  // Scoring
  final double relevanceScore;
  double finalScore = 0.0;

  // Performance optimization fields
  final DateTime? _lastImageLoadTime;
  final String? _cachedImageUrl;
  final bool _isImageOptimized;
  final int _searchRank;
  final double _loadPriority;

  SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.price,
    this.rating,
    this.distance,
    this.discount,
    this.isAvailable = true,
    this.data,
    this.relevanceScore = 0.0,
    DateTime? lastImageLoadTime,
    String? cachedImageUrl,
    bool isImageOptimized = false,
    int searchRank = 0,
    double loadPriority = 1.0,
  })  : _lastImageLoadTime = lastImageLoadTime,
        _cachedImageUrl = cachedImageUrl,
        _isImageOptimized = isImageOptimized,
        _searchRank = searchRank,
        _loadPriority = loadPriority;

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    // Start performance monitoring for search result parsing
    final performanceService = PerformanceMonitoringService();
    performanceService.startOperation('search_result_parsing');

    try {
      final searchResult = SearchResult(
        id: json['id'] ?? '',
        type: SearchResultType.values.firstWhere(
          (e) => e.toString().split('.').last == json['type'],
          orElse: () => SearchResultType.restaurant,
        ),
        title: json['title'] ?? '',
        subtitle: json['subtitle'] ?? '',
        imageUrl: json['image_url'],
        price: json['price']?.toDouble(),
        rating: json['rating']?.toDouble(),
        distance: json['distance']?.toDouble(),
        discount: json['discount']?.toDouble(),
        isAvailable: json['is_available'] ?? true,
        data: json['data'],
        relevanceScore: json['relevance_score']?.toDouble() ?? 0.0,
        lastImageLoadTime: DateTime.now(),
        cachedImageUrl: json['image_url'],
        isImageOptimized: false,
        searchRank: json['search_rank'] ?? 0,
        loadPriority: json['load_priority']?.toDouble() ?? 1.0,
      );

      performanceService.endOperation('search_result_parsing');
      return searchResult;
    } catch (e) {
      performanceService.endOperation('search_result_parsing');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    // Start performance monitoring for search result serialization
    final performanceService = PerformanceMonitoringService();
    performanceService.startOperation('search_result_serialization');

    try {
      final json = {
        'id': id,
        'type': type.toString().split('.').last,
        'title': title,
        'subtitle': subtitle,
        'image_url': imageUrl,
        'price': price,
        'rating': rating,
        'distance': distance,
        'discount': discount,
        'is_available': isAvailable,
        'data': data,
        'relevance_score': relevanceScore,
        'final_score': finalScore,
        // Performance optimization fields excluded from serialization
        // These are client-side only fields for tracking search result performance
      };

      performanceService.endOperation('search_result_serialization');
      return json;
    } catch (e) {
      performanceService.endOperation('search_result_serialization');
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// Get optimized image URL based on network conditions
  String? getOptimizedImageUrl(String networkQuality) {
    // Use cached URL if available and recent
    if (_cachedImageUrl != null &&
        _lastImageLoadTime != null &&
        DateTime.now().difference(_lastImageLoadTime).inMinutes < 30) {
      return _cachedImageUrl;
    }

    // Return appropriate image based on network quality and search rank
    switch (networkQuality) {
      case 'fast':
        return imageUrl;
      case 'moderate':
        return _searchRank <= 5 ? imageUrl : null; // Only top 5 results
      case 'slow':
        return _searchRank <= 3 ? imageUrl : null; // Only top 3 results
      case 'verySlow':
        return _searchRank <= 1 ? imageUrl : null; // Only top result
      case 'offline':
        return _cachedImageUrl; // Use cached version when offline
      default:
        return imageUrl;
    }
  }

  /// Check if image should be loaded based on network conditions
  bool shouldLoadImage(String networkQuality) {
    switch (networkQuality) {
      case 'offline':
        return _cachedImageUrl != null;
      case 'verySlow':
        return _searchRank <= 1; // Only top result
      case 'slow':
        return _searchRank <= 3; // Top 3 results
      case 'moderate':
        return _searchRank <= 5; // Top 5 results
      default:
        return imageUrl != null;
    }
  }

  /// Get adaptive cache duration based on network quality
  Duration getAdaptiveCacheDuration(String networkQuality) {
    switch (networkQuality) {
      case 'fast':
        return const Duration(hours: 2);
      case 'moderate':
        return const Duration(hours: 1);
      case 'slow':
        return const Duration(minutes: 30);
      case 'verySlow':
        return const Duration(minutes: 15);
      case 'offline':
        return const Duration(hours: 24);
      default:
        return const Duration(hours: 1);
    }
  }

  /// Calculate load priority based on search rank and network conditions
  double calculateLoadPriority(String networkQuality) {
    double basePriority = _loadPriority;

    // Adjust priority based on search rank
    if (_searchRank <= 3) {
      basePriority *= 2.0; // High priority for top 3
    } else if (_searchRank <= 10) {
      basePriority *= 1.5; // Medium priority for top 10
    }

    // Adjust based on network quality
    switch (networkQuality) {
      case 'fast':
        return basePriority;
      case 'moderate':
        return basePriority * 0.8;
      case 'slow':
        return basePriority * 0.6;
      case 'verySlow':
        return basePriority * 0.4;
      case 'offline':
        return basePriority * 0.2;
      default:
        return basePriority;
    }
  }

  /// Check if this result should be prioritized for loading
  bool shouldPrioritizeLoading(String networkQuality) {
    final priority = calculateLoadPriority(networkQuality);
    return priority >= 1.0;
  }

  /// Get performance metrics for this search result
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'search_rank': _searchRank,
      'load_priority': _loadPriority,
      'is_image_optimized': _isImageOptimized,
      'last_image_load_time': _lastImageLoadTime?.toIso8601String(),
      'has_cached_image': _cachedImageUrl != null,
      'relevance_score': relevanceScore,
      'final_score': finalScore,
    };
  }

  /// Update search result with new performance data
  SearchResult updatePerformanceData({
    String? newCachedUrl,
    bool? optimized,
    int? newSearchRank,
    double? newLoadPriority,
  }) {
    return SearchResult(
      id: id,
      type: type,
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
      price: price,
      rating: rating,
      distance: distance,
      discount: discount,
      isAvailable: isAvailable,
      data: data,
      relevanceScore: relevanceScore,
      lastImageLoadTime: DateTime.now(),
      cachedImageUrl: newCachedUrl ?? _cachedImageUrl,
      isImageOptimized: optimized ?? _isImageOptimized,
      searchRank: newSearchRank ?? _searchRank,
      loadPriority: newLoadPriority ?? _loadPriority,
    );
  }
}

enum SearchResultType {
  restaurant,
  menuItem,
  category,
  deal,
}
