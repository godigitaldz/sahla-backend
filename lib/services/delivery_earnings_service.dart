import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_earnings.dart';
import 'context_aware_service.dart';

class DeliveryEarningsService extends ChangeNotifier {
  static final DeliveryEarningsService _instance =
      DeliveryEarningsService._internal();
  factory DeliveryEarningsService() => _instance;
  DeliveryEarningsService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();

  // Initialize the service with context tracking
  Future<void> initialize() async {
    await _contextAware.initialize();
    debugPrint('🚀 DeliveryEarningsService initialized with context tracking');
  }

  // Calculate and create earnings for a delivery
  Future<DeliveryEarnings?> calculateEarnings({
    required String deliveryPersonId,
    required String orderId,
    required double distanceKm,
    required double baseFee,
    double? performanceMultiplier,
    double? tip,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'calculateEarnings',
      service: 'DeliveryEarningsService',
      operationFunction: () async {
        try {
          // Calculate distance fee (0.5 DA per km)
          final distanceFee = distanceKm * 0.5;

          // Calculate performance bonus
          final performanceBonus = performanceMultiplier != null
              ? baseFee * (performanceMultiplier - 1.0)
              : 0.0;

          // Calculate total earnings
          final totalEarnings =
              baseFee + distanceFee + performanceBonus + (tip ?? 0.0);

          final earningsData = {
            'delivery_person_id': deliveryPersonId,
            'order_id': orderId,
            'base_fee': baseFee,
            'distance_fee': distanceFee,
            'performance_bonus': performanceBonus,
            'tip': tip ?? 0.0,
            'penalty': 0.0,
            'total_earnings': totalEarnings,
            'type': 'base_fee',
            'description': 'Delivery earnings for order #$orderId',
            'created_at': DateTime.now().toIso8601String(),
          };

          final response = await client
              .from('delivery_earnings')
              .insert(earningsData)
              .select('''
                *,
                delivery_personnel(*),
                orders(*)
              ''').single();

          notifyListeners();
          return DeliveryEarnings.fromJson(response);
        } catch (e) {
          debugPrint('Error calculating earnings: $e');
          return null;
        }
      },
      metadata: {
        'delivery_person_id': deliveryPersonId,
        'order_id': orderId,
        'distance_km': distanceKm,
        'base_fee': baseFee,
      },
    );
  }

