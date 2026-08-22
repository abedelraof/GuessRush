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
