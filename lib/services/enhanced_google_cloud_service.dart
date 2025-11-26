import 'package:flutter/foundation.dart';

import '../models/menu_item.dart' as models;
import '../models/restaurant.dart';
import 'cloud_natural_language_service.dart' as nlp;
import 'cloud_translation_service.dart';
import 'cloud_vision_service.dart' as vision;

/// Enhanced Google Cloud service integrating multiple APIs for food delivery
class EnhancedGoogleCloudService {
  /// Translate restaurant menu to user's language
  static Future<Map<String, String>> translateMenu({
    required Map<String, String> menuItems,
    required String targetLanguage,
  }) async {
    try {
      debugPrint(
          '🌐 Translating menu with ${menuItems.length} items to $targetLanguage');

      final translatedMenu = <String, String>{};
      final texts = menuItems.values.toList();

      // Batch translate all menu items
      final translations = await CloudTranslationService.translateBatch(
        texts: texts,
        targetLanguage: targetLanguage,
      );

      // Map translations back to menu items
      int index = 0;
      for (final entry in menuItems.entries) {
        final translation = translations[index];
        translatedMenu[entry.key] = translation ?? entry.value;
        index++;
      }

      debugPrint('✅ Menu translation completed');
      return translatedMenu;
    } catch (e) {
      debugPrint('❌ Error translating menu: $e');
      return menuItems; // Return original menu if translation fails
    }
  }

