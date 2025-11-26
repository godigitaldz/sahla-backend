// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // Removed local persistence
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../utils/price_formatter.dart';

// Using Flutter's built-in Locale instead of custom enum

class SettingsService extends ChangeNotifier {
  // Current settings (in-memory only)
  Locale _currentLocale = const Locale('en');
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _analyticsEnabled = true;

  // Getters
  Locale get currentLocale => _currentLocale;
  String get currentLanguage => _currentLocale.languageCode;
  bool get isDarkMode => _isDarkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get locationEnabled => _locationEnabled;
  bool get analyticsEnabled => _analyticsEnabled;

  // Singleton pattern
  static SettingsService? _instance;
  factory SettingsService() {
    _instance ??= SettingsService._internal();
    return _instance!;
  }
  SettingsService._internal() {
    // Constructor is now safe - no Supabase access during construction
  }

  // Reset singleton for hot reload
  static void reset() {
    _instance = null;
  }

  // Supabase - completely safe getter that never throws
  supa.SupabaseClient? get _supabase {
    try {
      return supa.Supabase.instance.client;
    } catch (e) {
      return null; // Return null instead of throwing
    }
  }

  supa.RealtimeChannel? _settingsChannel;

  /// Initialize settings (DB load + realtime subscribe)
  Future<void> initialize() async {
    // Only initialize if Supabase is available
    if (_supabase == null) {
      debugPrint(
          'SettingsService: Supabase not ready, skipping initialization');
      return;
    }
    await loadFromDb();
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    final supabase = _supabase;
    if (supabase == null) return;

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      _settingsChannel?.unsubscribe();
      _settingsChannel = supabase
          .channel('user_settings_$userId')
          .onPostgresChanges(
            event: supa.PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_settings',
            filter: supa.PostgresChangeFilter(
              type: supa.PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              // Refresh from DB on any change for this user
              loadFromDb();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  /// Load settings from DB (user_settings)
  Future<void> loadFromDb() async {
    final supabase = _supabase;
    if (supabase == null) return;

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final row = await supabase
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return;

      // Map DB -> local
      final languageCode = (row['language'] as String?)?.toLowerCase() ?? 'en';
      _currentLocale = Locale(languageCode);
      _isDarkMode = (row['is_dark_mode'] as bool?) ?? false;
      _notificationsEnabled = (row['notifications_enabled'] as bool?) ?? true;
      _locationEnabled = (row['location_enabled'] as bool?) ?? true;
      _analyticsEnabled = (row['analytics_enabled'] as bool?) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings from DB: $e');
    }
  }

  /// Save settings to DB (direct upsert into user_settings)
  Future<void> saveToDb() async {
    final supabase = _supabase;
    if (supabase == null) return;

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase.from('user_settings').upsert({
        'user_id': userId,
        'language': _currentLocale.languageCode,
        'currency': 'DZD', // Always DZD (Dinar Algerienne)
        'is_dark_mode': _isDarkMode,
        'notifications_enabled': _notificationsEnabled,
        'location_enabled': _locationEnabled,
        'analytics_enabled': _analyticsEnabled,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('Error saving settings to DB: $e');
    }
  }

  /// Setters: update local, persist to DB, notify
  Future<void> setLanguage(Locale locale) async {
    _currentLocale = locale;
    notifyListeners();
    await saveToDb();
  }

  /// Set language by code (for backward compatibility with language switcher)
  Future<void> setLanguageCode(String languageCode) async {
    await setLanguage(Locale(languageCode));
  }

  Future<void> setDarkMode(bool enabled) async {
    _isDarkMode = enabled;
    notifyListeners();
    await saveToDb();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();
    await saveToDb();
  }

  Future<void> setLocationEnabled(bool enabled) async {
    _locationEnabled = enabled;
    notifyListeners();
    await saveToDb();
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    _analyticsEnabled = enabled;
    notifyListeners();
    await saveToDb();
  }

  /// Format price with Dinar Algerienne (DA)
  String formatPrice(double amount) {
    return '${PriceFormatter.formatPrice(amount.toString())} DA';
  }

  /// Reset all settings to defaults (in-memory + persist)
  Future<void> resetToDefaults() async {
    _currentLocale = const Locale('en');
    _isDarkMode = false;
    _notificationsEnabled = true;
    _locationEnabled = true;
    _analyticsEnabled = true;
    notifyListeners();
    await saveToDb();
  }

  Map<String, String> getAppInfo() {
    return {
      'version': '1.0.0',
      'build': '1',
      'developer': 'Roulez Team',
      'website': 'https://roulez.app',
      'support': 'support@roulez.app'
    };
  }

  @override
  void dispose() {
    _settingsChannel?.unsubscribe();
    super.dispose();
  }
}
