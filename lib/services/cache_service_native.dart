import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_service.dart';

CacheServiceInterface createCacheService() => _SharedPrefsCacheService();

class _SharedPrefsCacheService implements CacheServiceInterface {
  @override
  Future<void> saveData(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(value);
    await prefs.setString('cache_$key', json);
  }

  @override
  Future<dynamic> getData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('cache_$key');
    if (json == null) return null;
    try {
      return jsonDecode(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_'));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
