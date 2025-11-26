import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'context_aware_service.dart';

class CashManagementService extends ChangeNotifier {
  static final CashManagementService _instance =
      CashManagementService._internal();
  factory CashManagementService() => _instance;
  CashManagementService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();

  // Initialize the service
  Future<void> initialize() async {
    await _contextAware.initialize();
    debugPrint('🚀 CashManagementService initialized with context tracking');
  }

  // Record cash collection from customer
  Future<bool> recordCashCollection({
    required String orderId,
    required String deliveryPersonId,
    required double collectedAmount,
    required String paymentMethod, // 'cash', 'card', etc.
    String? notes,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'recordCashCollection',
          service: 'CashManagementService',
          operationFunction: () async {
            try {
              final collectionData = {
                'order_id': orderId,
                'delivery_person_id': deliveryPersonId,
                'collected_amount': collectedAmount,
                'payment_method': paymentMethod,
                'collection_type': 'customer_payment',
                'status': 'collected',
                'collection_time': DateTime.now().toIso8601String(),
                'notes': notes,
                'created_at': DateTime.now().toIso8601String(),
              };

              await client.from('cash_collections').insert(collectionData);

              // Update order payment status
              await client.from('orders').update({
                'payment_status': 'collected',
                'payment_method': paymentMethod,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', orderId);

              debugPrint(
                  '✅ Cash collection recorded: $collectedAmount DA for order $orderId');
              notifyListeners();

              return true;
            } catch (e) {
              debugPrint('❌ Error recording cash collection: $e');
              return false;
            }
          },
          metadata: {
            'order_id': orderId,
            'delivery_person_id': deliveryPersonId,
            'collected_amount': collectedAmount,
            'payment_method': paymentMethod,
          },
        ) ??
        false;
  }

  // Record cash payment to delivery person
  Future<bool> recordCashPayment({
    required String deliveryPersonId,
    required double paymentAmount,
    required String paymentType, // 'salary', 'commission', 'bonus', etc.
    String? orderId,
    String? notes,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'recordCashPayment',
          service: 'CashManagementService',
          operationFunction: () async {
            try {
              final paymentData = {
                'delivery_person_id': deliveryPersonId,
                'payment_amount': paymentAmount,
                'payment_type': paymentType,
                'payment_method': 'cash',
                'status': 'paid',
                'payment_time': DateTime.now().toIso8601String(),
                'order_id': orderId,
                'notes': notes,
                'created_at': DateTime.now().toIso8601String(),
              };

              await client.from('cash_payments').insert(paymentData);

              debugPrint(
                  '✅ Cash payment recorded: $paymentAmount DA to delivery person $deliveryPersonId');
              notifyListeners();

              return true;
            } catch (e) {
              debugPrint('❌ Error recording cash payment: $e');
              return false;
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'payment_amount': paymentAmount,
            'payment_type': paymentType,
            'order_id': orderId,
          },
        ) ??
        false;
  }

  // Get cash collection summary for delivery person
  Future<Map<String, dynamic>?> getCashCollectionSummary({
    required String deliveryPersonId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getCashCollectionSummary',
      service: 'CashManagementService',
      operationFunction: () async {
        try {
          var query = client
              .from('cash_collections')
              .select(
                  'collected_amount, collection_time, payment_method, order_id')
              .eq('delivery_person_id', deliveryPersonId)
              .eq('status', 'collected');

          if (startDate != null) {
            query = query.gte('collection_time', startDate.toIso8601String());
          }
          if (endDate != null) {
            query = query.lte('collection_time', endDate.toIso8601String());
          }

          final collections = await query;

          double totalCollected = 0.0;
          int totalCollections = 0;
          double cashCollections = 0.0;
          double cardCollections = 0.0;

          for (final collection in collections) {
            totalCollections++;
            final amount = (collection['collected_amount'] ?? 0.0).toDouble();
            totalCollected += amount;

            final method = collection['payment_method'];
            if (method == 'cash') {
              cashCollections += amount;
            } else if (method == 'card') {
              cardCollections += amount;
            }
          }

          return {
            'total_collections': totalCollections,
            'total_collected': totalCollected,
            'cash_collections': cashCollections,
            'card_collections': cardCollections,
            'average_collection':
                totalCollections > 0 ? totalCollected / totalCollections : 0.0,
          };
        } catch (e) {
          debugPrint('❌ Error fetching cash collection summary: $e');
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

  // Get cash payment summary for delivery person
  Future<Map<String, dynamic>?> getCashPaymentSummary({
    required String deliveryPersonId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getCashPaymentSummary',
      service: 'CashManagementService',
      operationFunction: () async {
        try {
          var query = client
              .from('cash_payments')
              .select('payment_amount, payment_time, payment_type, order_id')
              .eq('delivery_person_id', deliveryPersonId)
              .eq('status', 'paid');

          if (startDate != null) {
            query = query.gte('payment_time', startDate.toIso8601String());
          }
          if (endDate != null) {
            query = query.lte('payment_time', endDate.toIso8601String());
          }

          final payments = await query;

          double totalPaid = 0.0;
          int totalPayments = 0;
          double salaryPayments = 0.0;
          double commissionPayments = 0.0;
          double bonusPayments = 0.0;

          for (final payment in payments) {
            totalPayments++;
            final amount = (payment['payment_amount'] ?? 0.0).toDouble();
            totalPaid += amount;

            final type = payment['payment_type'];
            if (type == 'salary') {
              salaryPayments += amount;
            } else if (type == 'commission') {
              commissionPayments += amount;
            } else if (type == 'bonus') {
              bonusPayments += amount;
            }
          }

          return {
            'total_payments': totalPayments,
            'total_paid': totalPaid,
            'salary_payments': salaryPayments,
            'commission_payments': commissionPayments,
            'bonus_payments': bonusPayments,
            'average_payment':
                totalPayments > 0 ? totalPaid / totalPayments : 0.0,
          };
        } catch (e) {
          debugPrint('❌ Error fetching cash payment summary: $e');
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

  // Get cash reconciliation for delivery person (collections vs payments)
  Future<Map<String, dynamic>?> getCashReconciliation({
    required String deliveryPersonId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getCashReconciliation',
      service: 'CashManagementService',
      operationFunction: () async {
        try {
          // Get collections and payments in parallel
          final collectionSummary = await getCashCollectionSummary(
            deliveryPersonId: deliveryPersonId,
            startDate: startDate,
            endDate: endDate,
          );

          final paymentSummary = await getCashPaymentSummary(
            deliveryPersonId: deliveryPersonId,
            startDate: startDate,
            endDate: endDate,
          );

          if (collectionSummary == null || paymentSummary == null) {
            return null;
          }

          final totalCollected = collectionSummary['total_collected'] ?? 0.0;
          final totalPaid = paymentSummary['total_paid'] ?? 0.0;
          final balance = totalCollected - totalPaid;

          return {
            'total_collected': totalCollected,
            'total_paid': totalPaid,
            'current_balance': balance,
            'status': balance >= 0 ? 'positive' : 'negative',
            'collections_summary': collectionSummary,
            'payments_summary': paymentSummary,
            'reconciliation_date': DateTime.now().toIso8601String(),
          };
        } catch (e) {
          debugPrint('❌ Error fetching cash reconciliation: $e');
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

  // Get all cash transactions for delivery person
  Future<List<Map<String, dynamic>>?> getCashTransactions({
    required String deliveryPersonId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getCashTransactions',
      service: 'CashManagementService',
      operationFunction: () async {
        try {
          // Get collections
          var collectionQuery = client.from('cash_collections').select('''
                order_id,
                collected_amount,
                payment_method,
                collection_time,
                notes,
                'collection' as transaction_type
              ''').eq('delivery_person_id', deliveryPersonId);

          if (startDate != null) {
            collectionQuery = collectionQuery.gte(
                'collection_time', startDate.toIso8601String());
          }
          if (endDate != null) {
            collectionQuery = collectionQuery.lte(
                'collection_time', endDate.toIso8601String());
          }

          final collections = await collectionQuery;

          // Get payments
          var paymentQuery = client.from('cash_payments').select('''
                order_id,
                payment_amount,
                payment_type,
                payment_time,
                notes,
                'payment' as transaction_type
              ''').eq('delivery_person_id', deliveryPersonId);

          if (startDate != null) {
            paymentQuery =
                paymentQuery.gte('payment_time', startDate.toIso8601String());
          }
          if (endDate != null) {
            paymentQuery =
                paymentQuery.lte('payment_time', endDate.toIso8601String());
          }

          final payments = await paymentQuery;

          // Combine and sort transactions
          final allTransactions = <Map<String, dynamic>>[];

          // Add collections
          for (final collection in collections) {
            allTransactions.add({
              ...collection,
              'amount': collection['collected_amount'],
              'date': collection['collection_time'],
              'type': collection['transaction_type'],
            });
          }

          // Add payments (as negative amounts)
          for (final payment in payments) {
            allTransactions.add({
              ...payment,
              'amount': -payment['payment_amount'],
              'date': payment['payment_time'],
              'type': payment['transaction_type'],
            });
          }

          // Sort by date (most recent first)
          allTransactions.sort((a, b) {
            final dateA = DateTime.parse(a['date']);
            final dateB = DateTime.parse(b['date']);
            return dateB.compareTo(dateA);
          });

          return allTransactions.take(limit).toList();
        } catch (e) {
          debugPrint('❌ Error fetching cash transactions: $e');
          return null;
        }
      },
      metadata: {
        'delivery_person_id': deliveryPersonId,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'limit': limit,
      },
    );
  }

  // Generate cash settlement report
  Future<Map<String, dynamic>?> generateSettlementReport({
    required String deliveryPersonId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'generateSettlementReport',
      service: 'CashManagementService',
      operationFunction: () async {
        try {
          final reconciliation = await getCashReconciliation(
            deliveryPersonId: deliveryPersonId,
            startDate: startDate,
            endDate: endDate,
          );

          if (reconciliation == null) {
            return null;
          }

          final report = {
            'delivery_person_id': deliveryPersonId,
            'period': {
              'start_date': startDate?.toIso8601String() ?? 'All time',
              'end_date': endDate?.toIso8601String() ?? 'All time',
            },
            'reconciliation': reconciliation,
            'generated_at': DateTime.now().toIso8601String(),
            'status': reconciliation['current_balance'] >= 0
                ? 'settled'
                : 'pending_settlement',
          };

          // Store settlement report
          await client.from('cash_settlement_reports').insert(report);

          return report;
        } catch (e) {
          debugPrint('❌ Error generating settlement report: $e');
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

  // Get context summary for debugging
  Map<String, dynamic> getContextSummary() {
    return _contextAware.getContextSummary();
  }
}
