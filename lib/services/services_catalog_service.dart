import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceOption {
  final String key;
  final String name;
  final String icon; // material icon name or url

  const ServiceOption(
      {required this.key, required this.name, required this.icon});
}

class ServicesCatalogService {
  final SupabaseClient _client;
  ServicesCatalogService(this._client);

  Future<List<ServiceOption>> fetchAvailableServices() async {
    final response = await _client
        .from('services')
        .select('key,name,icon')
        .order('ordering')
        .limit(20);

    return (response as List<dynamic>)
        .map((row) {
          return ServiceOption(
            key: (row['key'] ?? '').toString(),
            name: (row['name'] ?? '').toString(),
            icon: (row['icon'] ?? '').toString(),
          );
        })
        .where((s) => s.key.isNotEmpty)
        .toList();
  }
}
