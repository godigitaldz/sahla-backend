import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Google Cloud Natural Language API service for text analysis
class CloudNaturalLanguageService {
  static const String _baseUrl =
      'https://language.googleapis.com/v1/documents:analyzeSentiment';
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Analyze sentiment of text (reviews, comments, etc.)
  static Future<SentimentResult?> analyzeSentiment(String text) async {
    try {
      final requestBody = {
        'document': {
          'type': 'PLAIN_TEXT',
          'content': text,
        },
        'encodingType': 'UTF8',
      };

      final uri = Uri.parse('$_baseUrl?key=$_apiKey');

      debugPrint(
          '🧠 Analyzing sentiment for text: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['documentSentiment'] != null) {
          final sentiment = data['documentSentiment'];

          return SentimentResult(
            score: sentiment['score'] as double,
            magnitude: sentiment['magnitude'] as double,
            language: data['language'] as String? ?? 'unknown',
          );
        }
      } else {
        debugPrint('❌ Natural Language API error: ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error analyzing sentiment: $e');
    }

    return null;
  }

  /// Analyze sentiment of multiple texts in batch
  static Future<List<SentimentResult?>> analyzeSentimentBatch(
      List<String> texts) async {
    final results = <SentimentResult?>[];

    for (final text in texts) {
      final result = await analyzeSentiment(text);
      results.add(result);

      // Add small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return results;
  }

  /// Extract entities from text (restaurant names, food items, etc.)
  static Future<List<Entity>> extractEntities(String text) async {
    try {
      final requestBody = {
        'document': {
          'type': 'PLAIN_TEXT',
          'content': text,
        },
        'encodingType': 'UTF8',
      };

      final uri = Uri.parse(
          'https://language.googleapis.com/v1/documents:analyzeEntities?key=$_apiKey');

      debugPrint(
          '🏷️ Extracting entities from text: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['entities'] != null) {
          final entities = data['entities'] as List;

          return entities
              .map((entity) => Entity(
                    name: entity['name'] as String,
                    type: entity['type'] as String,
                    salience: entity['salience'] as double,
                    confidence: entity['mentions'] != null &&
                            (entity['mentions'] as List).isNotEmpty
                        ? (entity['mentions'][0]['probability'] as double)
                        : 0.0,
                  ))
              .toList();
        }
      } else {
        debugPrint('❌ Natural Language API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error extracting entities: $e');
    }

    return [];
  }

  /// Classify text content
  static Future<List<ClassificationCategory>> classifyText(String text) async {
    try {
      final requestBody = {
        'document': {
          'type': 'PLAIN_TEXT',
          'content': text,
        },
      };

      final uri = Uri.parse(
          'https://language.googleapis.com/v1/documents:classifyText?key=$_apiKey');

      debugPrint(
          '📋 Classifying text: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['categories'] != null) {
          final categories = data['categories'] as List;

          return categories
              .map((category) => ClassificationCategory(
                    name: category['name'] as String,
                    confidence: category['confidence'] as double,
                  ))
              .toList();
        }
      } else {
        debugPrint('❌ Natural Language API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error classifying text: $e');
    }

    return [];
  }

  /// Moderate content for inappropriate text
  static Future<ContentModerationResult> moderateText(String text) async {
    try {
      final requestBody = {
        'document': {
          'type': 'PLAIN_TEXT',
          'content': text,
        },
      };

      final uri = Uri.parse(
          'https://language.googleapis.com/v1/documents:moderateText?key=$_apiKey');

      debugPrint(
          '🛡️ Moderating text: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['moderationCategories'] != null) {
          final categories = data['moderationCategories'] as List;

          double adultScore = 0.0;
          double violenceScore = 0.0;
          double racyScore = 0.0;
          double spoofScore = 0.0;
          double medicalScore = 0.0;

          for (final category in categories) {
            final name = category['name'] as String;
            final confidence = category['confidence'] as double;

            switch (name.toLowerCase()) {
              case 'adult':
                adultScore = confidence;
                break;
              case 'violence':
                violenceScore = confidence;
                break;
              case 'racy':
                racyScore = confidence;
                break;
              case 'spoof':
                spoofScore = confidence;
                break;
              case 'medical':
                medicalScore = confidence;
                break;
            }
          }

          return ContentModerationResult(
            adult: adultScore,
            violence: violenceScore,
            racy: racyScore,
            spoof: spoofScore,
            medical: medicalScore,
          );
        }
      } else {
        debugPrint('❌ Natural Language API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error moderating text: $e');
    }

    return const ContentModerationResult();
  }

  /// Analyze restaurant reviews for insights
  static Future<ReviewInsights> analyzeRestaurantReviews(
      List<String> reviews) async {
    final insights = ReviewInsights();

    for (final review in reviews) {
      // Analyze sentiment
      final sentiment = await analyzeSentiment(review);
      if (sentiment != null) {
        insights.addSentiment(sentiment);
      }

      // Extract entities
      final entities = await extractEntities(review);
      entities.forEach(insights.addEntity);

      // Moderate content
      final moderation = await moderateText(review);
      if (!moderation.isSafe) {
        insights.addInappropriateContent();
      }
    }

    return insights;
  }
}

/// Sentiment analysis result
class SentimentResult {
  final double score; // -1.0 to 1.0 (negative to positive)
  final double magnitude; // 0.0 to infinity (strength of sentiment)
  final String language;

