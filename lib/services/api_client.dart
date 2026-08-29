import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Default matches the Android emulator's host loopback (10.0.2.2).
/// Override at build/run time for other targets, e.g. a physical device
/// reached via `adb reverse tcp:3000 tcp:3000`:
///   flutter run --dart-define=API_BASE_URL=http://localhost:3000
const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  /// Server origin, for resolving media paths (audio_path, option_image_paths)
  /// returned by the API as root-relative URLs (e.g. "/public/audio/5.flac").
  static String get baseUrl => _baseUrl;

  /// Same origin as [baseUrl], just as a ws(s):// URL — for MatchSocketService.
  static String get wsBaseUrl => _baseUrl.replaceFirst(RegExp(r'^http'), 'ws');

  static const _tokenKey = 'auth_token';
  String? _cachedToken;

  Future<String?> get token async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  Future<void> setToken(String? token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(Uri.parse('$_baseUrl$path'), headers: await _headers());
    return _decode(res);
  }

  Future<List<dynamic>> getList(String path) async {
    final res = await http.get(Uri.parse('$_baseUrl$path'), headers: await _headers());
    return _decodeList(res);
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final res = await http.delete(Uri.parse('$_baseUrl$path'), headers: await _headers());
    return _decode(res);
  }

  Future<Map<String, String>> _headers() async {
    final t = await token;
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  Map<String, dynamic> _decode(http.Response res) {
    final body = res.body.isEmpty ? {} : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw ApiException(
      (body is Map && body['error'] is String) ? body['error'] as String : 'Request failed (${res.statusCode})',
      statusCode: res.statusCode,
    );
  }

  List<dynamic> _decodeList(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw ApiException('Request failed (${res.statusCode})', statusCode: res.statusCode);
  }
}
