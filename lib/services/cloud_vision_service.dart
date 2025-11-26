import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Google Cloud Vision API service for image analysis
class CloudVisionService {
  static const String _baseUrl =
      'https://vision.googleapis.com/v1/images:annotate';
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Extract text from image using OCR
  static Future<List<String>> extractTextFromImage(String imageUrl) async {
    try {
      final requestBody = {
        'requests': [
          {
            'image': {
              'source': {
                'imageUri': imageUrl,
              },
            },
            'features': [
              {
                'type': 'TEXT_DETECTION',
                'maxResults': 10,
              },
            ],
          },
        ],
      };

      final uri = Uri.parse('$_baseUrl?key=$_apiKey');

      debugPrint('👁️ Extracting text from image: $imageUrl');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['responses'] != null && data['responses'].isNotEmpty) {
          final response = data['responses'][0];

          if (response['textAnnotations'] != null) {
            final textAnnotations = response['textAnnotations'] as List;
            final extractedTexts = textAnnotations
                .map((annotation) => annotation['description'] as String)
                .toList();

            debugPrint('✅ Extracted ${extractedTexts.length} text elements');
            return extractedTexts;
          }
        }
      } else {
        debugPrint('❌ Vision API error: ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error extracting text from image: $e');
    }

    return [];
  }

  /// Detect food items in image
  static Future<List<FoodItem>> detectFoodItems(String imageUrl) async {
    try {
      final requestBody = {
        'requests': [
          {
            'image': {
              'source': {
                'imageUri': imageUrl,
              },
            },
            'features': [
              {
                'type': 'LABEL_DETECTION',
                'maxResults': 20,
              },
            ],
          },
        ],
      };

      final uri = Uri.parse('$_baseUrl?key=$_apiKey');

      debugPrint('🍽️ Detecting food items in image: $imageUrl');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['responses'] != null && data['responses'].isNotEmpty) {
          final response = data['responses'][0];

          if (response['labelAnnotations'] != null) {
            final labelAnnotations = response['labelAnnotations'] as List;

            // Filter for food-related labels
            final foodLabels = labelAnnotations
                .where(
                    (label) => _isFoodRelated(label['description'] as String))
                .map((label) => FoodItem(
                      name: label['description'] as String,
                      confidence: (label['score'] as double) * 100,
                    ))
                .toList();

            debugPrint('✅ Detected ${foodLabels.length} food items');
            return foodLabels;
          }
        }
      } else {
        debugPrint('❌ Vision API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error detecting food items: $e');
    }

    return [];
  }

  /// Extract menu items from menu image
  static Future<List<MenuItem>> extractMenuItems(String imageUrl) async {
    try {
      // First extract text using OCR
      final extractedTexts = await extractTextFromImage(imageUrl);

      if (extractedTexts.isEmpty) {
        return [];
      }

      // Parse the extracted text to find menu items
      final menuItems = <MenuItem>[];

      for (final text in extractedTexts) {
        final lines = text.split('\n');

        for (final line in lines) {
          final trimmedLine = line.trim();

          // Look for patterns like "Item Name - Price" or "Item Name Price"
          final pricePattern =
              RegExp(r'[\d,]+\.?\d*\s*(DA|دج|دينار)', caseSensitive: false);
          final priceMatch = pricePattern.firstMatch(trimmedLine);

          if (priceMatch != null) {
            final price = priceMatch.group(0);
            final itemName = trimmedLine.replaceAll(price!, '').trim();

            if (itemName.isNotEmpty) {
              menuItems.add(MenuItem(
                name: itemName,
                price: _parsePrice(price),
                confidence: 0.8, // Default confidence for parsed items
              ));
            }
          }
        }
      }

      debugPrint('✅ Extracted ${menuItems.length} menu items');
      return menuItems;
    } catch (e) {
      debugPrint('❌ Error extracting menu items: $e');
      return [];
    }
  }

  /// Detect if a label is food-related
  static bool _isFoodRelated(String label) {
    final foodKeywords = [
      'food',
      'dish',
      'meal',
      'cuisine',
      'restaurant',
      'cooking',
      'pizza',
      'burger',
      'sandwich',
      'salad',
      'soup',
      'pasta',
      'chicken',
      'beef',
      'fish',
      'vegetable',
      'fruit',
      'dessert',
      'bread',
      'rice',
      'noodle',
      'sauce',
      'spice',
      'herb',
      'طعام',
      'أكل',
      'وجبة',
      'مطعم',
      'طبخ',
      'بيتزا',
      'برجر',
      'سلطة',
      'شوربة',
      'معكرونة',
      'دجاج',
      'لحم',
      'سمك',
      'خضار',
      'فاكهة',
      'حلوى',
      'خبز',
      'أرز',
      'صلصة',
      'nourriture',
      'repas',
      'cuisine',
      'restaurant',
      'cuisson',
      'pizza',
      'burger',
      'salade',
      'soupe',
      'pâtes',
      'poulet',
      'bœuf',
      'poisson',
      'légume',
      'fruit',
      'dessert',
      'pain',
      'riz',
      'sauce',
      'épice',
      'herbe',
    ];

    final lowerLabel = label.toLowerCase();
    return foodKeywords.any((keyword) => lowerLabel.contains(keyword));
  }

  /// Parse price from text
  static double _parsePrice(String priceText) {
    try {
      // Remove currency symbols and extract numbers
      final cleanPrice = priceText.replaceAll(RegExp(r'[^\d,.]'), '');
      final price = double.parse(cleanPrice.replaceAll(',', ''));
      return price;
    } catch (e) {
      debugPrint('❌ Error parsing price: $priceText');
      return 0.0;
    }
  }

  /// Analyze image for content moderation
  static Future<ContentModerationResult> moderateContent(
      String imageUrl) async {
    try {
      final requestBody = {
        'requests': [
          {
            'image': {
              'source': {
                'imageUri': imageUrl,
              },
            },
            'features': [
              {
                'type': 'SAFE_SEARCH_DETECTION',
                'maxResults': 1,
              },
            ],
          },
        ],
      };

      final uri = Uri.parse('$_baseUrl?key=$_apiKey');

      debugPrint('🛡️ Moderating content in image: $imageUrl');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['responses'] != null && data['responses'].isNotEmpty) {
          final response = data['responses'][0];

          if (response['safeSearchAnnotation'] != null) {
            final safeSearch = response['safeSearchAnnotation'];

            return ContentModerationResult(
              adult: _getLikelihood(safeSearch['adult']),
              violence: _getLikelihood(safeSearch['violence']),
              racy: _getLikelihood(safeSearch['racy']),
              spoof: _getLikelihood(safeSearch['spoof']),
              medical: _getLikelihood(safeSearch['medical']),
            );
          }
        }
      } else {
        debugPrint('❌ Vision API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error moderating content: $e');
    }

    return const ContentModerationResult();
  }

  /// Convert likelihood string to score
  static double _getLikelihood(String? likelihood) {
    switch (likelihood?.toLowerCase()) {
      case 'very_likely':
        return 0.9;
      case 'likely':
        return 0.7;
      case 'possible':
        return 0.5;
      case 'unlikely':
        return 0.3;
      case 'very_unlikely':
        return 0.1;
      default:
        return 0.0;
    }
  }
}

/// Food item detected in image
class FoodItem {
  final String name;
  final double confidence;

  const FoodItem({
    required this.name,
    required this.confidence,
  });

  @override
  String toString() => 'FoodItem(name: $name, confidence: $confidence)';
}

/// Menu item extracted from image
class MenuItem {
  final String name;
  final double price;
  final double confidence;

  const MenuItem({
    required this.name,
    required this.price,
    required this.confidence,
  });

  @override
  String toString() =>
      'MenuItem(name: $name, price: $price, confidence: $confidence)';
}

/// Content moderation result
class ContentModerationResult {
  final double adult;
  final double violence;
  final double racy;
  final double spoof;
  final double medical;

  const ContentModerationResult({
    this.adult = 0.0,
    this.violence = 0.0,
    this.racy = 0.0,
    this.spoof = 0.0,
    this.medical = 0.0,
  });

  /// Check if content is safe
  bool get isSafe {
    return adult < 0.5 &&
        violence < 0.5 &&
        racy < 0.5 &&
        spoof < 0.5 &&
        medical < 0.5;
  }

  @override
  String toString() =>
      'ContentModerationResult(adult: $adult, violence: $violence, racy: $racy, spoof: $spoof, medical: $medical)';
}