  const SentimentResult({
    required this.score,
    required this.magnitude,
    required this.language,
  });

  /// Get sentiment label
  String get sentimentLabel {
    if (score >= 0.25) return 'Positive';
    if (score <= -0.25) return 'Negative';
    return 'Neutral';
  }

  /// Get sentiment emoji
  String get sentimentEmoji {
    if (score >= 0.25) return '😊';
    if (score <= -0.25) return '😞';
    return '😐';
  }

  @override
  String toString() =>
      'SentimentResult(score: $score, magnitude: $magnitude, language: $language)';
}

/// Entity extracted from text
class Entity {
  final String name;
  final String type;
  final double salience; // 0.0 to 1.0 (importance)
  final double confidence; // 0.0 to 1.0 (confidence)

  const Entity({
    required this.name,
    required this.type,
    required this.salience,
    required this.confidence,
  });

  @override
  String toString() =>
      'Entity(name: $name, type: $type, salience: $salience, confidence: $confidence)';
}

/// Classification category
class ClassificationCategory {
  final String name;
  final double confidence;

  const ClassificationCategory({
    required this.name,
    required this.confidence,
  });

  @override
  String toString() =>
      'ClassificationCategory(name: $name, confidence: $confidence)';
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

/// Restaurant review insights
class ReviewInsights {
  final List<SentimentResult> sentiments = [];
  final Map<String, int> entityCounts = {};
  int inappropriateContentCount = 0;

  void addSentiment(SentimentResult sentiment) {
    sentiments.add(sentiment);
  }

  void addEntity(Entity entity) {
    entityCounts[entity.name] = (entityCounts[entity.name] ?? 0) + 1;
  }

  void addInappropriateContent() {
    inappropriateContentCount++;
  }

  /// Get overall sentiment
  SentimentResult get overallSentiment {
    if (sentiments.isEmpty) {
      return const SentimentResult(
          score: 0.0, magnitude: 0.0, language: 'unknown');
    }

    final avgScore = sentiments.map((s) => s.score).reduce((a, b) => a + b) /
        sentiments.length;
    final avgMagnitude =
        sentiments.map((s) => s.magnitude).reduce((a, b) => a + b) /
            sentiments.length;

    return SentimentResult(
      score: avgScore,
      magnitude: avgMagnitude,
      language: sentiments.first.language,
    );
  }

  /// Get top mentioned entities
  List<MapEntry<String, int>> get topEntities {
    final entries = entityCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(10).toList();
  }

  /// Get sentiment distribution
  Map<String, int> get sentimentDistribution {
    final distribution = <String, int>{
      'Positive': 0,
      'Neutral': 0,
      'Negative': 0,
    };

    for (final sentiment in sentiments) {
      distribution[sentiment.sentimentLabel] =
          (distribution[sentiment.sentimentLabel] ?? 0) + 1;
    }

    return distribution;
  }

  @override
  String toString() =>
      'ReviewInsights(sentiments: ${sentiments.length}, entities: ${entityCounts.length}, inappropriate: $inappropriateContentCount)';
}
