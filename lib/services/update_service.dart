import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'auth_service.dart';

class UpdateService {
  static const String _baseUrl =
      'https://pokefinanzas-default-rtdb.europe-west1.firebasedatabase.app';
  static const String _versionPath = 'app_config/current_version';

  static String? remoteVersion;

  static Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  static Future<String?> getRemoteVersion() async {
    try {
      final token = AuthService.idToken;
      final url = Uri.parse('$_baseUrl/$_versionPath.json?auth=$token');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = response.body;
        if (data != 'null') {
          final parsed = jsonDecode(data) as Map<String, dynamic>;
          final version = parsed['version'] as String?;
          remoteVersion = version;
          return version;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isNewVersionAvailable() async {
    final current = await getCurrentVersion();
    final remote = await getRemoteVersion();
    if (remote == null) return false;
    return _compareVersions(remote, current) > 0;
  }

  static Future<void> updateRemoteVersion() async {
    final current = await getCurrentVersion();
    final token = AuthService.idToken;
    final url = Uri.parse('$_baseUrl/$_versionPath.json?auth=$token');
    await http.put(
      url,
      body: jsonEncode({
        'version': current,
        'updated_at': DateTime.now().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 10));
  }

  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      final a = i < parts1.length ? parts1[i] : 0;
      final b = i < parts2.length ? parts2[i] : 0;
      if (a != b) return a - b;
    }
    return 0;
  }
}
