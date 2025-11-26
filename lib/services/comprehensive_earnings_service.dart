import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'context_aware_service.dart';

/// Comprehensive earnings service for delivery personnel
///
/// This service handles the complete earnings system including:
/// - 15% service fee calculation (app takes 15% from delivery man's earnings)
/// - Credit management and upfront payments
/// - Service fee payments from delivery man to app bank account
/// - Payment collection from customers (handled by delivery man)
/// - Bank transfer management for service fees
/// - Real-time earnings tracking
///
/// Key Features:
/// - Service fee is 15% of gross earnings (owed to app)
/// - Delivery personnel can add credit for upfront payments
/// - Delivery personnel pay service fees to app bank account
/// - App collects service fees from customers via delivery man
/// - Real-time wallet balance updates
/// - Comprehensive transaction history
class ComprehensiveEarningsService extends ChangeNotifier {
  static final ComprehensiveEarningsService _instance =
      ComprehensiveEarningsService._internal();
  factory ComprehensiveEarningsService() => _instance;
  ComprehensiveEarningsService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();

  // Service fee rate (15%)
  static const double serviceFeeRate = 0.15;

  // Initialize the service
  Future<void> initialize() async {
    await _contextAware.initialize();
    debugPrint(
        '🚀 ComprehensiveEarningsService initialized with context tracking');
  }

  // =====================================================
  // WALLET MANAGEMENT
  // =====================================================

