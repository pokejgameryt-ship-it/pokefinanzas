import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'cache_service.dart';

CacheServiceInterface createCacheService() => _LocalStorageCacheService();

class _LocalStorageCacheService implements CacheServiceInterface {
  @override
  Future<void> saveData(String key, dynamic value) async {
    final json = jsonEncode(value);
    html.window.localStorage['cache_$key'] = json;
  }

  @override
  Future<dynamic> getData(String key) async {
    final json = html.window.localStorage['cache_$key'];
    if (json == null) return null;
    try {
      return jsonDecode(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearData() async {
    final keysToRemove = <String>[];
    html.window.localStorage.forEach((key, value) {
      if (key.startsWith('cache_')) {
        keysToRemove.add(key);
      }
    });
    for (final k in keysToRemove) {
      html.window.localStorage.remove(k);
    }
  }
}
