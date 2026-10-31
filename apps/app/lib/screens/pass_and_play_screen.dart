import 'dart:async';
import 'package:flutter/material.dart';
import '../chess/models.dart';
import '../chess/engine.dart';
import '../chess/game_archive.dart';
import '../audio/sounds.dart';
import '../widgets/chess_board.dart';
import '../widgets/app_icon.dart';
import '../theme/app_theme.dart';

class PassAndPlayScreen extends StatefulWidget {
  final int initialMinutes; // 0 for untimed
  const PassAndPlayScreen({super.key, this.initialMinutes = 0});

  @override
  State<PassAndPlayScreen> createState() => _PassAndPlayScreenState();
}

class _PassAndPlayScreenState extends State<PassAndPlayScreen> {
  String _liveFen = initialFen;
  PieceColor _liveTurn = PieceColor.white;
  PieceColor _boardOrientation = PieceColor.white;
  LastMoveInfo? _liveLastMove;

  // Move history records: [ {ply: 0, fen: ..., lastMove: ..., san: 'Start'} ]
  final List<Map<String, dynamic>> _boardHistory = [
    {
      'ply': 0,
      'fen': initialFen,
      'lastMove': null,
      'turn': PieceColor.white,
      'san': 'Start',
    }
  ];

  // -1 means viewing active live match
  int _viewingPly = -1;

  // Timers (in ms)
  late int _whiteTimeMs;
  late int _blackTimeMs;
  Timer? _clockTicker;
  bool _isGameOver = false;
  String _gameOverReason = '';
  String _gameOverWinner = '';

  @override
  void initState() {
    super.initState();
    _whiteTimeMs = widget.initialMinutes > 0 ? widget.initialMinutes * 60 * 1000 : 0;
    _blackTimeMs = widget.initialMinutes > 0 ? widget.initialMinutes * 60 * 1000 : 0;

    SoundEffects().playGameStart();
    if (widget.initialMinutes > 0) {
      _startClock();
    }
  }

