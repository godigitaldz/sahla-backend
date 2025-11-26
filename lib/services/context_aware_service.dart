import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'context_tracking_service.dart';

/// Wrapper service that provides context-aware implementation guidance
/// This service helps maintain consistency and avoid breaking existing flows
class ContextAwareService {
  static final ContextAwareService _instance = ContextAwareService._internal();
  factory ContextAwareService() => _instance;
  ContextAwareService._internal();

  final ContextTrackingService _contextTracker = ContextTrackingService();

  // ==================== FEATURE IMPLEMENTATION GUIDANCE ====================

  /// Analyze a new feature implementation for potential conflicts
  Future<FeatureAnalysis> analyzeFeature({
    required String featureName,
    required List<String> services,
    required List<String> tables,
    required List<String> operations,
  }) async {
    debugPrint('🔍 Analyzing feature: $featureName');

    final warnings = _contextTracker.checkPotentialConflicts(
      feature: featureName,
      services: services,
      tables: tables,
    );

    final reusablePatterns =
        _contextTracker.suggestReusablePatterns(featureName);
    final existingFlows = _getExistingFlows(services);
    final rlsPolicies = _getRLSPolicies(tables);

    return FeatureAnalysis(
      featureName: featureName,
      warnings: warnings,
      reusablePatterns: reusablePatterns,
      existingFlows: existingFlows,
      rlsPolicies: rlsPolicies,
      recommendations: _generateRecommendations(
        featureName,
        warnings,
        reusablePatterns,
        existingFlows,
        rlsPolicies,
      ),
    );
  }

  /// Get existing data flows for services
  List<DataFlow> _getExistingFlows(List<String> services) {
    final flows = <DataFlow>[];
    for (final service in services) {
      flows.addAll(_contextTracker.getDataFlows(service));
    }
    return flows;
  }

  /// Get RLS policies for tables
  List<Map<String, dynamic>?> _getRLSPolicies(List<String> tables) {
    final policies = <Map<String, dynamic>?>[];
    for (final table in tables) {
      policies.addAll(_contextTracker.getRLSPolicies(table));
    }
    return policies;
  }

  /// Generate implementation recommendations
  List<String> _generateRecommendations(
    String featureName,
    List<String> warnings,
    List<ImplementationPattern> reusablePatterns,
    List<DataFlow> existingFlows,
    List<Map<String, dynamic>?> rlsPolicies,
  ) {
    final recommendations = <String>[];

    // Suggest reusable patterns
    if (reusablePatterns.isNotEmpty) {
      recommendations
          .add('✅ Found ${reusablePatterns.length} reusable patterns:');
      for (final pattern in reusablePatterns.take(3)) {
        recommendations.add('   - ${pattern.pattern}: ${pattern.description}');
      }
    }

    // Suggest existing flows to follow
    if (existingFlows.isNotEmpty) {
      recommendations.add('🔄 Follow existing data flows:');
      for (final flow in existingFlows.take(3)) {
        recommendations.add(
            '   - ${flow.source} → ${flow.destination} (${flow.dataType})');
      }
    }

    // RLS policy considerations
    if (rlsPolicies.isNotEmpty) {
      recommendations.add('🔒 Consider RLS policies for database operations');
    }

    // Warning-specific recommendations
    if (warnings.isNotEmpty) {
      recommendations.add('⚠️ Address potential conflicts:');
      for (final warning in warnings.take(3)) {
        recommendations.add('   - $warning');
      }
    }

    return recommendations;
  }

  // ==================== SERVICE IMPLEMENTATION HELPERS ====================

  /// Create a context-aware service method
  Future<T?> executeWithContext<T>({
    required String operation,
    required String service,
    required Future<T?> Function() operationFunction,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('🔧 Executing $operation in $service with context tracking');

      // Track the operation
      _contextTracker.trackImplementationPattern(
        feature: operation,
        pattern: 'service_method',
        description: 'Executing $operation in $service',
        filePath: 'lib/services/${service.toLowerCase()}.dart',
        relatedServices: [service],
        metadata: metadata,
      );

      // Execute the operation
      final result = await operationFunction();

      debugPrint('✅ Successfully executed $operation in $service');
      return result;
    } catch (e) {
      debugPrint('❌ Error executing $operation in $service: $e');
      rethrow;
    }
  }

  /// Create a context-aware database operation
  Future<T?> executeDatabaseOperation<T>({
    required String operation,
    required String table,
    required String operationType,
    required Future<T?> Function() operationFunction,
    Map<String, dynamic>? data,
    Map<String, dynamic>? rlsPolicies,
  }) async {
    try {
      debugPrint(
          '🗄️ Executing $operationType on $table with context tracking');

      // Track the database operation
      _contextTracker.trackDatabaseOperation(
        operation: operation,
        table: table,
        operationType: operationType,
        data: data ?? {},
        affectedServices: ['DatabaseService'],
        rlsPolicies: rlsPolicies,
      );

      // Execute the operation
      final result = await operationFunction();

      debugPrint('✅ Successfully executed $operationType on $table');
      return result;
    } catch (e) {
      debugPrint('❌ Error executing $operationType on $table: $e');
      rethrow;
    }
  }

