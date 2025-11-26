import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to track and link data events, business logic, and implementation patterns
/// This helps maintain consistency and avoid breaking existing flows
class ContextTrackingService extends ChangeNotifier {
  static final ContextTrackingService _instance =
      ContextTrackingService._internal();
  factory ContextTrackingService() => _instance;
  ContextTrackingService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Track existing implementations and patterns
  final Map<String, List<ImplementationPattern>> _implementationPatterns = {};
  final Map<String, List<DataFlow>> _dataFlows = {};
  final Map<String, List<BusinessRule>> _businessRules = {};
  final Map<String, List<DatabaseOperation>> _databaseOperations = {};

  // Event chain tracking
  final Map<String, List<EventChain>> _eventChains = {};

  // ==================== IMPLEMENTATION PATTERNS ====================

  /// Track a new implementation pattern
  void trackImplementationPattern({
    required String feature,
    required String pattern,
    required String description,
    required String filePath,
    required List<String> relatedServices,
    Map<String, dynamic>? metadata,
  }) {
    if (!_implementationPatterns.containsKey(feature)) {
      _implementationPatterns[feature] = [];
    }

    _implementationPatterns[feature]!.add(ImplementationPattern(
      pattern: pattern,
      description: description,
      filePath: filePath,
      relatedServices: relatedServices,
      metadata: metadata,
      timestamp: DateTime.now(),
    ));

    debugPrint('📋 Tracked implementation pattern: $pattern for $feature');
  }

  /// Get existing patterns for a feature
  List<ImplementationPattern> getImplementationPatterns(String feature) {
    return _implementationPatterns[feature] ?? [];
  }

  /// Check if a pattern already exists
  bool hasImplementationPattern(String feature, String pattern) {
    final patterns = _implementationPatterns[feature] ?? [];
    return patterns.any((p) => p.pattern == pattern);
  }

  // ==================== DATA FLOWS ====================

  /// Track a data flow between services
  void trackDataFlow({
    required String flowName,
    required String source,
    required String destination,
    required String dataType,
    required List<String> triggers,
    Map<String, dynamic>? conditions,
  }) {
    if (!_dataFlows.containsKey(flowName)) {
      _dataFlows[flowName] = [];
    }

    _dataFlows[flowName]!.add(DataFlow(
      source: source,
      destination: destination,
      dataType: dataType,
      triggers: triggers,
      conditions: conditions,
      timestamp: DateTime.now(),
    ));

    debugPrint('🔄 Tracked data flow: $source → $destination ($dataType)');
  }

  /// Get data flows for a service
  List<DataFlow> getDataFlows(String serviceName) {
    final flows = <DataFlow>[];
    for (final flowList in _dataFlows.values) {
      flows.addAll(flowList.where((flow) =>
          flow.source == serviceName || flow.destination == serviceName));
    }
    return flows;
  }

  // ==================== BUSINESS RULES ====================

  /// Track a business rule
  void trackBusinessRule({
    required String ruleName,
    required String description,
    required String category,
    required List<String> affectedServices,
    Map<String, dynamic>? constraints,
  }) {
    if (!_businessRules.containsKey(category)) {
      _businessRules[category] = [];
    }

    _businessRules[category]!.add(BusinessRule(
      name: ruleName,
      description: description,
      category: category,
      affectedServices: affectedServices,
      constraints: constraints,
      timestamp: DateTime.now(),
    ));

    debugPrint('📋 Tracked business rule: $ruleName ($category)');
  }

  /// Get business rules for a category
  List<BusinessRule> getBusinessRules(String category) {
    return _businessRules[category] ?? [];
  }

  /// Check if a business rule exists
  bool hasBusinessRule(String category, String ruleName) {
    final rules = _businessRules[category] ?? [];
    return rules.any((r) => r.name == ruleName);
  }

  // ==================== DATABASE OPERATIONS ====================

  /// Track a database operation
  void trackDatabaseOperation({
    required String operation,
    required String table,
    required String operationType, // insert, update, delete, select
    required Map<String, dynamic> data,
    required List<String> affectedServices,
    Map<String, dynamic>? rlsPolicies,
  }) {
    if (!_databaseOperations.containsKey(table)) {
      _databaseOperations[table] = [];
    }

    _databaseOperations[table]!.add(DatabaseOperation(
      operation: operation,
      table: table,
      operationType: operationType,
      data: data,
      affectedServices: affectedServices,
      rlsPolicies: rlsPolicies,
      timestamp: DateTime.now(),
    ));

    debugPrint('🗄️ Tracked database operation: $operationType on $table');
  }