  void _startClock() {
    _clockTicker?.cancel();
    _clockTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isGameOver) return;
      setState(() {
        if (_liveTurn == PieceColor.white) {
          _whiteTimeMs = (_whiteTimeMs - 100).clamp(0, 36000000);
          if (_whiteTimeMs == 0) {
            _onMatchFinished(winner: 'black', reason: 'Black wins on time');
          }
        } else {
          _blackTimeMs = (_blackTimeMs - 100).clamp(0, 36000000);
          if (_blackTimeMs == 0) {
            _onMatchFinished(winner: 'white', reason: 'White wins on time');
          }
        }
      });
    });
  }

  void _onPlayerMove(String from, String to, String? promo) {
    if (_isGameOver) return;

    // Snaps immediately back to live mode whenever a player makes a move
    if (_viewingPly != -1) {
      _viewingPly = -1;
    }

    final res = ChessEngine.executeMove(_liveFen, from, to, promotion: promo);
    if (res == null || res['valid'] != true) {
      SoundEffects().playIllegal();
      return;
    }

    final san = res['san'] as String;
    final isCap = res['isCapture'] as bool;
    final isCheck = res['isCheck'] as bool;
    final isCheckmate = res['isCheckmate'] as bool;
    final isDraw = res['isDraw'] as bool;
    final nextFen = res['newFen'] as String;
    final nextTurn = res['turn'] as PieceColor;

    SoundEffects().playMoveSound(san: san, isCapture: isCap, isCheck: isCheck);

    final moveRecord = LastMoveInfo(
      from: from,
      to: to,
      san: san,
      isCapture: isCap,
      isPromotion: promo != null,
    );

    setState(() {
      _liveFen = nextFen;
      _liveTurn = nextTurn;
      _liveLastMove = moveRecord;
      _viewingPly = -1; // Keep strictly in live mode

      _boardHistory.add({
        'ply': _boardHistory.length,
        'from': from,
        'to': to,
        'fen': nextFen,
        'lastMove': moveRecord,
        'turn': nextTurn,
        'san': san,
      });
    });

    if (isCheckmate) {
      final winner = nextTurn == PieceColor.white ? 'black' : 'white';
      _onMatchFinished(winner: winner, reason: 'Checkmate! ${winner[0].toUpperCase()}${winner.substring(1)} wins.');
    } else if (isDraw) {
      _onMatchFinished(winner: 'draw', reason: 'Drawn by stalemate or repetition.');
    }
  }

  void _onMatchFinished({required String winner, required String reason}) {
    _clockTicker?.cancel();
    SoundEffects().playGameEnd();

    final movesList = _boardHistory.skip(1).map((h) => {
      'from': h['from'],
      'to': h['to'],
      'san': h['san'],
      'fen': h['fen'],
    }).toList();

    final resultStr = winner == 'white' ? '1-0' : (winner == 'black' ? '0-1' : '1/2-1/2');

    final record = SavedGameRecord(
      title: 'Pass & Play Game',
      mode: 'Pass & Play',
      date: DateTime.now().toLocal().toString().split('.')[0],
      whitePlayer: 'Player 1 (White)',
      blackPlayer: 'Player 2 (Black)',
      result: resultStr,
      finalFen: _liveFen,
      moves: movesList,
    );

    GameArchive.saveGame(record);

    setState(() {
      _isGameOver = true;
      _gameOverWinner = winner;
      _gameOverReason = reason;
    });

    _showGameOverDialog(record);
  }

  void _showGameOverDialog(SavedGameRecord record) {
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
          _gameOverWinner == 'draw'
              ? 'Drawn Game'
              : '${_gameOverWinner[0].toUpperCase()}${_gameOverWinner.substring(1)} Victory!',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          _gameOverReason,
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
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetGame();
            },
            child: const Text('Play Again'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              // Exit back to home and trigger analysis tab
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

  void _resetGame() {
    setState(() {
      _liveFen = initialFen;
      _liveTurn = PieceColor.white;
      _liveLastMove = null;
      _boardHistory.clear();
      _boardHistory.add({
        'ply': 0,
        'fen': initialFen,
        'lastMove': null,
        'turn': PieceColor.white,
        'san': 'Start',
      });
      _viewingPly = -1;
      _isGameOver = false;
      _whiteTimeMs = widget.initialMinutes > 0 ? widget.initialMinutes * 60 * 1000 : 0;
      _blackTimeMs = widget.initialMinutes > 0 ? widget.initialMinutes * 60 * 1000 : 0;
    });
    if (widget.initialMinutes > 0) {
      _startClock();
    }
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
      setState(() => _viewingPly = -1); // Jump to live
    } else {
      setState(() => _viewingPly++);
    }
  }

  void _goToLive() {
    setState(() => _viewingPly = -1);
  }

  String _formatTime(int ms) {
    if (widget.initialMinutes == 0) return '∞';
    final totalSec = (ms / 1000).ceil();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLiveView = _viewingPly == -1 || _viewingPly == _boardHistory.length - 1;
    final currentEntry = !isLiveView && _viewingPly >= 0 && _viewingPly < _boardHistory.length
        ? _boardHistory[_viewingPly]
        : null;

    final displayFen = currentEntry != null ? currentEntry['fen'] as String : _liveFen;
    final displayLastMove = currentEntry != null ? currentEntry['lastMove'] as LastMoveInfo? : _liveLastMove;
    final displayTurn = currentEntry != null ? currentEntry['turn'] as PieceColor : _liveTurn;

    final isWhiteOriented = _boardOrientation == PieceColor.white;
    final topColor = isWhiteOriented ? PieceColor.black : PieceColor.white;
    final bottomColor = isWhiteOriented ? PieceColor.white : PieceColor.black;

    final topName = topColor == PieceColor.white ? 'Player 1 (White)' : 'Player 2 (Black)';
    final bottomName = bottomColor == PieceColor.white ? 'Player 1 (White)' : 'Player 2 (Black)';

    final topTime = topColor == PieceColor.white ? _whiteTimeMs : _blackTimeMs;
    final bottomTime = bottomColor == PieceColor.white ? _whiteTimeMs : _blackTimeMs;

    final isTopTurn = _liveTurn == topColor && !_isGameOver;
    final isBottomTurn = _liveTurn == bottomColor && !_isGameOver;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        title: const Row(
          children: [
            AppIcon(name: 'handshake', size: 18, color: AppColors.textPrimary),
            SizedBox(width: 8),
            Text(
              'Pass & Play',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const AppIcon(name: 'rotate-cw', size: 16, color: AppColors.textMuted),
            tooltip: 'Flip Board',
            onPressed: () {
              setState(() {
                _boardOrientation = _boardOrientation == PieceColor.white ? PieceColor.black : PieceColor.white;
              });
            },
          ),
          IconButton(
            icon: const AppIcon(name: 'rotate-ccw', size: 16, color: AppColors.textMuted),
            tooltip: 'Reset Game',
            onPressed: _resetGame,
          ),
          IconButton(
            icon: const AppIcon(name: 'flag', size: 16, color: AppColors.red),
            tooltip: 'Resign Current Turn',
            onPressed: () {
              final winner = _liveTurn == PieceColor.white ? 'black' : 'white';
              _onMatchFinished(winner: winner, reason: '${_liveTurn.name.toUpperCase()} resigned the match.');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Player Bar (Black by default)
            _playerBar(
              name: topName,
              timeStr: _formatTime(topTime),
              isActiveTurn: isTopTurn,
              color: topColor,
            ),

            // Natural Board Display
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ChessBoardWidget(
                    fen: displayFen,
                    orientation: _boardOrientation,
                    turn: displayTurn,
                    playerColor: null, // Natural pass & play: both colors can move on their turn
                    lastMove: displayLastMove,
                    interactive: isLiveView && !_isGameOver,
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

                    // Live vs Historical indicator
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
                                '• Jump to Live',
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

            // Bottom Player Bar (White by default)
            _playerBar(
              name: bottomName,
              timeStr: _formatTime(bottomTime),
              isActiveTurn: isBottomTurn,
              color: bottomColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerBar({
    required String name,
    required String timeStr,
    required bool isActiveTurn,
    required PieceColor color,
  }) {
    final isWhitePiece = color == PieceColor.white;
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
            backgroundColor: isWhitePiece ? Colors.white : AppColors.surfacePanel,
            child: Text(
              isWhitePiece ? 'W' : 'B',
              style: TextStyle(
                color: isWhitePiece ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
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
