import "dart:async";

import "package:flutter/foundation.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../models/promo_code.dart";
import "../utils/logger.dart";
import "api_client.dart";

class PromoCodeService extends ChangeNotifier {
  factory PromoCodeService() => _instance;

  PromoCodeService._internal();

  static final PromoCodeService _instance = PromoCodeService._internal();

  final Logger logger = Logger();

  /// Validate and get promo code by code string
  /// Returns a map with 'promoCode' and 'errorMessage' keys
  Future<Map<String, dynamic>> validatePromoCodeWithDetails(String code,
      {String? restaurantId, String? userId}) async {
    try {
      // Build query parameters - only include non-null values
      final queryParams = <String, String>{
        "code": code.toUpperCase(),
      };

      if (restaurantId != null && restaurantId.isNotEmpty) {
        queryParams["restaurantId"] = restaurantId;
      }

      if (userId != null && userId.isNotEmpty) {
        queryParams["userId"] = userId;
      }

      if (kDebugMode) {
        Logger.info(
            "🎫 Validating promo code: $code with params: $queryParams");
      }

      // Try the validation endpoint
      try {
        if (kDebugMode) {
          Logger.info("🎫 Making API request to: /api/promo-codes/validate");
        }
        final response = await ApiClient.get(
          "/api/promo-codes/validate",
          queryParameters: queryParams,
        );

        if (kDebugMode) {
          Logger.info(
              "🎫 Validation response: ${response["success"]} - ${response["data"]}");
        }

        if (!response["success"]) {
          final errorMsg =
              response["error"] ?? response["data"] ?? "Server error occurred";
          if (kDebugMode) {
            Logger.error("❌ Promo code validation failed: $errorMsg");
          }
          return {"promoCode": null, "errorMessage": errorMsg};
        }

        // Check if validation was successful
        if (response["data"] == null || response["data"]["valid"] != true) {
          final errorMsg = response["data"]?["message"] ?? "Invalid promo code";
          if (kDebugMode) {
            Logger.error("❌ Promo code validation failed: $errorMsg");
          }
          return {"promoCode": null, "errorMessage": errorMsg};
        }

        final promoCodeData = response["data"]["promoCode"];
        if (promoCodeData == null) {
          if (kDebugMode) {
            Logger.error("❌ No promo code data in response");
          }
          return {
            "promoCode": null,
            "errorMessage": "Promo code data not found"
          };
        }

        final promoCode = PromoCode.fromJson(promoCodeData);

        if (kDebugMode) {
          Logger.info("✅ Validated promo code via Node.js backend: $code");
        }
        return {"promoCode": promoCode, "errorMessage": null};
      } catch (apiError) {
        if (kDebugMode) {
          Logger.error("❌ API validation failed: $apiError");
        }

        // Fallback: Try to get the promo code directly from public promo codes
        if (kDebugMode) {
          Logger.info(
              "🔄 Attempting fallback validation via public promo codes...");
        }

        try {
          if (kDebugMode) {
            Logger.info(
                "🎫 Fetching public promo codes for fallback validation...");
          }
          final publicPromoCodes = await getPublicPromoCodes(limit: 100);
          if (kDebugMode) {
            Logger.info(
                "🎫 Found ${publicPromoCodes.length} public promo codes");
          }

          final matchingPromoCode = publicPromoCodes.firstWhere(
            (promo) => promo.code.toUpperCase() == code.toUpperCase(),
            orElse: () => throw StateError('No matching promo code found'),
          );

          if (kDebugMode) {
            Logger.info(
                "🎫 Found matching promo code: ${matchingPromoCode.code}");
          }

          // Basic validation
          if (!matchingPromoCode.isActive) {
            if (kDebugMode) {
              Logger.error("❌ Promo code $code is not active");
            }
            return {
              "promoCode": null,
              "errorMessage":
                  "This promo code is not currently active or has expired"
            };
          }

          if (restaurantId != null &&
              matchingPromoCode.restaurantId != null &&
              matchingPromoCode.restaurantId != restaurantId) {
            if (kDebugMode) {
              Logger.error(
                  "❌ Promo code $code is not valid for restaurant $restaurantId");
            }
            return {
              "promoCode": null,
              "errorMessage":
                  "This promo code is not valid for the selected restaurant"
            };
          }

          if (kDebugMode) {
            Logger.info(
                "✅ Fallback validation successful for promo code: $code");
          }
          return {"promoCode": matchingPromoCode, "errorMessage": null};
        } catch (fallbackError) {
          if (kDebugMode) {
            Logger.error("❌ Fallback validation also failed: $fallbackError");
          }
          return {
            "promoCode": null,
            "errorMessage": "Promo code not found or invalid"
          };
        }
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        Logger.error("❌ Error validating promo code via API: $e");
      }
      return {
        "promoCode": null,
        "errorMessage": "Network error: ${e.toString()}"
      };
    }
  }

