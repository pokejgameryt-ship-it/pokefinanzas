import 'cache_service_native.dart'
    if (dart.library.js_interop) 'cache_service_web.dart';

abstract class CacheServiceInterface {
  Future<void> saveData(String key, dynamic value);
  Future<dynamic> getData(String key);
  Future<void> clearData();
}

class CacheService {
  static final CacheServiceInterface _impl = createCacheService();

  static Future<void> saveData(String key, dynamic value) =>
      _impl.saveData(key, value);

  static Future<dynamic> getData(String key) => _impl.getData(key);

  static Future<void> clearData() => _impl.clearData();
}
