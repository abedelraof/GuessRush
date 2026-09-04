import '../models/player.dart';
import 'api_client.dart';

class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<Player> signup({required String email, required String password, required String displayName}) async {
    final res = await _api.post('/api/auth/signup', {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    await _api.setToken(res['token'] as String);
    return Player.fromJson(res['player'] as Map<String, dynamic>);
  }

  Future<Player> login({required String email, required String password}) async {
    final res = await _api.post('/api/auth/login', {'email': email, 'password': password});
    await _api.setToken(res['token'] as String);
    return Player.fromJson(res['player'] as Map<String, dynamic>);
  }

  /// Auto-provisions an anonymous account so the app can open straight to the
  /// home screen and play solo without ever showing a login form.
  Future<Player> guest() async {
    final res = await _api.post('/api/auth/guest');
    await _api.setToken(res['token'] as String);
    return Player.fromJson(res['player'] as Map<String, dynamic>);
  }

  /// Converts the current guest session into a real account in place, so
  /// whatever was played as a guest (XP, level, stats) carries over.
  Future<Player> upgrade({required String email, required String password, required String displayName}) async {
    final res = await _api.post('/api/auth/upgrade', {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    await _api.setToken(res['token'] as String);
    return Player.fromJson(res['player'] as Map<String, dynamic>);
  }

  Future<Player?> fetchStoredSession() async {
    final token = await _api.token;
    if (token == null) return null;
    try {
      final res = await _api.get('/api/auth/me');
      return Player.fromJson(res);
    } on ApiException {
      await _api.setToken(null);
      return null;
    }
  }

  Future<void> logout() => _api.setToken(null);
}