  /// Get database operations for a table
  List<DatabaseOperation> getDatabaseOperations(String table) {
    return _databaseOperations[table] ?? [];
  }

  /// Get RLS policies for a table
  List<Map<String, dynamic>?> getRLSPolicies(String table) {
    final operations = _databaseOperations[table] ?? [];
    return operations
        .map((op) => op.rlsPolicies)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  // ==================== EVENT CHAINS ====================

  /// Track an event chain
  void trackEventChain({
    required String chainName,
    required List<EventStep> steps,
    required String trigger,
    Map<String, dynamic>? metadata,
  }) {
    if (!_eventChains.containsKey(chainName)) {
      _eventChains[chainName] = [];
    }

    _eventChains[chainName]!.add(EventChain(
      steps: steps,
      trigger: trigger,
      metadata: metadata,
      timestamp: DateTime.now(),
    ));

    debugPrint('⛓️ Tracked event chain: $chainName (${steps.length} steps)');
  }

  /// Get event chains for a trigger
  List<EventChain> getEventChains(String trigger) {
    final chains = <EventChain>[];
    for (final chainList in _eventChains.values) {
      chains.addAll(chainList.where((chain) => chain.trigger == trigger));
    }
    return chains;
  }

  // ==================== VALIDATION & WARNINGS ====================

  /// Check if implementing a feature might break existing flows
  List<String> checkPotentialConflicts({
    required String feature,
    required List<String> services,
    required List<String> tables,
  }) {
    final warnings = <String>[];

    // Check for conflicting business rules
    for (final category in _businessRules.keys) {
      final rules = _businessRules[category]!;
      for (final rule in rules) {
        if (rule.affectedServices
            .any((service) => services.contains(service))) {
          warnings.add(
              '⚠️ Feature "$feature" may conflict with business rule "${rule.name}" in $category');
        }
      }
    }

    // Check for conflicting data flows
    for (final flowName in _dataFlows.keys) {
      final flows = _dataFlows[flowName]!;
      for (final flow in flows) {
        if (services.contains(flow.source) ||
            services.contains(flow.destination)) {
          warnings.add(
              '⚠️ Feature "$feature" may affect data flow: ${flow.source} → ${flow.destination}');
        }
      }
    }

    // Check for RLS policy conflicts
    for (final table in tables) {
      final operations = _databaseOperations[table] ?? [];
      for (final operation in operations) {
        if (operation.rlsPolicies != null) {
          warnings.add(
              '⚠️ Feature "$feature" will interact with RLS policies on table "$table"');
        }
      }
    }

    return warnings;
  }

  /// Suggest existing patterns to reuse
  List<ImplementationPattern> suggestReusablePatterns(String feature) {
    final suggestions = <ImplementationPattern>[];

    for (final patterns in _implementationPatterns.values) {
      for (final pattern in patterns) {
        if (pattern.description.toLowerCase().contains(feature.toLowerCase()) ||
            pattern.relatedServices.any((service) =>
                service.toLowerCase().contains(feature.toLowerCase()))) {
          suggestions.add(pattern);
        }
      }
    }

    return suggestions;
  }

  // ==================== INITIALIZATION ====================

  bool _isInitialized = false;

  /// Initialize with existing patterns from the codebase (only once)
  Future<void> initialize() async {
    if (_isInitialized) return; // Prevent duplicate initialization
    _isInitialized = true;

    // Track existing restaurant operations (relevant to food delivery app)
    trackDatabaseOperation(
      operation: 'Restaurant CRUD Operations',
      table: 'restaurants',
      operationType: 'insert',
      data: {'owner_id': 'auth.uid()', 'is_active': true},
      affectedServices: ['RestaurantService', 'SupabaseService'],
      rlsPolicies: {
        'insert': 'auth.uid() = owner_id',
        'select': 'is_active = true OR auth.uid() = owner_id',
        'update': 'auth.uid() = owner_id',
        'delete': 'auth.uid() = owner_id',
      },
    );

    // Track order flow (relevant to food delivery app)
    trackEventChain(
      chainName: 'Order Creation Flow',
      trigger: 'user_creates_order',
      steps: [
        EventStep(
          service: 'OrderService',
          operation: 'createOrder',
          description: 'Create order record',
        ),
        EventStep(
          service: 'PaymentService',
          operation: 'processOrderPayment',
          description: 'Process order payment',
        ),
        EventStep(
          service: 'NotificationService',
          operation: 'sendOrderNotification',
          description: 'Send confirmation to user and restaurant',
        ),
        EventStep(
          service: 'RestaurantService',
          operation: 'updateOrderStatus',
          description: 'Update restaurant order status',
        ),
      ],
    );

    // Track payment flow (relevant to food delivery app)
    trackEventChain(
      chainName: 'Payment Processing Flow',
      trigger: 'payment_processed',
      steps: [
        EventStep(
          service: 'PaymentService',
          operation: 'updatePaymentStatus',
          description: 'Update payment status to completed',
        ),
        EventStep(
          service: 'OrderService',
          operation: 'updateOrderStatus',
          description: 'Update order status to confirmed',
        ),
        EventStep(
          service: 'NotificationService',
          operation: 'sendPaymentNotification',
          description: 'Send payment confirmation notification',
        ),
      ],
    );

    // Track business rules (relevant to food delivery app)
    trackBusinessRule(
      ruleName: 'Order Cancellation Policy',
      description: 'Refund policy based on cancellation timing',
      category: 'orders',
      affectedServices: ['OrderService', 'PaymentService'],
      constraints: {
        'before_preparation': '100% refund',
        'during_preparation': '50% refund',
        'after_preparation': 'No refund',
      },
    );

    trackBusinessRule(
      ruleName: 'Restaurant Verification Required',
      description: 'Restaurants must be verified before accepting orders',
      category: 'restaurants',
      affectedServices: ['RestaurantService', 'UserService'],
      constraints: {
        'verification_required': true,
        'document_upload': true,
        'background_check': true,
      },
    );

    debugPrint(
        '✅ ContextTrackingService initialized with ${_implementationPatterns.length} patterns');
  }

  // ==================== UTILITY METHODS ====================

  /// Get summary of tracked context
  Map<String, dynamic> getContextSummary() {
    return {
      'implementationPatterns': _implementationPatterns.length,
      'dataFlows': _dataFlows.length,
      'businessRules': _businessRules.length,
      'databaseOperations': _databaseOperations.length,
      'eventChains': _eventChains.length,
    };
  }

  /// Clear all tracked data (for testing)
  void clearAll() {
    _implementationPatterns.clear();
    _dataFlows.clear();
    _businessRules.clear();
    _databaseOperations.clear();
    _eventChains.clear();
    notifyListeners();
  }
}

// ==================== DATA CLASSES ====================

class ImplementationPattern {
  final String pattern;
  final String description;
  final String filePath;
  final List<String> relatedServices;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  ImplementationPattern({
    required this.pattern,
    required this.description,
    required this.filePath,
    required this.relatedServices,
    required this.timestamp,
    this.metadata,
  });
}

class DataFlow {
  final String source;
  final String destination;
  final String dataType;
  final List<String> triggers;
  final Map<String, dynamic>? conditions;
  final DateTime timestamp;