  // ==================== EVENT CHAIN HELPERS ====================

  /// Execute an event chain with proper tracking
  Future<bool> executeEventChain({
    required String chainName,
    required List<EventStep> steps,
    required String trigger,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('⛓️ Executing event chain: $chainName');

      // Track the event chain
      _contextTracker.trackEventChain(
        chainName: chainName,
        steps: steps,
        trigger: trigger,
        metadata: metadata,
      );

      // Execute each step
      for (final step in steps) {
        debugPrint(
            '   → ${step.service}.${step.operation}: ${step.description}');

        // Here you would actually call the service method
        // For now, we'll just simulate the execution
        await Future.delayed(const Duration(milliseconds: 100));
      }

      debugPrint('✅ Successfully executed event chain: $chainName');
      return true;
    } catch (e) {
      debugPrint('❌ Error executing event chain $chainName: $e');
      return false;
    }
  }

  // ==================== BUSINESS RULE HELPERS ====================

  /// Check if a business rule applies
  bool checkBusinessRule({
    required String category,
    required String ruleName,
    Map<String, dynamic>? context,
  }) {
    final rules = _contextTracker.getBusinessRules(category);
    final rule = rules.firstWhere(
      (r) => r.name == ruleName,
      orElse: () => BusinessRule(
        name: ruleName,
        description: 'Unknown rule',
        category: category,
        affectedServices: [],
        timestamp: DateTime.now(),
      ),
    );

    if (rule.constraints != null && context != null) {
      // Check if context matches constraints
      for (final entry in rule.constraints!.entries) {
        if (context.containsKey(entry.key)) {
          final contextValue = context[entry.key];
          final constraintValue = entry.value;

          if (contextValue != constraintValue) {
            debugPrint('⚠️ Business rule violation: $ruleName - ${entry.key}');
            return false;
          }
        }
      }
    }

    return true;
  }

  /// Apply business rules to an operation
  Future<bool> applyBusinessRules({
    required String category,
    required Map<String, dynamic> context,
  }) async {
    final rules = _contextTracker.getBusinessRules(category);

    for (final rule in rules) {
      if (!checkBusinessRule(
        category: category,
        ruleName: rule.name,
        context: context,
      )) {
        debugPrint('❌ Business rule violation: ${rule.name}');
        return false;
      }
    }

    return true;
  }

  /// Track an event with context
  void trackEvent({
    required String eventName,
    required String service,
    required String operation,
    Map<String, dynamic>? metadata,
  }) {
    debugPrint('📊 Tracking event: $eventName in $service.$operation');

    _contextTracker.trackImplementationPattern(
      feature: eventName,
      pattern: 'event_tracking',
      description: 'Tracking $eventName in $service',
      filePath: 'lib/services/${service.toLowerCase()}.dart',
      relatedServices: [service],
      metadata: metadata,
    );
    // Optional: send to Supabase 'analytics' table if exists
    try {
      Supabase.instance.client.from('analytics').insert({
        'event_name': eventName,
        'service': service,
        'operation': operation,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // ==================== PATTERN SUGGESTION ====================

  /// Suggest implementation patterns for a feature
  List<ImplementationPattern> suggestPatterns(String feature) {
    return _contextTracker.suggestReusablePatterns(feature);
  }

  /// Get existing patterns for a specific service
  List<ImplementationPattern> getServicePatterns(String service) {
    return _contextTracker.getImplementationPatterns(service);
  }

  // ==================== CONTEXT SUMMARY ====================

  /// Get a summary of tracked context
  Map<String, dynamic> getContextSummary() {
    return _contextTracker.getContextSummary();
  }

  /// Initialize the context tracking service
  Future<void> initialize() async {
    await _contextTracker.initialize();
    debugPrint('🚀 ContextAwareService initialized');
  }
}

// ==================== DATA CLASSES ====================

class FeatureAnalysis {
  final String featureName;
  final List<String> warnings;
  final List<ImplementationPattern> reusablePatterns;
  final List<DataFlow> existingFlows;
  final List<Map<String, dynamic>?> rlsPolicies;
  final List<String> recommendations;

  FeatureAnalysis({
    required this.featureName,
    required this.warnings,
    required this.reusablePatterns,
    required this.existingFlows,
    required this.rlsPolicies,
    required this.recommendations,
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasReusablePatterns => reusablePatterns.isNotEmpty;
  bool get hasExistingFlows => existingFlows.isNotEmpty;
  bool get hasRLSPolicies => rlsPolicies.isNotEmpty;

  void printAnalysis() {
    debugPrint('📊 Feature Analysis: $featureName');
    debugPrint('   Warnings: ${warnings.length}');
    debugPrint('   Reusable Patterns: ${reusablePatterns.length}');
    debugPrint('   Existing Flows: ${existingFlows.length}');
    debugPrint('   RLS Policies: ${rlsPolicies.length}');

    if (recommendations.isNotEmpty) {
      debugPrint('   Recommendations:');
      for (final recommendation in recommendations) {
        debugPrint('     $recommendation');
      }
    }
  }
}
