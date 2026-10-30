import 'dart:async';
import 'package:flutter/material.dart';
import '../chess/models.dart';
import '../chess/engine.dart';
import '../audio/sounds.dart';
import '../widgets/chess_board.dart';
import '../widgets/app_icon.dart';
import '../theme/app_theme.dart';
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
      final turn =
          turnStr == 'w' || turnStr == 'white' ? PieceColor.white : PieceColor.black;

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
        if (msg['whiteTime'] != null) {
          _whiteTimeMs = (msg['whiteTime'] as num).toInt();
        }
        if (msg['blackTime'] != null) {
          _blackTimeMs = (msg['blackTime'] as num).toInt();
        }
      });
    } else if (type == 'move') {
      final from = msg['from'] as String;
      final to = msg['to'] as String;
      final promo = msg['promotion'] as String?;
      final fen = msg['fen'] as String;
      final turnStr = msg['turn'] as String;
      final turn =
          turnStr == 'w' || turnStr == 'white' ? PieceColor.white : PieceColor.black;
      final san = msg['san'] as String? ?? '';
      final isCap = msg['isCapture'] as bool? ?? false;
      final isCheck = msg['isCheck'] as bool? ?? false;

      SoundEffects().playMoveSound(san: san, isCapture: isCap, isCheck: isCheck);

      setState(() {
        _fen = fen;
        _turn = turn;
        _lastMove =
            LastMoveInfo(from: from, to: to, san: san, isCapture: isCap, isPromotion: promo != null);
        if (msg['whiteTime'] != null) {
          _whiteTimeMs = (msg['whiteTime'] as num).toInt();
        }
        if (msg['blackTime'] != null) {
          _blackTimeMs = (msg['blackTime'] as num).toInt();
        }
      });
    } else if (type == 'game_over') {
      SoundEffects().playGameEnd();
      final winner = msg['winner'] as String?;
      final reason = msg['reason'] as String? ?? 'Match concluded';
      final title = winner == null
          ? 'Drawn Game'
          : (winner == (_playerColor == PieceColor.white ? 'white' : 'black')
              ? 'Victory!'
              : 'Defeat');

      setState(() {
        _isGameOver = true;
      });
      _clockTimer?.cancel();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border, width: 1.2),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          content: Text(
            reason,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Back to Hub', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _onPlayerMove(String from, String to, String? promo) {
    if (_isGameOver || _turn != _playerColor) return;
    _socket?.sendMove(from, to, promotion: promo);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _socket?.disconnect();
    super.dispose();
  }

  String _formatTime(int ms) {
    final totalSec = (ms / 1000).ceil();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        shape: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? AppColors.green : AppColors.red,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _isConnected ? 'Live Duel' : 'Connecting...',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const AppIcon(name: 'flag', size: 18, color: AppColors.textMuted),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActiveTurn ? AppColors.amber.withValues(alpha: 0.6) : AppColors.border,
          width: isActiveTurn ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfacePanel,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$rating ELO',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isActiveTurn
                  ? AppColors.amber.withValues(alpha: 0.15)
                  : AppColors.surfacePanel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActiveTurn ? AppColors.amber : AppColors.border,
              ),
            ),
            child: Text(
              timeStr,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isActiveTurn ? AppColors.amber : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
