import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Service for managing order reviews
/// Handles fetching, submitting, updating, and deleting order reviews
class OrderReviewService extends ChangeNotifier {
  /// Fetch reviews for a specific order
  Future<List<Map<String, dynamic>>> getOrderReviews(String orderId) async {
    try {
      debugPrint('📦 FETCHING ORDER REVIEWS: orderId=$orderId');

      final response = await ApiClient.get('/api/orders/$orderId/reviews');

      debugPrint(
          '📦 ORDER REVIEWS RAW RESPONSE: success=${response["success"]}, statusCode=${response["statusCode"]}, dataType=${response["data"]?.runtimeType}, dataLength=${response["data"] is List ? (response["data"] as List).length : "Not a list"}');

      if (!response['success']) {
        debugPrint('❌ ORDER REVIEW SERVICE ERROR: ${response["error"]}');
        return [];
      }

      final reviewsData = response['data'] as List;

      if (reviewsData.isEmpty) {
        debugPrint('⚠️ ORDER REVIEWS: No data received from API');
        return [];
      }

      debugPrint(
          '✅ ORDER REVIEWS PROCESSED SUCCESSFULLY: totalCount=${reviewsData.length}');

      return reviewsData.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ OrderReviewService: Error fetching order reviews: $e');
      return [];
    }
  }

  /// Submit a review for an order
  Future<bool> submitOrderReview({
    required String orderId,
    required int rating,
    String? comment,
    String? image,
    List<String>? photos,
  }) async {
    try {
      debugPrint(
          '📦 SUBMITTING ORDER REVIEW: orderId=$orderId, rating=$rating');

      final response = await ApiClient.post(
        '/api/orders/$orderId/reviews',
        data: {
          'rating': rating,
          'comment': comment,
          'image': image,
          'photos': photos,
        },
      );

      debugPrint(
          '📦 SUBMIT ORDER REVIEW RESPONSE: success=${response["success"]}, statusCode=${response["statusCode"]}');

      if (!response['success']) {
        debugPrint('❌ SUBMIT ORDER REVIEW ERROR: ${response["error"]}');
        return false;
      }

      debugPrint('✅ ORDER REVIEW SUBMITTED SUCCESSFULLY');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ OrderReviewService: Error submitting order review: $e');
      return false;
    }
  }

  /// Update a review for an order
  Future<bool> updateOrderReview({
    required String reviewId,
    required int rating,
    String? comment,
    String? image,
    List<String>? photos,
  }) async {
    try {
      debugPrint(
          '📦 UPDATING ORDER REVIEW: reviewId=$reviewId, rating=$rating');

      final response = await ApiClient.put(
        '/api/orders/reviews/$reviewId',
        data: {
          'rating': rating,
          'comment': comment,
          'image': image,
          'photos': photos,
        },
      );

      debugPrint(
          '📦 UPDATE ORDER REVIEW RESPONSE: success=${response["success"]}, statusCode=${response["statusCode"]}');

      if (!response['success']) {
        debugPrint('❌ UPDATE ORDER REVIEW ERROR: ${response["error"]}');
        return false;
      }

      debugPrint('✅ ORDER REVIEW UPDATED SUCCESSFULLY');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ OrderReviewService: Error updating order review: $e');
      return false;
    }
  }

  /// Delete a review for an order
  Future<bool> deleteOrderReview(String reviewId) async {
    try {
      debugPrint('📦 DELETING ORDER REVIEW: reviewId=$reviewId');

      final response = await ApiClient.delete('/api/orders/reviews/$reviewId');

      debugPrint(
          '📦 DELETE ORDER REVIEW RESPONSE: success=${response["success"]}, statusCode=${response["statusCode"]}');

      if (!response['success']) {
        debugPrint('❌ DELETE ORDER REVIEW ERROR: ${response["error"]}');
        return false;
      }

      debugPrint('✅ ORDER REVIEW DELETED SUCCESSFULLY');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ OrderReviewService: Error deleting order review: $e');
      return false;
    }
  }

  /// Get user's review for a specific order
  Future<Map<String, dynamic>?> getUserOrderReview(String orderId) async {
    try {
      debugPrint('📦 FETCHING USER ORDER REVIEW: orderId=$orderId');

      final response = await ApiClient.get('/api/orders/$orderId/reviews/user');

      debugPrint(
          '📦 USER ORDER REVIEW RESPONSE: success=${response["success"]}, statusCode=${response["statusCode"]}');

      if (!response['success']) {
        debugPrint('❌ USER ORDER REVIEW ERROR: ${response["error"]}');
        return null;
      }

      return response['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('❌ OrderReviewService: Error fetching user order review: $e');
      return null;
    }
  }
}
