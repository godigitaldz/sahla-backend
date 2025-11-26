import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InfoService {
  static final InfoService _instance = InfoService._internal();
  factory InfoService() => _instance;
  InfoService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> getAttribute({
    required String namespace,
    required String entity,
    required String entityId,
    required String attribute,
    String defaultValue = '',
  }) async {
    try {
      final res = await _client.rpc('get_info', params: {
        'p_namespace': namespace,
        'p_entity': entity,
        'p_entity_id': entityId,
        'p_attribute': attribute,
      });
      if (res == null) return defaultValue;
      final value = res.toString();
      return value.isEmpty ? defaultValue : value;
    } catch (e) {
      debugPrint('InfoService.getAttribute error: $e');
      return defaultValue;
    }
  }

  Future<Map<String, dynamic>> getEntity({
    required String namespace,
    required String entity,
    required String entityId,
  }) async {
    try {
      final res = await _client.rpc('get_entity_info', params: {
        'p_namespace': namespace,
        'p_entity': entity,
        'p_entity_id': entityId,
      });
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      if (res is String && res.isNotEmpty) {
        try {
          final decoded = jsonDecode(res);
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }
      return <String, dynamic>{};
    } catch (e) {
      debugPrint('InfoService.getEntity error: $e');
      return <String, dynamic>{};
    }
  }

  // Overlay non-null, non-empty string attributes from info into target map
  Map<String, dynamic> overlayStrings({
    required Map<String, dynamic> target,
    required Map<String, dynamic> info,
    required List<String> keys,
  }) {
    final out = Map<String, dynamic>.from(target);
    for (final k in keys) {
      final v = info[k];
      if (v is String && v.trim().isNotEmpty) {
        out[k] = v;
      }
    }
    return out;
  }
}
