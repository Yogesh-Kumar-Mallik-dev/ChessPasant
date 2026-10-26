import 'dart:async';
import 'package:flutter/material.dart';
import '../chess/models.dart';
import '../chess/engine.dart';
import '../audio/sounds.dart';
import '../widgets/chess_board.dart';
import '../websocket/game_socket.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String token;
  final String currentUserId;

  const GameScreen({
    super.key,
    required this.gameId,
    required this.token,
    required this.currentUserId,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameSocketClient? _socket;
  String _fen = initialFen;
  PieceColor _turn = PieceColor.white;
  PieceColor _playerColor = PieceColor.white;
  LastMoveInfo? _lastMove;
  bool _isConnected = false;

  Map<String, dynamic>? _whitePlayer;
  Map<String, dynamic>? _blackPlayer;
  int _whiteTimeMs = 300000;
  int _blackTimeMs = 300000;
  Timer? _clockTimer;

  bool _isGameOver = false;
  String _gameOverTitle = '';
  String _gameOverSubtitle = '';

  @override
  void initState() {
    super.initState();
    _connectSocket();
    _startClockTimer();
  }

  void _connectSocket() {
    _socket = GameSocketClient(
      gameId: widget.gameId,
      token: widget.token,
      onConnected: () => setState(() => _isConnected = true),
      onDisconnected: () => setState(() => _isConnected = false),
      onError: (_) => setState(() => _isConnected = false),
      onMessage: _handleServerMessage,
    );
    _socket!.connect();
  }

  void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isGameOver || !_isConnected) return;
      setState(() {
        if (_turn == PieceColor.white) {
          _whiteTimeMs = (_whiteTimeMs - 100).clamp(0, 3600000);
        } else {
          _blackTimeMs = (_blackTimeMs - 100).clamp(0, 3600000);
        }
      });
    });
  }

  void _handleServerMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;

    if (type == 'state' || type == 'init') {
      final fen = msg['fen'] as String? ?? initialFen;
      final turnStr = msg['turn'] as String? ?? 'w';
      final turn = turnStr == 'w' || turnStr == 'white' ? PieceColor.white : PieceColor.black;

      final white = msg['white'] as Map<String, dynamic>?;
      final black = msg['black'] as Map<String, dynamic>?;

      // Identify player's assigned color
      PieceColor myColor = PieceColor.white;
      if (black != null && black['id'] == widget.currentUserId) {
        myColor = PieceColor.black;
      }

      setState(() {
        _fen = fen;
        _turn = turn;
        _playerColor = myColor;
        _whitePlayer = white;
        _blackPlayer = black;
        if (msg['whiteTime'] != null) _whiteTimeMs = (msg['whiteTime'] as num).toInt();
        if (msg['blackTime'] != null) _blackTimeMs = (msg['blackTime'] as num).toInt();
      });
    } else if (type == 'move') {
      final fen = msg['fen'] as String?;
      final san = msg['san'] as String? ?? '';
      final moveObj = msg['move'] as Map<String, dynamic>?;
      final turnStr = msg['turn'] as String? ?? 'w';
      final turn = turnStr == 'w' || turnStr == 'white' ? PieceColor.white : PieceColor.black;
      final isCap = san.contains('x');
      final isCheck = msg['isCheck'] == true;

      SoundEffects().playMoveSound(san: san, isCapture: isCap, isCheck: isCheck);

      setState(() {
        if (fen != null) _fen = fen;
        _turn = turn;
        if (moveObj != null) {
          _lastMove = LastMoveInfo(
            from: moveObj['from'] ?? '',
            to: moveObj['to'] ?? '',
            san: san,
            isCapture: isCap,
          );
        }
        if (msg['whiteTime'] != null) _whiteTimeMs = (msg['whiteTime'] as num).toInt();
        if (msg['blackTime'] != null) _blackTimeMs = (msg['blackTime'] as num).toInt();
      });
    } else if (type == 'game_over') {
      SoundEffects().playGameEnd();
      final title = msg['winner'] != null ? '${msg['winner']} Won!' : 'Game Drawn';
      final subtitle = msg['outcome'] ?? msg['result'] ?? 'Match Finished';
      setState(() {
        _isGameOver = true;
        _gameOverTitle = title;
        _gameOverSubtitle = subtitle;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E2024),
          title: Text(_gameOverTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(_gameOverSubtitle, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(color: Colors.greenAccent)),
            ),
          ],
        ),
      );
    }
  }

  void _onPlayerMove(String from, String to, String? promo) {
    if (_isGameOver || _turn != _playerColor) return;

    // Optimistic client execution
    final localRes = ChessEngine.executeMove(_fen, from, to, promotion: promo);
    if (localRes != null && localRes['valid'] == true) {
      final san = localRes['san'] as String;
      final isCap = localRes['isCapture'] as bool;
      final isCheck = localRes['isCheck'] as bool;

      SoundEffects().playMoveSound(san: san, isCapture: isCap, isCheck: isCheck);

      setState(() {
        _fen = localRes['newFen'];
        _turn = localRes['turn'];
        _lastMove = LastMoveInfo(from: from, to: to, san: san, isCapture: isCap);
      });

      _socket?.sendMove(from, to, promotion: promo);
    } else {
      SoundEffects().playIllegal();
    }
  }

  String _formatTime(int ms) {
    final totalSec = (ms / 1000).ceil();
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _socket?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWhiteOriented = _playerColor == PieceColor.white;
    final topPlayer = isWhiteOriented ? _blackPlayer : _whitePlayer;
    final bottomPlayer = isWhiteOriented ? _whitePlayer : _blackPlayer;
    final topTime = isWhiteOriented ? _blackTimeMs : _whiteTimeMs;
    final bottomTime = isWhiteOriented ? _whiteTimeMs : _blackTimeMs;
    final topColor = isWhiteOriented ? PieceColor.black : PieceColor.white;
    final bottomColor = isWhiteOriented ? PieceColor.white : PieceColor.black;

    return Scaffold(
      backgroundColor: const Color(0xFF141518),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2024),
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _isConnected ? 'Live Duel' : 'Connecting...',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag, color: Colors.white70),
            tooltip: 'Resign',
            onPressed: () {
              _socket?.resign();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Opponent Bar
            _playerBar(
              name: topPlayer?['username'] ?? 'Opponent',
              rating: topPlayer?['rating']?.toString() ?? '1500',
              timeStr: _formatTime(topTime),
              isActiveTurn: _turn == topColor && !_isGameOver,
            ),

            // Interactive Chessboard
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ChessBoardWidget(
                    fen: _fen,
                    orientation: _playerColor,
                    turn: _turn,
                    playerColor: _playerColor,
                    lastMove: _lastMove,
                    interactive: !_isGameOver && _turn == _playerColor,
                    onMove: _onPlayerMove,
                  ),
                ),
              ),
            ),

            // Bottom Player Bar
            _playerBar(
              name: bottomPlayer?['username'] ?? 'You',
              rating: bottomPlayer?['rating']?.toString() ?? '1500',
              timeStr: _formatTime(bottomTime),
              isActiveTurn: _turn == bottomColor && !_isGameOver,
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerBar({
    required String name,
    required String rating,
    required String timeStr,
    required bool isActiveTurn,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2024),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActiveTurn ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF2A2D35),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text('$rating ELO', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActiveTurn ? Colors.greenAccent.withValues(alpha: 0.15) : const Color(0xFF2A2D35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActiveTurn ? Colors.greenAccent : Colors.white12,
              ),
            ),
            child: Text(
              timeStr,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isActiveTurn ? Colors.greenAccent : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