  /// Validate and get promo code by code string (legacy method for backward compatibility)
  Future<PromoCode?> validatePromoCode(String code,
      {String? restaurantId, String? userId}) async {
    final result = await validatePromoCodeWithDetails(code,
        restaurantId: restaurantId, userId: userId);
    return result["promoCode"];
  }

  /// Simple validation using public promo codes (fallback method)
  Future<PromoCode?> validatePromoCodeSimple(String code,
      {String? restaurantId}) async {
    try {
      if (kDebugMode) Logger.info("🎫 Simple validation for promo code: $code");

      final publicPromoCodes = await getPublicPromoCodes(limit: 100);
      final matchingPromoCode = publicPromoCodes.firstWhere(
        (promo) => promo.code.toUpperCase() == code.toUpperCase(),
        orElse: () => throw StateError('No matching promo code found'),
      );

      // Basic validation
      if (!matchingPromoCode.isActive) {
        if (kDebugMode) {
          Logger.error("❌ Promo code $code is not active");
        }
        return null;
      }

      if (restaurantId != null &&
          matchingPromoCode.restaurantId != null &&
          matchingPromoCode.restaurantId != restaurantId) {
        if (kDebugMode) {
          Logger.error(
              "❌ Promo code $code is not valid for restaurant $restaurantId");
        }
        return null;
      }

      if (kDebugMode) {
        Logger.info("✅ Simple validation successful for promo code: $code");
      }
      return matchingPromoCode;
    } catch (e) {
      if (kDebugMode) {
        Logger.error("❌ Simple validation failed for promo code $code: $e");
      }
      return null;
    }
  }

  /// Direct validation using only public promo codes (bypasses problematic validation endpoint)
  Future<Map<String, dynamic>> validatePromoCodeDirect(String code,
      {String? restaurantId, String? userId}) async {
    try {
      if (kDebugMode) {
        Logger.info(
            "🎫 Direct validation for promo code: $code (bypassing validation endpoint)");
      }

      final publicPromoCodes = await getPublicPromoCodes(limit: 100);
      if (kDebugMode) {
        Logger.info("🎫 Found ${publicPromoCodes.length} public promo codes");
      }

      // Use where().firstOrNull instead of firstWhere to avoid exceptions
      final matchingPromoCode = publicPromoCodes
          .where(
            (promo) => promo.code.toUpperCase() == code.toUpperCase(),
          )
          .firstOrNull;

      if (matchingPromoCode == null) {
        if (kDebugMode) {
          Logger.error("❌ Promo code $code not found in public promo codes");
        }
        return {"promoCode": null, "errorMessage": "Promo code not found"};
      }

      if (kDebugMode) {
        Logger.info("🎫 Found matching promo code: ${matchingPromoCode.code}");
      }

      // Basic validation
      if (!matchingPromoCode.isActive) {
        if (kDebugMode) {
          Logger.error("❌ Promo code $code is not active");
        }
        return {
          "promoCode": null,
          "errorMessage":
              "This promo code is not currently active or has expired"
        };
      }

      if (restaurantId != null &&
          matchingPromoCode.restaurantId != null &&
          matchingPromoCode.restaurantId != restaurantId) {
        if (kDebugMode) {
          Logger.error(
              "❌ Promo code $code is not valid for restaurant $restaurantId");
        }
        return {
          "promoCode": null,
          "errorMessage":
              "This promo code is not valid for the selected restaurant"
        };
      }

      if (kDebugMode) {
        Logger.info("✅ Direct validation successful for promo code: $code");
      }
      return {"promoCode": matchingPromoCode, "errorMessage": null};
    } catch (e) {
      if (kDebugMode) {
        Logger.error("❌ Direct validation failed for promo code $code: $e");
      }
      return {
        "promoCode": null,
        "errorMessage": "Error validating promo code: ${e.toString()}"
      };
    }
  }

