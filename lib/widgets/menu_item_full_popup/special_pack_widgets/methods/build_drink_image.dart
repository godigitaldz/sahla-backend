import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../models/menu_item.dart';
import '../../../../services/menu_item_image_service.dart';
import '../../../../services/image_api_service.dart';

/// Build drink loading state
Widget buildDrinkLoadingState() {
  return Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    period: const Duration(milliseconds: 1200),
    child: Container(
      color: Colors.white,
    ),
  );
}

/// Build drink placeholder
Widget buildDrinkPlaceholder() {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.grey[300]!,
          Colors.grey[200]!,
        ],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.local_drink,
        size: 45,
        color: Colors.grey[400],
      ),
    ),
  );
}

/// Build default drink image
Widget buildDefaultDrinkImage(
  MenuItem drink,
  SupabaseClient supabase,
) {
  // Create multiple filename variations for smart detection
  final baseName = drink.name.trim();

  // Remove special characters but keep spaces for processing
  final cleanName = baseName.replaceAll(RegExp(r'[^\w\s]'), '');

  // Generate filename variations
  final variations = [
    // Underscore versions
    cleanName.replaceAll(RegExp(r'\s+'), '_'), // Coca_Cola
    cleanName.toLowerCase().replaceAll(RegExp(r'\s+'), '_'), // coca_cola
    // Hyphen versions
    cleanName.replaceAll(RegExp(r'\s+'), '-'), // Coca-Cola
    cleanName.toLowerCase().replaceAll(RegExp(r'\s+'), '-'), // coca-cola
    // Space versions
    cleanName, // Coca Cola
    cleanName.toLowerCase(), // coca cola
  ];

  // Try each variation
  for (final variation in variations) {
    final filename = '$variation.jpg';
    final imageUrl =
        supabase.storage.from('drink_images').getPublicUrl(filename);

    // PERFORMANCE FIX: Add memCacheWidth/memCacheHeight to reduce memory usage
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      memCacheWidth: 216, // 108 * 2 for retina
      memCacheHeight: 264, // 132 * 2 for retina
      fadeInDuration: Duration.zero, // Disable fade for smooth scrolling
      placeholder: (context, url) => buildDrinkLoadingState(),
      errorWidget: (context, url, error) {
        // Try next variation or show placeholder
        if (variation == variations.last) {
          return buildDrinkPlaceholder();
        }
        return buildDrinkPlaceholder();
      },
    );
  }

  return buildDrinkPlaceholder();
}

/// Build drink image with caching support
Widget buildDrinkImage({
  required MenuItem drink,
  required Map<String, String> drinkImageCache,
  required Function(String) onCacheUpdate,
  required SupabaseClient supabase,
}) {
  // Check cache first for fast loading
  if (drinkImageCache.containsKey(drink.id)) {
    final cachedFilename = drinkImageCache[drink.id]!;
    if (cachedFilename == 'custom') {
      // Use custom image from drink.image
      // PERFORMANCE FIX: Add memCacheWidth/memCacheHeight to reduce memory usage
      // Drink cards are 108x132, use 2x for retina displays = 216x264
      return CachedNetworkImage(
        imageUrl: MenuItemImageService().ensureImageUrl(drink.image),
        fit: BoxFit.cover,
        memCacheWidth: 216, // 108 * 2 for retina
        memCacheHeight: 264, // 132 * 2 for retina
        fadeInDuration: Duration.zero, // Disable fade for smooth scrolling
        placeholder: (context, url) => buildDrinkLoadingState(),
        errorWidget: (context, url, error) {
          // Cache was wrong, remove and try default
          onCacheUpdate(drink.id);
          return buildDefaultDrinkImage(drink, supabase);
        },
      );
    } else if (cachedFilename == 'none') {
      // Known to have no image, show placeholder immediately
      return buildDrinkPlaceholder();
    } else {
      // Use cached filename from bucket
      final imageUrl =
          supabase.storage.from('drink_images').getPublicUrl(cachedFilename);
      // PERFORMANCE FIX: Add memCacheWidth/memCacheHeight to reduce memory usage
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        memCacheWidth: 216, // 108 * 2 for retina
        memCacheHeight: 264, // 132 * 2 for retina
        fadeInDuration: Duration.zero, // Disable fade for smooth scrolling
        placeholder: (context, url) => buildDrinkLoadingState(),
        errorWidget: (context, url, error) {
          // Cache was wrong, remove and try again
          onCacheUpdate(drink.id);
          return buildDefaultDrinkImage(drink, supabase);
        },
      );
    }
  }

  // If drink has custom image, try it first
  if (drink.image.isNotEmpty) {
    // PERFORMANCE FIX: Add memCacheWidth/memCacheHeight to reduce memory usage
    return CachedNetworkImage(
      imageUrl: MenuItemImageService().ensureImageUrl(drink.image),
      fit: BoxFit.cover,
      memCacheWidth: 216, // 108 * 2 for retina
      memCacheHeight: 264, // 132 * 2 for retina
      fadeInDuration: Duration.zero, // Disable fade for smooth scrolling
      placeholder: (context, url) => buildDrinkLoadingState(),
      errorWidget: (context, url, error) {
        // Custom image failed, try default
        return buildDefaultDrinkImage(drink, supabase);
      },
      imageBuilder: (context, imageProvider) {
        // Successfully loaded, cache it
        onCacheUpdate(drink.id);
        return Image(
          image: imageProvider,
          fit: BoxFit.cover,
        );
      },
    );
  }

  // No custom image and not in cache - try ImageApiService (Node.js API with Supabase fallback)
  return _buildDrinkImageFromApi(drink, drinkImageCache, onCacheUpdate, supabase);
}

/// Build drink image using ImageApiService when cache is empty
Widget _buildDrinkImageFromApi(
  MenuItem drink,
  Map<String, String> drinkImageCache,
  Function(String) onCacheUpdate,
  SupabaseClient supabase,
) {
  return FutureBuilder<String?>(
    future: ImageApiService().loadImageById(drink.id),
    builder: (context, snapshot) {
      // Show loading state while fetching
      if (snapshot.connectionState == ConnectionState.waiting) {
        return buildDrinkLoadingState();
      }

      // If API returned an image URL, use it
      if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
        final imageUrl = snapshot.data!;

        // Cache the result for future use
        onCacheUpdate(drink.id);
        drinkImageCache[drink.id] = 'custom';

        return CachedNetworkImage(
          imageUrl: MenuItemImageService().ensureImageUrl(imageUrl),
          fit: BoxFit.cover,
          memCacheWidth: 216, // 108 * 2 for retina
          memCacheHeight: 264, // 132 * 2 for retina
          fadeInDuration: Duration.zero, // Disable fade for smooth scrolling
          placeholder: (context, url) => buildDrinkLoadingState(),
          errorWidget: (context, url, error) {
            // API image failed, try default
            return buildDefaultDrinkImage(drink, supabase);
          },
        );
      }

      // API returned no image or failed - fall back to default behavior
      return buildDefaultDrinkImage(drink, supabase);
    },
  );
}
