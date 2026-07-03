import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  final String uid;
  final String email;
  final String? displayName;

  AuthUser({required this.uid, required this.email, this.displayName});
}

class AuthService {
  static const String _apiKey = 'AIzaSyB4zR2gH97nx2p34tqNorqKMKwL4OAS9-g';
  static const String _authUrl =
      'https://identitytoolkit.googleapis.com/v1/accounts';
  static const Duration _timeout = Duration(seconds: 15);

  static AuthUser? _currentUser;
  static String? _idToken;

  static AuthUser? get currentUser => _currentUser;
  static String? get idToken => _idToken;
  static bool get isLoggedIn => _currentUser != null;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final uid = prefs.getString('auth_uid');
    final email = prefs.getString('auth_email');
    final displayName = prefs.getString('auth_displayName');

    if (token != null && uid != null && email != null) {
      _idToken = token;
      _currentUser = AuthUser(uid: uid, email: email, displayName: displayName);

      // Verify token is still valid
      final valid = await _verifyToken(token);
      if (!valid) {
        // Try refresh
        final refreshToken = prefs.getString('auth_refreshToken');
        if (refreshToken != null) {
          final refreshed = await _refreshToken(refreshToken);
          if (!refreshed) {
            await logout();
          }
        } else {
          await logout();
        }
      }
    }
  }

  static Future<bool> _verifyToken(String token) async {
    try {
      final url = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=$_apiKey');
      final response = await http
          .post(url, body: jsonEncode({'idToken': token}))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _refreshToken(String refreshToken) async {
    try {
      final url = Uri.parse(
          'https://securetoken.googleapis.com/v1/token?key=$_apiKey');
      final response = await http
          .post(url, body: jsonEncode({
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          }))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _idToken = data['id_token'];
        final uid = data['user_id'];
        final email = _currentUser?.email ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _idToken!);
        await prefs.setString('auth_refreshToken', data['refresh_token']);
        await prefs.setString('auth_uid', uid);
        await prefs.setString('auth_email', email);

        _currentUser = AuthUser(uid: uid, email: email);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<AuthResult> register(String email, String password) async {
    try {
      final url = Uri.parse('$_authUrl:signUp?key=$_apiKey');
      final response = await http
          .post(url,
              body: jsonEncode({
                'email': email,
                'password': password,
                'returnSecureToken': true,
              }))
          .timeout(_timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _idToken = data['idToken'];
        _currentUser = AuthUser(
          uid: data['localId'],
          email: data['email'],
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _idToken!);
        await prefs.setString('auth_refreshToken', data['refreshToken']);
        await prefs.setString('auth_uid', data['localId']);
        await prefs.setString('auth_email', data['email']);
        if (data['displayName'] != null) {
          await prefs.setString('auth_displayName', data['displayName']);
        }

        return AuthResult.success(_currentUser!);
      } else {
        final errorMsg = _parseError(data);
        return AuthResult.error(errorMsg);
      }
    } catch (e) {
      return AuthResult.error('Error de conexión: $e');
    }
  }

  static Future<AuthResult> login(String email, String password) async {
    try {
      final url = Uri.parse('$_authUrl:signInWithPassword?key=$_apiKey');
      final response = await http
          .post(url,
              body: jsonEncode({
                'email': email,
                'password': password,
                'returnSecureToken': true,
              }))
          .timeout(_timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _idToken = data['idToken'];
        _currentUser = AuthUser(
          uid: data['localId'],
          email: data['email'],
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _idToken!);
        await prefs.setString('auth_refreshToken', data['refreshToken']);
        await prefs.setString('auth_uid', data['localId']);
        await prefs.setString('auth_email', data['email']);
        if (data['displayName'] != null) {
          await prefs.setString('auth_displayName', data['displayName']);
        }

        return AuthResult.success(_currentUser!);
      } else {
        final errorMsg = _parseError(data);
        return AuthResult.error(errorMsg);
      }
    } catch (e) {
      return AuthResult.error('Error de conexión: $e');
    }
  }

  static Future<void> logout() async {
    _currentUser = null;
    _idToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_refreshToken');
    await prefs.remove('auth_uid');
    await prefs.remove('auth_email');
    await prefs.remove('auth_displayName');
  }

  static Future<void> deleteAccount() async {
    if (_idToken == null) return;
    try {
      final url = Uri.parse('$_authUrl:delete?key=$_apiKey');
      await http
          .post(url, body: jsonEncode({'idToken': _idToken}))
          .timeout(_timeout);
    } catch (_) {}
    await logout();
  }

  static String _parseError(Map<String, dynamic> data) {
    final message = data['error']?['message'] ?? 'Error desconocido';
    switch (message) {
      case 'EMAIL_EXISTS':
        return 'Este email ya está registrado';
      case 'EMAIL_NOT_FOUND':
        return 'No existe cuenta con este email';
      case 'INVALID_PASSWORD':
        return 'Contraseña incorrecta';
      case 'WEAK_PASSWORD':
        return 'La contraseña debe tener al menos 6 caracteres';
      case 'INVALID_EMAIL':
        return 'Email no válido';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Demasiados intentos. Inténtalo más tarde';
      case 'USER_DISABLED':
        return 'Esta cuenta está deshabilitada';
      default:
        return 'Error: $message';
    }
  }
}

class AuthResult {
  final bool isSuccess;
  final AuthUser? user;
  final String? errorMessage;

  AuthResult.success(this.user)
      : isSuccess = true,
        errorMessage = null;

  AuthResult.error(this.errorMessage)
      : isSuccess = false,
        user = null;
}
