import 'dart:async';
import 'package:flutter/material.dart';
import '../chess/models.dart';
import '../chess/engine.dart';
import '../chess/game_archive.dart';
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
  String _liveFen = initialFen;
  PieceColor _turn = PieceColor.white;
  PieceColor _playerColor = PieceColor.white;
  LastMoveInfo? _liveLastMove;
  bool _isConnected = false;

  // Full move history: [ {ply: 0, fen: ..., lastMove: ..., san: 'Start'} ]
  final List<Map<String, dynamic>> _boardHistory = [
    {
      'ply': 0,
      'fen': initialFen,
      'lastMove': null,
      'turn': PieceColor.white,
      'san': 'Start',
    }
  ];

  // -1 means active live match position
  int _viewingPly = -1;

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
        _liveFen = fen;
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

      final moveRecord = LastMoveInfo(
        from: from,
        to: to,
        san: san,
        isCapture: isCap,
        isPromotion: promo != null,
      );

      setState(() {
        _liveFen = fen;
        _turn = turn;
        _liveLastMove = moveRecord;

        // Whenever anyone plays a move, snap immediately back to live mode!
        _viewingPly = -1;

        _boardHistory.add({
          'ply': _boardHistory.length,
          'from': from,
          'to': to,
          'fen': fen,
          'lastMove': moveRecord,
          'turn': turn,
          'san': san,
        });

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

      final movesList = _boardHistory.skip(1).map((h) => {
        'from': h['from'],
        'to': h['to'],
        'san': h['san'],
        'fen': h['fen'],
      }).toList();

      final record = SavedGameRecord(
        title: 'Online Duel',
        mode: 'Online Match',
        date: DateTime.now().toLocal().toString().split('.')[0],
        whitePlayer: _whitePlayer?['username'] ?? 'White',
        blackPlayer: _blackPlayer?['username'] ?? 'Black',
        result: winner == 'white' ? '1-0' : (winner == 'black' ? '0-1' : '1/2-1/2'),
        finalFen: _liveFen,
        moves: movesList,
        gameId: widget.gameId,
      );

      GameArchive.saveGame(record);

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
              fontSize: 18,
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
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Back to Hub', style: TextStyle(color: AppColors.textMuted)),
            ),
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
                // Pop back to HomeScreen returning true so it immediately switches to Analysis
                Navigator.of(context).pop(true);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(name: 'search', size: 14, color: AppColors.background),
                  SizedBox(width: 6),
                  Text('Analyze Game', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  void _onPlayerMove(String from, String to, String? promo) {
    if (_isGameOver || _turn != _playerColor) return;
    // Snap to live mode on player action
    setState(() => _viewingPly = -1);
    _socket?.sendMove(from, to, promotion: promo);
  }

  void _goToFirst() {
    setState(() => _viewingPly = 0);
  }

  void _goToPrevious() {
    final cur = _viewingPly == -1 ? _boardHistory.length - 1 : _viewingPly;
    setState(() => _viewingPly = (cur - 1).clamp(0, _boardHistory.length - 1));
  }

  void _goToNext() {
    if (_viewingPly == -1) return;
    if (_viewingPly + 1 >= _boardHistory.length - 1) {
      setState(() => _viewingPly = -1);
    } else {
      setState(() => _viewingPly++);
    }
  }

  void _goToLive() {
    setState(() => _viewingPly = -1);
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

    final isLiveView = _viewingPly == -1 || _viewingPly == _boardHistory.length - 1;
    final currentEntry = !isLiveView && _viewingPly >= 0 && _viewingPly < _boardHistory.length
        ? _boardHistory[_viewingPly]
        : null;

    final displayFen = currentEntry != null ? currentEntry['fen'] as String : _liveFen;
    final displayLastMove = currentEntry != null ? currentEntry['lastMove'] as LastMoveInfo? : _liveLastMove;
    final displayTurn = currentEntry != null ? currentEntry['turn'] as PieceColor : _turn;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
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

            // Interactive Chessboard (natural board)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ChessBoardWidget(
                    fen: displayFen,
                    orientation: _playerColor,
                    turn: displayTurn,
                    playerColor: _playerColor,
                    lastMove: displayLastMove,
                    interactive: isLiveView && !_isGameOver && _turn == _playerColor,
                    onMove: _onPlayerMove,
                  ),
                ),
              ),
            ),

            // Move History & Live Snapper Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Navigation Buttons
                    Row(
                      children: [
                        IconButton(
                          icon: const AppIcon(name: 'chevrons-left', size: 16, color: AppColors.textPrimary),
                          onPressed: _boardHistory.length <= 1 || _viewingPly == 0 ? null : _goToFirst,
                          tooltip: 'Start of Game',
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(32, 32),
                          ),
                        ),
                        IconButton(
                          icon: const AppIcon(name: 'chevron-left', size: 16, color: AppColors.textPrimary),
                          onPressed: _boardHistory.length <= 1 || _viewingPly == 0 ? null : _goToPrevious,
                          tooltip: 'Previous Move',
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(32, 32),
                          ),
                        ),
                        IconButton(
                          icon: const AppIcon(name: 'chevron-right', size: 16, color: AppColors.textPrimary),
                          onPressed: _boardHistory.length <= 1 || isLiveView ? null : _goToNext,
                          tooltip: 'Next Move',
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(32, 32),
                          ),
                        ),
                        IconButton(
                          icon: const AppIcon(name: 'chevrons-right', size: 16, color: AppColors.textPrimary),
                          onPressed: _boardHistory.length <= 1 || isLiveView ? null : _goToLive,
                          tooltip: 'Jump to Live',
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(32, 32),
                          ),
                        ),
                      ],
                    ),

                    // Status Indicator
                    if (isLiveView)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '● LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.green,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _goToLive,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfacePanel,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ply $_viewingPly / ${_boardHistory.length - 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '• Tap for Live',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActiveTurn ? AppColors.textPrimary.withValues(alpha: 0.8) : AppColors.border,
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
                  ? Colors.white.withValues(alpha: 0.12)
                  : AppColors.surfacePanel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActiveTurn ? AppColors.textPrimary : AppColors.border,
              ),
            ),
            child: Text(
              timeStr,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isActiveTurn ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