  /// Get delivery person wallet information
  Future<Map<String, dynamic>?> getWalletInfo(String deliveryPersonId) async {
    return _contextAware.executeWithContext(
      operation: 'getWalletInfo',
      service: 'ComprehensiveEarningsService',
      operationFunction: () async {
        try {
          // Try to get from the view first
          try {
            final response = await client
                .from('delivery_earnings_summary')
                .select('*')
                .eq('delivery_person_id', deliveryPersonId)
                .single();

            return response;
          } catch (e) {
            debugPrint('View not available, trying direct wallet query: $e');

            // Fallback: try to get from delivery_wallets table
            final walletResponse = await client
                .from('delivery_wallets')
                .select('*')
                .eq('delivery_person_id', deliveryPersonId)
                .maybeSingle();

            if (walletResponse != null) {
              return walletResponse;
            }

            // If no wallet exists, create a default one
            debugPrint(
                'No wallet found, creating default wallet for delivery person: $deliveryPersonId');
            final newWallet = await client
                .from('delivery_wallets')
                .insert({
                  'delivery_person_id': deliveryPersonId,
                  'current_balance': 0.0,
                  'credit_balance': 0.0,
                  'total_earned': 0.0,
                  'total_service_fees_paid': 0.0,
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .select()
                .single();

            return newWallet;
          }
        } catch (e) {
          debugPrint('Error fetching wallet info: $e');
          return null;
        }
      },
      metadata: {'delivery_person_id': deliveryPersonId},
    );
  }

  /// Add credit to delivery person wallet
  Future<bool> addCredit({
    required String deliveryPersonId,
    required double amount,
    required String paymentMethod,
    required String paymentReference,
    Map<String, dynamic>? bankDetails,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'addCredit',
          service: 'ComprehensiveEarningsService',
          operationFunction: () async {
            try {
              final response = await client.rpc('add_delivery_credit', params: {
                'p_delivery_person_id': deliveryPersonId,
                'p_amount': amount,
                'p_payment_method': paymentMethod,
                'p_payment_reference': paymentReference,
                'p_bank_details': bankDetails,
              });

              if (response != null) {
                notifyListeners();
                return true;
              }
              return false;
            } catch (e) {
              debugPrint('Error adding credit: $e');
              return false;
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'amount': amount,
            'payment_method': paymentMethod,
          },
        ) ??
        false;
  }

  /// Get credit transaction history
  Future<List<Map<String, dynamic>>> getCreditTransactions({
    required String deliveryPersonId,
    int limit = 50,
    int offset = 0,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'getCreditTransactions',
          service: 'ComprehensiveEarningsService',
          operationFunction: () async {
            try {
              final response = await client
                  .from('delivery_credit_transactions')
                  .select('*')
                  .eq('delivery_person_id', deliveryPersonId)
                  .order('created_at', ascending: false)
                  .range(offset, offset + limit - 1);

              return (response as List<dynamic>)
                  .map((e) =>
                      Map<String, dynamic>.from(e as Map<String, dynamic>))
                  .toList();
            } catch (e) {
              debugPrint('Error fetching credit transactions: $e');
              return [];
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'limit': limit,
            'offset': offset,
          },
        ) as List<Map<String, dynamic>>? ??
        <Map<String, dynamic>>[];
  }

  // =====================================================
  // EARNINGS CALCULATION & SERVICE FEES
  // =====================================================

  /// Calculate service fee (15% of gross earnings)
  double calculateServiceFee(double grossEarnings) {
    return (grossEarnings * serviceFeeRate).roundToDouble();
  }

  /// Calculate net earnings after service fee
  double calculateNetEarnings(double grossEarnings) {
    return grossEarnings - calculateServiceFee(grossEarnings);
  }

  /// Record payment collection from customer
  Future<bool> recordPaymentCollection({
    required String deliveryPersonId,
    required String orderId,
    required String customerId,
    required double totalOrderAmount,
    required double deliveryFee,
    required String paymentMethod,
    String? taskId,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'recordPaymentCollection',
          service: 'ComprehensiveEarningsService',
          operationFunction: () async {
            try {
              final response =
                  await client.rpc('record_payment_collection', params: {
                'p_delivery_person_id': deliveryPersonId,
                'p_order_id': orderId,
                'p_task_id': taskId,
                'p_customer_id': customerId,
                'p_total_order_amount': totalOrderAmount,
                'p_delivery_fee': deliveryFee,
                'p_payment_method': paymentMethod,
              });

              if (response != null) {
                notifyListeners();
                return true;
              }
              return false;
            } catch (e) {
              debugPrint('Error recording payment collection: $e');
              return false;
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'order_id': orderId,
            'task_id': taskId,
            'total_order_amount': totalOrderAmount,
            'delivery_fee': deliveryFee,
          },
        ) ??
        false;
  }

  /// Get pending service fees
  Future<List<Map<String, dynamic>>> getPendingServiceFees(
      String deliveryPersonId) async {
    return await _contextAware.executeWithContext(
          operation: 'getPendingServiceFees',
          service: 'ComprehensiveEarningsService',
          operationFunction: () async {
            try {
              final response = await client
                  .from('pending_service_fees')
                  .select('*')
                  .eq('delivery_person_id', deliveryPersonId);

              return (response as List<dynamic>)
                  .map((e) =>
                      Map<String, dynamic>.from(e as Map<String, dynamic>))
                  .toList();
            } catch (e) {
              debugPrint('Error fetching pending service fees: $e');
              return [];
            }
          },
          metadata: {'delivery_person_id': deliveryPersonId},
        ) as List<Map<String, dynamic>>? ??
        <Map<String, dynamic>>[];
  }

  /// Pay service fee to app using credit or bank transfer
  Future<bool> payServiceFee({
    required String deliveryPersonId,
    required String serviceFeeId,
    required String paymentMethod,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'payServiceFee',
          service: 'ComprehensiveEarningsService',
          operationFunction: () async {
            try {
              // If paying with credit, check if sufficient balance
              if (paymentMethod == 'credit') {
                final wallet = await getWalletInfo(deliveryPersonId);
                final serviceFee = await client
                    .from('delivery_service_fees')
                    .select('service_fee_amount')
                    .eq('id', serviceFeeId)
                    .single();

                if (wallet != null) {
                  final creditBalance =
                      (wallet['credit_balance'] ?? 0.0).toDouble();
                  final feeAmount =
                      (serviceFee['service_fee_amount'] ?? 0.0).toDouble();

                  if (creditBalance < feeAmount) {
                    debugPrint(
                        'Insufficient credit balance: $creditBalance < $feeAmount');
                    return false;
                  }
                }
              }

              final response =
                  await client.rpc('process_service_fee_payment', params: {
                'p_delivery_person_id': deliveryPersonId,
                'p_service_fee_id': serviceFeeId,
                'p_payment_method': paymentMethod,
              });

              if (response == true) {
                notifyListeners();
                return true;
              }
              return false;
            } catch (e) {
              debugPrint('Error paying service fee to app: $e');
              return false;
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'service_fee_id': serviceFeeId,
            'payment_method': paymentMethod,
          },
        ) ??
        false;
  }

  // =====================================================
  // BANK ACCOUNT MANAGEMENT
  // =====================================================

  /// Add bank account for delivery person
  Future<bool> addBankAccount({
    required String deliveryPersonId,
    required String bankName,
    required String accountHolderName,
    required String accountNumber,
    String? routingNumber,
    String? iban,
    String? swiftCode,
    bool isPrimary = false,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'addBankAccount',
          service: 'ComprehensiveEarningsService',
          operationFunction: () async {
            try {
              // If this is primary, unset other primary accounts
              if (isPrimary) {
                await client
                    .from('delivery_bank_accounts')
                    .update({'is_primary': false}).eq(
                        'delivery_person_id', deliveryPersonId);
              }

              await client.from('delivery_bank_accounts').insert({
                'delivery_person_id': deliveryPersonId,
                'bank_name': bankName,
                'account_holder_name': accountHolderName,
                'account_number': accountNumber,
                'routing_number': routingNumber,
                'iban': iban,
                'swift_code': swiftCode,
                'is_primary': isPrimary,
              });

              notifyListeners();
              return true;
            } catch (e) {
              debugPrint('Error adding bank account: $e');
              return false;
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'bank_name': bankName,
            'is_primary': isPrimary,
          },
        ) ??
        false;
  }

  /// Get bank accounts for delivery person
  Future<List<Map<String, dynamic>>> getBankAccounts(
      String deliveryPersonId) async {
    return await _contextAware.executeWithContext(
          operation: 'getBankAccounts',
          service: 'ComprehensiveEarningsService',
          operationFunction: () async {
            try {
              final response = await client
                  .from('delivery_bank_accounts')
                  .select('*')
                  .eq('delivery_person_id', deliveryPersonId)
                  .order('is_primary', ascending: false)
                  .order('created_at', ascending: false);

              return (response as List<dynamic>)
                  .map((e) =>
                      Map<String, dynamic>.from(e as Map<String, dynamic>))
                  .toList();
            } catch (e) {
              debugPrint('Error fetching bank accounts: $e');
              return [];
            }
          },
          metadata: {'delivery_person_id': deliveryPersonId},
        ) as List<Map<String, dynamic>>? ??
        <Map<String, dynamic>>[];
  }

  // =====================================================
  // EARNINGS ANALYTICS
  // =====================================================

  /// Get earnings summary for a period
  Future<Map<String, dynamic>?> getEarningsSummary({
    required String deliveryPersonId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getEarningsSummary',
      service: 'ComprehensiveEarningsService',
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

          // Calculate service fees
          final totalServiceFees = totalEarnings * serviceFeeRate;
          final netEarnings = totalEarnings - totalServiceFees;

          return {
            'total_base_fee': totalBaseFee,
            'total_distance_fee': totalDistanceFee,
            'total_performance_bonus': totalPerformanceBonus,
            'total_tip': totalTip,
            'total_penalty': totalPenalty,
            'total_earnings': totalEarnings,
            'total_service_fees': totalServiceFees,
            'net_earnings': netEarnings,
            'total_deliveries': totalDeliveries,
            'average_earnings_per_delivery':
                totalDeliveries > 0 ? totalEarnings / totalDeliveries : 0.0,
            'service_fee_rate': serviceFeeRate,
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

  /// Get daily earnings breakdown
  Future<List<Map<String, dynamic>>> getDailyEarnings({
    required String deliveryPersonId,
    int days = 30,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'getDailyEarnings',
          service: 'ComprehensiveEarningsService',
          operationFunction: () async {
            try {
              final startDate = DateTime.now().subtract(Duration(days: days));

              final response = await client
                  .from('delivery_earnings')
                  .select('total_earnings, created_at')
                  .eq('delivery_person_id', deliveryPersonId)
                  .gte('created_at', startDate.toIso8601String())
                  .order('created_at', ascending: true);

              // Group by date
              final Map<String, double> dailyEarnings = {};
              for (final earning in response) {
                final date = DateTime.parse(earning['created_at'])
                    .toIso8601String()
                    .split('T')[0];
                dailyEarnings[date] = (dailyEarnings[date] ?? 0.0) +
                    (earning['total_earnings'] ?? 0.0).toDouble();
              }

              // Convert to list
              final List<Map<String, dynamic>> result = [];
              for (int i = 0; i < days; i++) {
                final date = DateTime.now().subtract(Duration(days: i));
                final dateStr = date.toIso8601String().split('T')[0];
                final earnings = dailyEarnings[dateStr] ?? 0.0;
                final serviceFees = earnings * serviceFeeRate;
                final netEarnings = earnings - serviceFees;

                result.add({
                  'date': dateStr,
                  'gross_earnings': earnings,
                  'service_fees': serviceFees,
                  'net_earnings': netEarnings,
                });
              }

              return result.reversed.toList();
            } catch (e) {
              debugPrint('Error fetching daily earnings: $e');
              return [];
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'days': days,
          },
        ) as List<Map<String, dynamic>>? ??
        <Map<String, dynamic>>[];
  }

  // =====================================================
  // REAL-TIME STREAMS
  // =====================================================

  /// Stream for wallet balance updates
  Stream<Map<String, dynamic>?> onWalletBalanceChanged(
      String deliveryPersonId) {
    return _contextAware.executeWithContext(
      operation: 'onWalletBalanceChanged',
      service: 'ComprehensiveEarningsService',
      operationFunction: () async {
        return client
            .from('delivery_wallets')
            .stream(primaryKey: ['id'])
            .eq('delivery_person_id', deliveryPersonId)
            .map((rows) => rows.isNotEmpty ? rows.first : null);
      },
      metadata: {'delivery_person_id': deliveryPersonId},
    ) as Stream<Map<String, dynamic>?>;
  }

  /// Stream for earnings updates
  Stream<List<Map<String, dynamic>>> onEarningsChanged(
      String deliveryPersonId) {
    return _contextAware.executeWithContext(
      operation: 'onEarningsChanged',
      service: 'ComprehensiveEarningsService',
      operationFunction: () async {
        return client
            .from('delivery_earnings')
            .stream(primaryKey: ['id'])
            .eq('delivery_person_id', deliveryPersonId)
            .map((rows) => List<Map<String, dynamic>>.from(rows));
      },
      metadata: {'delivery_person_id': deliveryPersonId},
    ) as Stream<List<Map<String, dynamic>>>;
  }

  // =====================================================
  // UTILITY METHODS
  // =====================================================

  /// Format currency amount
  String formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} DA';
  }

  /// Get context summary for debugging
  Map<String, dynamic> getContextSummary() {
    return _contextAware.getContextSummary();
  }

  /// Dispose resources
  @override
  void dispose() {
    super.dispose();
  }
}