  // Get delivery person earnings
  Future<List<DeliveryEarnings>?> getDeliveryPersonEarnings({
    required String deliveryPersonId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getDeliveryPersonEarnings',
      service: 'DeliveryEarningsService',
      operationFunction: () async {
        try {
          var query = client.from('delivery_earnings').select('''
                *,
                delivery_personnel(*),
                orders(*)
              ''').eq('delivery_person_id', deliveryPersonId);

          if (startDate != null) {
            query = query.gte('created_at', startDate.toIso8601String());
          }
          if (endDate != null) {
            query = query.lte('created_at', endDate.toIso8601String());
          }

          final response = await query
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);

          return response
              .map((json) => DeliveryEarnings.fromJson(json))
              .toList();
        } catch (e) {
          debugPrint('Error fetching delivery person earnings: $e');
          return [];
        }
      },
      metadata: {
        'delivery_person_id': deliveryPersonId,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'limit': limit,
        'offset': offset,
      },
    );
  }

  // Get earnings summary for a delivery person
  Future<Map<String, dynamic>?> getEarningsSummary({
    required String deliveryPersonId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getEarningsSummary',
      service: 'DeliveryEarningsService',
      operationFunction: () async {
        try {
          var query = client
              .from('delivery_earnings')
              .select(
                  'base_fee, distance_fee, performance_bonus, tip, penalty, total_earnings, created_at')
              .eq('delivery_person_id', deliveryPersonId);

          if (startDate != null) {
            query = query.gte('created_at', startDate.toIso8601String());
          }
          if (endDate != null) {
            query = query.lte('created_at', endDate.toIso8601String());
          }

          final response = await query;

          double totalBaseFee = 0.0;
          double totalDistanceFee = 0.0;
          double totalPerformanceBonus = 0.0;
          double totalTip = 0.0;
          double totalPenalty = 0.0;
          double totalEarnings = 0.0;
          int totalDeliveries = 0;

          for (final earning in response) {
            totalBaseFee += (earning['base_fee'] ?? 0.0).toDouble();
            totalDistanceFee += (earning['distance_fee'] ?? 0.0).toDouble();
            totalPerformanceBonus +=
                (earning['performance_bonus'] ?? 0.0).toDouble();
            totalTip += (earning['tip'] ?? 0.0).toDouble();
            totalPenalty += (earning['penalty'] ?? 0.0).toDouble();
            totalEarnings += (earning['total_earnings'] ?? 0.0).toDouble();
            totalDeliveries++;
          }

          return {
            'total_base_fee': totalBaseFee,
            'total_distance_fee': totalDistanceFee,
            'total_performance_bonus': totalPerformanceBonus,
            'total_tip': totalTip,
            'total_penalty': totalPenalty,
            'total_earnings': totalEarnings,
            'total_deliveries': totalDeliveries,
            'average_earnings_per_delivery':
                totalDeliveries > 0 ? totalEarnings / totalDeliveries : 0.0,
          };
        } catch (e) {
          debugPrint('Error fetching earnings summary: $e');
          return null;
        }
      },
      metadata: {
        'delivery_person_id': deliveryPersonId,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      },
    );
  }

  // Add tip to earnings
  Future<bool> addTip({
    required String deliveryPersonId,
    required String orderId,
    required double tipAmount,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'addTip',
          service: 'DeliveryEarningsService',
          operationFunction: () async {
            try {
              // First, get existing earnings for this order
              final existingEarnings = await client
                  .from('delivery_earnings')
                  .select('*')
                  .eq('delivery_person_id', deliveryPersonId)
                  .eq('order_id', orderId)
                  .single();

              // Update existing earnings with tip
              final newTotalEarnings =
                  (existingEarnings['total_earnings'] ?? 0.0).toDouble() +
                      tipAmount;

              await client.from('delivery_earnings').update({
                'tip': (existingEarnings['tip'] ?? 0.0).toDouble() + tipAmount,
                'total_earnings': newTotalEarnings,
              }).eq('id', existingEarnings['id']);

              notifyListeners();
              return true;
            } catch (e) {
              debugPrint('Error adding tip: $e');
              return false;
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'order_id': orderId,
            'tip_amount': tipAmount,
          },
        ) ??
        false;
  }

  // Add penalty to earnings
  Future<bool> addPenalty({
    required String deliveryPersonId,
    required String orderId,
    required double penaltyAmount,
    required String reason,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'addPenalty',
          service: 'DeliveryEarningsService',
          operationFunction: () async {
            try {
              // First, get existing earnings for this order
              final existingEarnings = await client
                  .from('delivery_earnings')
                  .select('*')
                  .eq('delivery_person_id', deliveryPersonId)
                  .eq('order_id', orderId)
                  .single();

              // Update existing earnings with penalty
              final newTotalEarnings =
                  (existingEarnings['total_earnings'] ?? 0.0).toDouble() -
                      penaltyAmount;

              await client.from('delivery_earnings').update({
                'penalty': (existingEarnings['penalty'] ?? 0.0).toDouble() +
                    penaltyAmount,
                'total_earnings': newTotalEarnings,
              }).eq('id', existingEarnings['id']);

              notifyListeners();
              return true;
            } catch (e) {
              debugPrint('Error adding penalty: $e');
              return false;
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'order_id': orderId,
            'penalty_amount': penaltyAmount,
            'reason': reason,
          },
        ) ??
        false;
  }

  // Get all earnings (admin)
  Future<List<DeliveryEarnings>?> getAllEarnings({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getAllEarnings',
      service: 'DeliveryEarningsService',
      operationFunction: () async {
        try {
          var query = client.from('delivery_earnings').select('''
                *,
                delivery_personnel(*),
                orders(*)
              ''');

          if (startDate != null) {
            query = query.gte('created_at', startDate.toIso8601String());
          }
          if (endDate != null) {
            query = query.lte('created_at', endDate.toIso8601String());
          }

          final response = await query
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);

          return response
              .map((json) => DeliveryEarnings.fromJson(json))
              .toList();
        } catch (e) {
          debugPrint('Error fetching all earnings: $e');
          return [];
        }
      },
      metadata: {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'limit': limit,
        'offset': offset,
      },
    );
  }

  // Get context summary for debugging
  Map<String, dynamic> getContextSummary() {
    return _contextAware.getContextSummary();
  }
}