  /// Validate promo code with retry mechanism
  Future<Map<String, dynamic>> validatePromoCodeWithRetry(String code,
      {String? restaurantId, String? userId, int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        if (kDebugMode) {
          Logger.info(
              "🎫 Attempting validation (attempt ${i + 1}/$maxRetries) for promo code: $code");
        }
        return await validatePromoCodeDirect(code,
            restaurantId: restaurantId, userId: userId);
      } catch (e) {
        if (kDebugMode) {
          Logger.error("❌ Validation attempt ${i + 1} failed: $e");
        }
        if (i == maxRetries - 1) {
          return {
            "promoCode": null,
            "errorMessage":
                "Failed to validate promo code after $maxRetries attempts"
          };
        }
        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: (i + 1) * 2));
      }
    }
    return {"promoCode": null, "errorMessage": "Max retries exceeded"};
  }

  /// Get active promo codes for a restaurant
  Future<List<PromoCode>> getActivePromoCodes(String restaurantId) async {
    try {
      // Use Node.js backend for optimized restaurant data
      final response = await ApiClient.get(
        "/api/business/restaurants/optimized",
        queryParameters: {
          "restaurantId": restaurantId,
          "includePromoCodes": "true",
        },
      );

      if (!response["success"]) {
        if (kDebugMode) {
          Logger.error("Error fetching restaurant data: ${response["error"]}");
        }
        return [];
      }

      final restaurantData = response["data"];
      final promoCodesData = restaurantData["promoCodes"] ?? [];

      final promoCodes = promoCodesData
          .map((json) => PromoCode.fromJson(json))
          .where((promoCode) => promoCode.isActive)
          .toList();

      if (kDebugMode) {
        Logger.info(
          "Fetched ${promoCodes.length} active promo codes for restaurant $restaurantId via Node.js backend",
        );
      }

      return promoCodes;
    } on Exception catch (e) {
      if (kDebugMode) {
        Logger.error("Error fetching active promo codes via API: $e");
      }
      return [];
    }
  }

  /// Get all public promo codes
  Future<List<PromoCode>> getPublicPromoCodes(
      {int limit = 20, int offset = 0}) async {
    try {
      // Use direct Supabase since backend is disabled
      if (kDebugMode) {
        Logger.info(
            "🎫 FETCHING PROMO CODES FROM SUPABASE: limit=$limit, offset=$offset");
      }

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('promo_codes')
          .select('*')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final promoCodesData = response as List<dynamic>;

      if (kDebugMode) {
        Logger.info(
            "🎫 PROMO CODES DATA RECEIVED FROM SUPABASE: count=${promoCodesData.length}");
      }

      if (promoCodesData.isEmpty) {
        if (kDebugMode) {
          Logger.warning("⚠️ PROMO CODES: No data received from Supabase");
        }
        return [];
      }

      if (kDebugMode) {
        Logger.info("🎫 PARSING PROMO CODES...");
      }
      final promoCodes = <PromoCode>[];

      for (var i = 0; i < promoCodesData.length; i++) {
        try {
          final promoCode = PromoCode.fromJson(promoCodesData[i]);
          promoCodes.add(promoCode);
          if (kDebugMode) {
            Logger.info(
                "🎫 PARSED PROMO CODE ${i + 1}: ${promoCode.code} - ${promoCode.name}");
          }
        } on Exception catch (e) {
          if (kDebugMode) {
            Logger.error("❌ PROMO CODE PARSING ERROR at index $i: $e");
          }
          if (kDebugMode) {
            Logger.error("❌ PROBLEMATIC DATA: ${promoCodesData[i]}");
          }
        }
      }

      final result = promoCodes.take(limit).toList();

      if (kDebugMode) {
        Logger.info(
            "✅ PROMO CODES PROCESSED SUCCESSFULLY FROM SUPABASE: totalParsed=${promoCodes.length}, returned=${result.length}, sampleCodes=${result.take(3).map((p) => p.code).toList()}");
      }

      return result;
    } on Exception catch (e) {
      if (kDebugMode) {
        Logger.error("Error fetching public promo codes via API: $e");
      }
      return [];
    }
  }

  /// Get promo code by ID
  Future<PromoCode?> getPromoCodeById(String promoCodeId) async {
    try {
      // Use Node.js backend for enhanced promo code data
      final response = await ApiClient.get("/api/promo-codes/$promoCodeId");

      if (!response["success"]) {
        if (kDebugMode) {
          Logger.error("Error fetching promo code by ID: ${response["error"]}");
        }
        return null;
      }

      return PromoCode.fromJson(response["data"]);
    } on Exception catch (e) {
      if (kDebugMode) {
        Logger.error("Error fetching promo code by ID via API: $e");
      }
      return null;
    }
  }
}
