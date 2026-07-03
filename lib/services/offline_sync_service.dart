import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._init();
  OfflineSyncService._init();

  static const String _pendingKey = 'offline_pending_syncs';
  bool _syncing = false;
  Timer? _periodicTimer;
  final StreamController<int> _pendingCountController = StreamController<int>.broadcast();

  Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Queue a write operation for later sync
  Future<void> queueSync({
    required String entityType,
    required String entityId,
    required String operation,
    Map<String, dynamic>? data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingKey) ?? [];

    pending.add(jsonEncode({
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    }));

    await prefs.setStringList(_pendingKey, pending);
    _pendingCountController.add(pending.length);
  }

  /// Get count of pending syncs
  Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_pendingKey) ?? []).length;
  }

  /// Sync all pending operations to Firebase
  Future<int> syncPending() async {
    if (_syncing) return 0;
    if (AuthService.currentUser == null) return 0;

    _syncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_pendingKey) ?? [];
      if (pending.isEmpty) {
        _syncing = false;
        return 0;
      }

      int synced = 0;
      final remaining = <String>[];

      for (final entry in pending) {
        try {
          final data = jsonDecode(entry) as Map<String, dynamic>;
          final entityType = data['entityType'] as String;
          final entityId = data['entityId'] as String;
          final operation = data['operation'] as String;
          final entityData = data['data'] as Map<String, dynamic>?;

          final success = await _executeFirebase(entityType, entityId, operation, entityData);
          if (success) {
            synced++;
          } else {
            remaining.add(entry);
          }
        } catch (_) {
          remaining.add(entry);
        }
      }

      await prefs.setStringList(_pendingKey, remaining);
      _pendingCountController.add(remaining.length);
      _syncing = false;
      return synced;
    } catch (_) {
      _syncing = false;
      return 0;
    }
  }

  /// Start periodic sync every [interval]
  void startAutoSync({Duration interval = const Duration(minutes: 3)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) async {
      if (AuthService.currentUser != null) {
        final count = await getPendingCount();
        if (count > 0) await syncPending();
      }
    });
  }

  /// Stop periodic sync
  void stopAutoSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Clear pending queue
  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
    _pendingCountController.add(0);
  }

  Future<bool> _executeFirebase(
    String entityType,
    String entityId,
    String operation,
    Map<String, dynamic>? data,
  ) async {
    final userId = AuthService.currentUser?.uid;
    final token = AuthService.idToken;
    if (userId == null || token == null) return false;

    const baseUrl = 'https://pokefinanzas-default-rtdb.europe-west1.firebasedatabase.app';
    final path = 'users/$userId/$entityType/$entityId';

    try {
      if (operation == 'save' && data != null) {
        final url = Uri.parse('$baseUrl/$path.json?auth=$token');
        final response = await http.put(url, body: jsonEncode(data)).timeout(
          const Duration(seconds: 10),
        );
        return response.statusCode == 200;
      } else if (operation == 'delete') {
        final url = Uri.parse('$baseUrl/$path.json?auth=$token');
        final response = await http.delete(url).timeout(
          const Duration(seconds: 10),
        );
        return response.statusCode == 200;
      }
    } catch (_) {}
    return false;
  }
}
