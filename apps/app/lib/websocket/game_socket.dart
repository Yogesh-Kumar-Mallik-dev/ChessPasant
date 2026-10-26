import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class GameSocketClient {
  final String gameId;
  final String token;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;

  final Function(Map<String, dynamic> data) onMessage;
  final Function() onConnected;
  final Function(dynamic error) onError;
  final Function() onDisconnected;

  GameSocketClient({
    required this.gameId,
    required this.token,
    required this.onMessage,
    required this.onConnected,
    required this.onError,
    required this.onDisconnected,
  });

  void connect({String host = 'chess.yogeshmallik.in'}) {
    final uri = Uri.parse('wss://$host/ws?gameId=$gameId&token=$token');
    try {
      _channel = WebSocketChannel.connect(uri);
      onConnected();

      _sub = _channel!.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            onMessage(parsed);
          } catch (_) {}
        },
        onError: (err) {
          onError(err);
        },
        onDone: () {
          onDisconnected();
        },
      );

      // Keepalive ping every 15s
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        sendPing();
      });
    } catch (e) {
      onError(e);
    }
  }

  void sendMove(String from, String to, {String? promotion}) {
    _send({
      'type': 'move',
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    });
  }

  void resign() => _send({'type': 'resign'});
  void offerDraw() => _send({'type': 'offer_draw'});
  void acceptDraw() => _send({'type': 'accept_draw'});
  void declineDraw() => _send({'type': 'decline_draw'});
  void sendPing() => _send({'type': 'ping'});

  void _send(Map<String, dynamic> msg) {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode(msg));
      } catch (_) {}
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
