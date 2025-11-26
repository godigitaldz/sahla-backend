import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager for review images with LRU eviction.
/// Configured with 512MB max cache size and 30-day max age.
class ReviewImageCacheManager {
  static const key = 'reviewImageCache';

  static CacheManager get instance => CacheManager(
        Config(
          key,
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 1000,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileSystem: IOFileSystem(key),
          fileService: HttpFileService(),
        ),
      );
}