  /// Analyze restaurant image and extract menu items
  static Future<List<models.MenuItem>> analyzeMenuImage({
    required String imageUrl,
    String? targetLanguage,
  }) async {
    try {
      debugPrint('📸 Analyzing menu image: $imageUrl');

      // Extract menu items using Vision API
      final extractedItems =
          await vision.CloudVisionService.extractMenuItems(imageUrl);

      if (extractedItems.isEmpty) {
        debugPrint('⚠️ No menu items extracted from image');
        return [];
      }

      // Translate items if target language is specified
      if (targetLanguage != null && targetLanguage != 'en') {
        final itemNames = extractedItems.map((item) => item.name).toList();
        final translations = await CloudTranslationService.translateBatch(
          texts: itemNames,
          targetLanguage: targetLanguage,
        );

        // Create translated menu items
        final translatedItems = <models.MenuItem>[];
        for (int i = 0; i < extractedItems.length; i++) {
          final originalItem = extractedItems[i];
          final translation = translations[i];

          translatedItems.add(models.MenuItem(
            id: originalItem
                .name, // Use name as ID since MenuItem from vision doesn't have id
            name: translation ?? originalItem.name,
            description: '', // Vision MenuItem doesn't have description
            image: '', // Vision MenuItem doesn't have image
            price: originalItem.price,
            category: '', // Vision MenuItem doesn't have category
            isAvailable: true, // Default to available
            isFeatured: false, // Default to not featured
            preparationTime: 15, // Default preparation time
            rating: 0.0, // Default rating
            reviewCount: 0, // Default review count
            restaurantId: '', // Will be set by caller
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }

        debugPrint(
            '✅ Menu analysis completed with ${translatedItems.length} items');
        return translatedItems;
      }

      debugPrint(
          '✅ Menu analysis completed with ${extractedItems.length} items');
      return extractedItems
          .map((item) => models.MenuItem(
                id: item
                    .name, // Use name as ID since MenuItem from vision doesn't have id
                name: item.name,
                description: '', // Vision MenuItem doesn't have description
                image: '', // Vision MenuItem doesn't have image
                price: item.price,
                category: '', // Vision MenuItem doesn't have category
                isAvailable: true, // Default to available
                isFeatured: false, // Default to not featured
                preparationTime: 15, // Default preparation time
                rating: 0.0, // Default rating
                reviewCount: 0, // Default review count
                restaurantId: '', // Will be set by caller
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ))
          .toList();
    } catch (e) {
      debugPrint('❌ Error analyzing menu image: $e');
      return [];
    }
  }

  /// Analyze restaurant reviews for insights
  static Future<RestaurantInsights> analyzeRestaurantReviews({
    required String restaurantId,
    required List<String> reviews,
  }) async {
    try {
      debugPrint(
          '📊 Analyzing ${reviews.length} reviews for restaurant: $restaurantId');

      // Analyze reviews using Natural Language API
      final insights =
          await nlp.CloudNaturalLanguageService.analyzeRestaurantReviews(
              reviews);

      debugPrint('✅ Review analysis completed');
      return RestaurantInsights(
        restaurantId: restaurantId,
        overallSentiment: insights.overallSentiment,
        sentimentDistribution: insights.sentimentDistribution,
        topMentionedItems: insights.topEntities,
        inappropriateContentCount: insights.inappropriateContentCount,
        totalReviews: reviews.length,
      );
    } catch (e) {
      debugPrint('❌ Error analyzing restaurant reviews: $e');
      return RestaurantInsights(
        restaurantId: restaurantId,
        overallSentiment: const nlp.SentimentResult(
            score: 0.0, magnitude: 0.0, language: 'unknown'),
        sentimentDistribution: {},
        topMentionedItems: [],
        inappropriateContentCount: 0,
        totalReviews: reviews.length,
      );
    }
  }

  /// Moderate restaurant content (images and text)
  static Future<ContentModerationReport> moderateRestaurantContent({
    required String restaurantId,
    required List<String> imageUrls,
    required List<String> textContent,
  }) async {
    try {
      debugPrint('🛡️ Moderating content for restaurant: $restaurantId');

      final report = ContentModerationReport(restaurantId: restaurantId);

      // Moderate images
      for (final imageUrl in imageUrls) {
        final imageModeration =
            await vision.CloudVisionService.moderateContent(imageUrl);
        report.addImageModeration(imageModeration);
      }

      // Moderate text content
      for (final text in textContent) {
        final textModeration =
            await nlp.CloudNaturalLanguageService.moderateText(text);
        report.addTextModeration(textModeration);
      }

      debugPrint('✅ Content moderation completed');
      return report;
    } catch (e) {
      debugPrint('❌ Error moderating restaurant content: $e');
      return ContentModerationReport(restaurantId: restaurantId);
    }
  }

  /// Auto-translate restaurant information
  static Future<Restaurant> translateRestaurantInfo({
    required Restaurant restaurant,
    required String targetLanguage,
  }) async {
    try {
      debugPrint('🌐 Translating restaurant info to $targetLanguage');

      // Translate restaurant name and description
      final nameTranslation = await CloudTranslationService.translateText(
        text: restaurant.name,
        targetLanguage: targetLanguage,
      );

      final descriptionTranslation = restaurant.description.isNotEmpty
          ? await CloudTranslationService.translateText(
              text: restaurant.description,
              targetLanguage: targetLanguage,
            )
          : null;

      // Create translated restaurant
      final translatedRestaurant = Restaurant(
        id: restaurant.id,
        name: nameTranslation ?? restaurant.name,
        description: descriptionTranslation ?? restaurant.description,
        addressLine1: restaurant.addressLine1,
        addressLine2: restaurant.addressLine2,
        city: restaurant.city,
        state: restaurant.state,
        wilaya: restaurant.wilaya,
        latitude: restaurant.latitude,
        longitude: restaurant.longitude,
        phone: restaurant.phone,
        image: restaurant.image,
        rating: restaurant.rating,
        reviewCount: restaurant.reviewCount,
        isOpen: restaurant.isOpen,
        isFeatured: restaurant.isFeatured,
        isVerified: restaurant.isVerified,
        openingHours: restaurant.openingHours,
        deliveryFee: restaurant.deliveryFee,
        minimumOrder: restaurant.minimumOrder,
        estimatedDeliveryTime: restaurant.estimatedDeliveryTime,
        ownerId: restaurant.ownerId,
        createdAt: restaurant.createdAt,
        updatedAt: restaurant.updatedAt,
        logoUrl: restaurant.logoUrl,
      );

      debugPrint('✅ Restaurant translation completed');
      return translatedRestaurant;
    } catch (e) {
      debugPrint('❌ Error translating restaurant info: $e');
      return restaurant; // Return original restaurant if translation fails
    }
  }

  /// Detect food items in restaurant images
  static Future<List<vision.FoodItem>> detectFoodInImages({
    required String restaurantId,
    required List<String> imageUrls,
  }) async {
    try {
      debugPrint(
          '🍽️ Detecting food items in ${imageUrls.length} images for restaurant: $restaurantId');

      final allFoodItems = <vision.FoodItem>[];

      for (final imageUrl in imageUrls) {
        final foodItems =
            await vision.CloudVisionService.detectFoodItems(imageUrl);
        allFoodItems.addAll(foodItems);
      }

      // Remove duplicates and sort by confidence
      final uniqueItems = <String, vision.FoodItem>{};
      for (final item in allFoodItems) {
        final existingItem = uniqueItems[item.name];
        if (existingItem == null || item.confidence > existingItem.confidence) {
          uniqueItems[item.name] = item;
        }
      }

      final sortedItems = uniqueItems.values.toList();
      sortedItems.sort((a, b) => b.confidence.compareTo(a.confidence));

      debugPrint(
          '✅ Food detection completed with ${sortedItems.length} unique items');
      return sortedItems;
    } catch (e) {
      debugPrint('❌ Error detecting food items: $e');
      return [];
    }
  }

  /// Get language-specific restaurant recommendations
  static Future<List<Restaurant>> getLocalizedRecommendations({
    required List<Restaurant> restaurants,
    required String userLanguage,
    required String userLocation,
  }) async {
    try {
      debugPrint('🎯 Getting localized recommendations for $userLanguage');

      final localizedRestaurants = <Restaurant>[];

      for (final restaurant in restaurants) {
        // Translate restaurant info to user's language
        final translatedRestaurant = await translateRestaurantInfo(
          restaurant: restaurant,
          targetLanguage: userLanguage,
        );

        localizedRestaurants.add(translatedRestaurant);
      }

      debugPrint('✅ Localized recommendations completed');
      return localizedRestaurants;
    } catch (e) {
      debugPrint('❌ Error getting localized recommendations: $e');
      return restaurants; // Return original restaurants if translation fails
    }
  }
}

/// Restaurant insights from review analysis
class RestaurantInsights {
  final String restaurantId;
  final nlp.SentimentResult overallSentiment;
  final Map<String, int> sentimentDistribution;
  final List<MapEntry<String, int>> topMentionedItems;
  final int inappropriateContentCount;
  final int totalReviews;

  const RestaurantInsights({
    required this.restaurantId,
    required this.overallSentiment,
    required this.sentimentDistribution,
    required this.topMentionedItems,
    required this.inappropriateContentCount,
    required this.totalReviews,
  });

  /// Get sentiment percentage
  double get positivePercentage {
    final positive = sentimentDistribution['Positive'] ?? 0;
    return totalReviews > 0 ? (positive / totalReviews) * 100 : 0.0;
  }

  double get negativePercentage {
    final negative = sentimentDistribution['Negative'] ?? 0;
    return totalReviews > 0 ? (negative / totalReviews) * 100 : 0.0;
  }

  double get neutralPercentage {
    final neutral = sentimentDistribution['Neutral'] ?? 0;
    return totalReviews > 0 ? (neutral / totalReviews) * 100 : 0.0;
  }

  @override
  String toString() =>
      'RestaurantInsights(restaurantId: $restaurantId, sentiment: ${overallSentiment.sentimentLabel}, totalReviews: $totalReviews)';
}

/// Content moderation report
class ContentModerationReport {
  final String restaurantId;
  final List<vision.ContentModerationResult> imageModerations = [];
  final List<nlp.ContentModerationResult> textModerations = [];

  ContentModerationReport({required this.restaurantId});

  void addImageModeration(vision.ContentModerationResult moderation) {
    imageModerations.add(moderation);
  }

  void addTextModeration(nlp.ContentModerationResult moderation) {
    textModerations.add(moderation);
  }

  /// Check if content is safe
  bool get isContentSafe {
    final imageSafe = imageModerations.every((moderation) => moderation.isSafe);
    final textSafe = textModerations.every((moderation) => moderation.isSafe);
    return imageSafe && textSafe;
  }

  /// Get inappropriate content count
  int get inappropriateContentCount {
    final imageInappropriate =
        imageModerations.where((moderation) => !moderation.isSafe).length;
    final textInappropriate =
        textModerations.where((moderation) => !moderation.isSafe).length;
    return imageInappropriate + textInappropriate;
  }

  @override
  String toString() =>
      'ContentModerationReport(restaurantId: $restaurantId, safe: $isContentSafe, inappropriate: $inappropriateContentCount)';
}
