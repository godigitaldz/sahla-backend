import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';

/// Google Cloud Translation API service for real-time text translation
class CloudTranslationService {
  static const String _baseUrl =
      'https://translation.googleapis.com/language/translate/v2';
  static const String _apiKey = MapsConfig.googleMapsApiKey;

  /// Translate text to target language
  static Future<String?> translateText({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    try {
      final queryParams = <String, String>{
        'key': _apiKey,
        'q': text,
        'target': targetLanguage,
      };

      if (sourceLanguage != null) {
        queryParams['source'] = sourceLanguage;
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      debugPrint('🌐 Translating text: "$text" to $targetLanguage');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['data'] != null && data['data']['translations'] != null) {
          final translations = data['data']['translations'] as List;
          if (translations.isNotEmpty) {
            final translatedText =
                translations.first['translatedText'] as String;
            debugPrint('✅ Translation successful: "$translatedText"');
            return translatedText;
          }
        }
      } else {
        debugPrint('❌ Translation API error: ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error translating text: $e');
    }

    return null;
  }

  /// Translate multiple texts in batch
  static Future<List<String?>> translateBatch({
    required List<String> texts,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    try {
      final queryParams = <String, String>{
        'key': _apiKey,
        'target': targetLanguage,
      };

      if (sourceLanguage != null) {
        queryParams['source'] = sourceLanguage;
      }

      // Add all texts as separate 'q' parameters
      for (int i = 0; i < texts.length; i++) {
        queryParams['q'] = texts[i];
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      debugPrint(
          '🌐 Batch translating ${texts.length} texts to $targetLanguage');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['data'] != null && data['data']['translations'] != null) {
          final translations = data['data']['translations'] as List;
          return translations
              .map((t) => t['translatedText'] as String?)
              .toList();
        }
      } else {
        debugPrint('❌ Batch translation API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error in batch translation: $e');
    }

    return List.filled(texts.length, null);
  }

  /// Detect language of text
  static Future<String?> detectLanguage(String text) async {
    try {
      final uri = Uri.parse(
              'https://translation.googleapis.com/language/translate/v2/detect')
          .replace(
        queryParameters: {
          'key': _apiKey,
          'q': text,
        },
      );

      debugPrint('🔍 Detecting language for: "$text"');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['data'] != null && data['data']['detections'] != null) {
          final detections = data['data']['detections'] as List;
          if (detections.isNotEmpty && detections.first is List) {
            final firstDetection = (detections.first as List).first;
            final language = firstDetection['language'] as String;
            final confidence = firstDetection['confidence'] as double;

            debugPrint(
                '✅ Language detected: $language (confidence: $confidence)');
            return language;
          }
        }
      } else {
        debugPrint('❌ Language detection API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error detecting language: $e');
    }

    return null;
  }

  /// Get supported languages
  static Future<List<LanguageInfo>> getSupportedLanguages() async {
    try {
      final uri = Uri.parse(
              'https://translation.googleapis.com/language/translate/v2/languages')
          .replace(
        queryParameters: {
          'key': _apiKey,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['data'] != null && data['data']['languages'] != null) {
          final languages = data['data']['languages'] as List;
          return languages
              .map((lang) => LanguageInfo(
                    code: lang['language'] as String,
                    name: lang['name'] as String,
                  ))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting supported languages: $e');
    }

    return [];
  }
}

/// Language information model
class LanguageInfo {
  final String code;
  final String name;

  const LanguageInfo({
    required this.code,
    required this.name,
  });

  @override
  String toString() => 'LanguageInfo(code: $code, name: $name)';
}
