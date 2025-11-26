import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant_form_state.dart';

class FormPersistenceService {
  static const String _formStateKey = 'restaurant_form_state';
  static const String _formStepKey = 'restaurant_form_step';
  static const String _formTimestampKey = 'restaurant_form_timestamp';
  static const String _formDraftKey = 'restaurant_form_draft';

  /// Save current form state
  static Future<void> saveFormState(
      RestaurantFormState formState, int currentStep) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save form state
      final formStateJson = jsonEncode(formState.toMap());
      await prefs.setString(_formStateKey, formStateJson);

      // Save current step
      await prefs.setInt(_formStepKey, currentStep);

      // Save timestamp
      await prefs.setString(
          _formTimestampKey, DateTime.now().toIso8601String());

      debugPrint('📱 Form state saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving form state: $e');
    }
  }

  /// Load saved form state
  static Future<Map<String, dynamic>?> loadFormState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final formStateJson = prefs.getString(_formStateKey);
      final currentStep = prefs.getInt(_formStepKey) ?? 0;
      final timestamp = prefs.getString(_formTimestampKey);

      if (formStateJson != null) {
        final formStateMap = jsonDecode(formStateJson) as Map<String, dynamic>;

        return {
          'formState': formStateMap,
          'currentStep': currentStep,
          'timestamp': timestamp,
        };
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error loading form state: $e');
      return null;
    }
  }

  /// Clear saved form state
  static Future<void> clearFormState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_formStateKey);
      await prefs.remove(_formStepKey);
      await prefs.remove(_formTimestampKey);

      debugPrint('🗑️ Form state cleared successfully');
    } catch (e) {
      debugPrint('❌ Error clearing form state: $e');
    }
  }

  /// Check if form has been saved recently (within last 24 hours)
  static Future<bool> hasRecentDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString(_formTimestampKey);

      if (timestamp != null) {
        final savedTime = DateTime.parse(timestamp);
        final now = DateTime.now();
        final difference = now.difference(savedTime);

        return difference.inHours < 24;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking recent draft: $e');
      return false;
    }
  }

  /// Save form as draft for later completion
  static Future<void> saveFormDraft(Map<String, dynamic> formData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final draftData = {
        'formData': formData,
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0',
      };

      await prefs.setString(_formDraftKey, jsonEncode(draftData));

      debugPrint('💾 Form draft saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving form draft: $e');
    }
  }

  /// Load form draft
  static Future<Map<String, dynamic>?> loadFormDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftJson = prefs.getString(_formDraftKey);

      if (draftJson != null) {
        return jsonDecode(draftJson) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error loading form draft: $e');
      return null;
    }
  }

  /// Clear form draft
  static Future<void> clearFormDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_formDraftKey);

      debugPrint('🗑️ Form draft cleared successfully');
    } catch (e) {
      debugPrint('❌ Error clearing form draft: $e');
    }
  }

  /// Auto-save form data periodically
  static Future<void> autoSaveForm(Map<String, dynamic> formData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastAutoSave = prefs.getString('last_auto_save');

      // Only auto-save every 30 seconds
      if (lastAutoSave != null) {
        final lastSave = DateTime.parse(lastAutoSave);
        final now = DateTime.now();
        if (now.difference(lastSave).inSeconds < 30) {
          return;
        }
      }

      await saveFormDraft(formData);
      await prefs.setString('last_auto_save', DateTime.now().toIso8601String());

      debugPrint('🔄 Auto-save completed');
    } catch (e) {
      debugPrint('❌ Error auto-saving form: $e');
    }
  }

  /// Get form completion percentage
  static double calculateCompletionPercentage(Map<String, dynamic> formData) {
    int completedFields = 0;
    int totalFields = 0;

    // Required fields
    final requiredFields = [
      'restaurantName',
      'address',
      'phone',
      'wilaya',
      'workingHours',
      'latitude',
      'longitude',
    ];

    totalFields += requiredFields.length;

    for (final field in requiredFields) {
      if (formData[field] != null && formData[field].toString().isNotEmpty) {
        completedFields++;
      }
    }

    // Optional fields
    final optionalFields = [
      'description',
      'logoUrl',
      'facebook',
      'instagram',
      'tiktok',
    ];

    totalFields += optionalFields.length;

    for (final field in optionalFields) {
      if (formData[field] != null && formData[field].toString().isNotEmpty) {
        completedFields++;
      }
    }

    return totalFields > 0 ? (completedFields / totalFields) * 100 : 0;
  }

  /// Check if form is ready for submission
  static bool isFormReadyForSubmission(Map<String, dynamic> formData) {
    final requiredFields = [
      'restaurantName',
      'address',
      'phone',
      'wilaya',
      'workingHours',
      'latitude',
      'longitude',
    ];

    for (final field in requiredFields) {
      if (formData[field] == null || formData[field].toString().isEmpty) {
        return false;
      }
    }

    return true;
  }
}
