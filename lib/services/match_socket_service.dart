import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/match.dart';
import 'api_client.dart';

/// Owns the live WebSocket connection used for Play With Friends presence
/// events (match:paired, match:opponent_progress, match:result, ...). REST
/// stays the source of truth for every discrete action (join queue,
/// create/join a friend match) — this is purely a push channel; losing it
/// just means falling back to polling GET /api/matches/:id (see QuizApi).
class MatchSocketService {
  MatchSocketService._();

  static final MatchSocketService instance = MatchSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _controller = StreamController<MatchEvent>.broadcast();
  Timer? _reconnectTimer;
  bool _shouldReconnect = false;
  int _reconnectAttempt = 0;

  Stream<MatchEvent> get events => _controller.stream;

  /// Opens the connection, and keeps retrying (with backoff) until
  /// [disconnect] is called — e.g. across a brief network hiccup while
  /// queued or mid-match.
  Future<void> connect() async {
    _shouldReconnect = true;
    await _connectOnce();
  }

  Future<void> _connectOnce() async {
    final token = await ApiClient.instance.token;
    if (token == null) return;
    await _subscription?.cancel();
    await _channel?.sink.close();

    final uri = Uri.parse('${ApiClient.wsBaseUrl}/ws?token=$token');
    final channel = WebSocketChannel.connect(uri);
    try {
      await channel.ready;
    } catch (_) {
      // e.g. the server closed the handshake for an invalid/expired token.
      _scheduleReconnect();
      return;
    }

    _channel = channel;
    _reconnectAttempt = 0;
    _subscription = channel.stream.listen(
      (raw) {
        try {
          final json = jsonDecode(raw as String) as Map<String, dynamic>;
          _controller.add(MatchEvent.fromJson(json));
        } catch (_) {
          // Ignore a malformed frame rather than taking down the whole stream.
        }
      },
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
    );
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(1, 5);
    _reconnectTimer = Timer(Duration(seconds: _reconnectAttempt * 2), _connectOnce);
  }

  /// Stops reconnecting and closes the connection — call when leaving the
  /// Play With Friends flow entirely (queue cancelled, match finished, or
  /// backed out to Home).
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
