import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant_form_draft.dart';

class FormDraftService {
  static const String _draftsKey = 'restaurant_form_drafts';
  static const int _maxDrafts = 5; // Maximum number of drafts to keep

  /// Save a new draft
  static Future<void> saveDraft(RestaurantFormDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingDrafts = await _loadDrafts();

      // Remove existing draft with same ID if it exists
      existingDrafts.removeWhere((d) => d.id == draft.id);

      // Add new draft
      existingDrafts.add(draft);

      // Sort by updated date (newest first)
      existingDrafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // Keep only the most recent drafts
      if (existingDrafts.length > _maxDrafts) {
        existingDrafts.removeRange(_maxDrafts, existingDrafts.length);
      }

      // Save to preferences
      final draftsJson = existingDrafts.map((d) => d.toJson()).toList();
      await prefs.setString(_draftsKey, jsonEncode(draftsJson));

      debugPrint(
          '💾 Draft saved: ${draft.restaurantName} (${draft.completionPercentage.toStringAsFixed(1)}% complete)');
    } catch (e) {
      debugPrint('❌ Error saving draft: $e');
    }
  }

  /// Load all drafts
  static Future<List<RestaurantFormDraft>> loadDrafts() async {
    try {
      final drafts = await _loadDrafts();

      // Filter out expired drafts
      final validDrafts = drafts.where((draft) => !draft.isExpired).toList();

      // If we filtered out any drafts, save the updated list
      if (validDrafts.length != drafts.length) {
        await _saveDrafts(validDrafts);
      }

      return validDrafts;
    } catch (e) {
      debugPrint('❌ Error loading drafts: $e');
      return [];
    }
  }

  /// Load drafts from preferences
  static Future<List<RestaurantFormDraft>> _loadDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsJson = prefs.getString(_draftsKey);

      if (draftsJson != null) {
        final List<dynamic> draftsList = jsonDecode(draftsJson);
        return draftsList
            .map((json) =>
                RestaurantFormDraft.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('❌ Error loading drafts from preferences: $e');
      return [];
    }
  }

  /// Save drafts to preferences
  static Future<void> _saveDrafts(List<RestaurantFormDraft> drafts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsJson = drafts.map((d) => d.toJson()).toList();
      await prefs.setString(_draftsKey, jsonEncode(draftsJson));
    } catch (e) {
      debugPrint('❌ Error saving drafts to preferences: $e');
    }
  }

  /// Get draft by ID
  static Future<RestaurantFormDraft?> getDraftById(String id) async {
    try {
      final drafts = await loadDrafts();
      return drafts.firstWhere((draft) => draft.id == id);
    } catch (e) {
      debugPrint('❌ Error getting draft by ID: $e');
      return null;
    }
  }

  /// Delete draft by ID
  static Future<void> deleteDraft(String id) async {
    try {
      final drafts = await loadDrafts();
      drafts.removeWhere((draft) => draft.id == id);
      await _saveDrafts(drafts);

      debugPrint('🗑️ Draft deleted: $id');
    } catch (e) {
      debugPrint('❌ Error deleting draft: $e');
    }
  }

  /// Delete all drafts
  static Future<void> deleteAllDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftsKey);

      debugPrint('🗑️ All drafts deleted');
    } catch (e) {
      debugPrint('❌ Error deleting all drafts: $e');
    }
  }

  /// Get recent drafts (within last 24 hours)
  static Future<List<RestaurantFormDraft>> getRecentDrafts() async {
    try {
      final drafts = await loadDrafts();
      return drafts.where((draft) => draft.isRecent).toList();
    } catch (e) {
      debugPrint('❌ Error getting recent drafts: $e');
      return [];
    }
  }

  /// Get drafts by completion percentage
  static Future<List<RestaurantFormDraft>> getDraftsByCompletion({
    double minCompletion = 0.0,
    double maxCompletion = 100.0,
  }) async {
    try {
      final drafts = await loadDrafts();
      return drafts
          .where((draft) =>
              draft.completionPercentage >= minCompletion &&
              draft.completionPercentage <= maxCompletion)
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting drafts by completion: $e');
      return [];
    }
  }

  /// Get drafts ready for submission
  static Future<List<RestaurantFormDraft>> getReadyForSubmissionDrafts() async {
    try {
      final drafts = await loadDrafts();
      return drafts.where((draft) => draft.isReadyForSubmission).toList();
    } catch (e) {
      debugPrint('❌ Error getting ready for submission drafts: $e');
      return [];
    }
  }

  /// Update existing draft
  static Future<void> updateDraft(
      String id, Map<String, dynamic> formData, int currentStep) async {
    try {
      final draft = await getDraftById(id);
      if (draft != null) {
        final updatedDraft = draft.update(
          formData: formData,
          currentStep: currentStep,
        );
        await saveDraft(updatedDraft);
      }
    } catch (e) {
      debugPrint('❌ Error updating draft: $e');
    }
  }

  /// Auto-save draft
  static Future<void> autoSaveDraft(
      Map<String, dynamic> formData, int currentStep) async {
    try {
      final draft = RestaurantFormDraft.create(
        formData: formData,
        currentStep: currentStep,
        isAutoSaved: true,
      );

      await saveDraft(draft);
      debugPrint('🔄 Auto-saved draft: ${draft.restaurantName}');
    } catch (e) {
      debugPrint('❌ Error auto-saving draft: $e');
    }
  }

  /// Get draft statistics
  static Future<Map<String, dynamic>> getDraftStatistics() async {
    try {
      final drafts = await loadDrafts();

      if (drafts.isEmpty) {
        return {
          'totalDrafts': 0,
          'recentDrafts': 0,
          'readyForSubmission': 0,
          'averageCompletion': 0.0,
          'oldestDraft': null,
          'newestDraft': null,
        };
      }

      final recentDrafts = drafts.where((d) => d.isRecent).length;
      final readyForSubmission =
          drafts.where((d) => d.isReadyForSubmission).length;
      final averageCompletion = drafts.fold<double>(
              0, (sum, draft) => sum + draft.completionPercentage) /
          drafts.length;

      drafts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final oldestDraft = drafts.first;
      final newestDraft = drafts.last;

      return {
        'totalDrafts': drafts.length,
        'recentDrafts': recentDrafts,
        'readyForSubmission': readyForSubmission,
        'averageCompletion': averageCompletion,
        'oldestDraft': oldestDraft.formattedCreatedDate,
        'newestDraft': newestDraft.formattedCreatedDate,
      };
    } catch (e) {
      debugPrint('❌ Error getting draft statistics: $e');
      return {
        'totalDrafts': 0,
        'recentDrafts': 0,
        'readyForSubmission': 0,
        'averageCompletion': 0.0,
        'oldestDraft': null,
        'newestDraft': null,
      };
    }
  }

  /// Clean up expired drafts
  static Future<void> cleanupExpiredDrafts() async {
    try {
      final drafts = await loadDrafts();
      final validDrafts = drafts.where((draft) => !draft.isExpired).toList();

      if (validDrafts.length != drafts.length) {
        await _saveDrafts(validDrafts);
        debugPrint(
            '🧹 Cleaned up ${drafts.length - validDrafts.length} expired drafts');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up expired drafts: $e');
    }
  }
}