  DataFlow({
    required this.source,
    required this.destination,
    required this.dataType,
    required this.triggers,
    required this.timestamp,
    this.conditions,
  });
}

class BusinessRule {
  final String name;
  final String description;
  final String category;
  final List<String> affectedServices;
  final Map<String, dynamic>? constraints;
  final DateTime timestamp;

  BusinessRule({
    required this.name,
    required this.description,
    required this.category,
    required this.affectedServices,
    required this.timestamp,
    this.constraints,
  });
}

class DatabaseOperation {
  final String operation;
  final String table;
  final String operationType;
  final Map<String, dynamic> data;
  final List<String> affectedServices;
  final Map<String, dynamic>? rlsPolicies;
  final DateTime timestamp;

  DatabaseOperation({
    required this.operation,
    required this.table,
    required this.operationType,
    required this.data,
    required this.affectedServices,
    required this.timestamp,
    this.rlsPolicies,
  });
}

class EventChain {
  final List<EventStep> steps;
  final String trigger;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  EventChain({
    required this.steps,
    required this.trigger,
    required this.timestamp,
    this.metadata,
  });
}

class EventStep {
  final String service;
  final String operation;
  final String description;
  final Map<String, dynamic>? data;

  EventStep({
    required this.service,
    required this.operation,
    required this.description,
    this.data,
  });
}
