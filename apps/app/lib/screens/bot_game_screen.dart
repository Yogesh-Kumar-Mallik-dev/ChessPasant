import 'dart:math';
import 'package:flutter/material.dart';
import '../chess/models.dart';
import '../chess/engine.dart';
import '../chess/game_archive.dart';
import '../audio/sounds.dart';
import '../widgets/chess_board.dart';
import '../widgets/app_icon.dart';
import '../theme/app_theme.dart';
import '../api/api_client.dart';

class BotGameScreen extends StatefulWidget {
  final int initialLevel;
  const BotGameScreen({super.key, this.initialLevel = 2});

  @override
  State<BotGameScreen> createState() => _BotGameScreenState();
}

class _BotGameScreenState extends State<BotGameScreen> {
  String _liveFen = initialFen;
  PieceColor _liveTurn = PieceColor.white;
  final PieceColor _playerColor = PieceColor.white;
  LastMoveInfo? _liveLastMove;

  final List<Map<String, dynamic>> _boardHistory = [
    {
      'ply': 0,
      'fen': initialFen,
      'lastMove': null,
      'turn': PieceColor.white,
      'san': 'Start',
    }
  ];

  int _viewingPly = -1; // -1 means live
  bool _isGameOver = false;
  late int _botLevel;

  @override
  void initState() {
    super.initState();
    _botLevel = widget.initialLevel;
    SoundEffects().playGameStart();
  }

  void _onPlayerMove(String from, String to, String? promo) {
    if (_isGameOver || _liveTurn != _playerColor) return;

    // Immediately snap back to live mode
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
      _viewingPly = -1;

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
      _finishGame('Checkmate! You won.', winner: 'white');
      return;
    } else if (isDraw) {
      _finishGame('Draw by stalemate or repetition.', winner: 'draw');
      return;
    }

    // Bot move after brief thinking delay
    Future.delayed(const Duration(milliseconds: 350), _triggerBotMove);
  }

  Future<void> _triggerBotMove() async {
    if (_isGameOver || _liveTurn == _playerColor) return;

    // First try backend botMove if online
    Map<String, dynamic>? botRes;
    try {
      botRes = await ApiClient().botMove(_liveFen, _botLevel);
    } catch (_) {}

    String? from;
    String? to;
    String? promo;

    if (botRes != null && botRes['from'] != null && botRes['to'] != null) {
      from = botRes['from'];
      to = botRes['to'];
      promo = botRes['promotion'];
    } else {
      // Local engine fallback: calculate all legal moves and pick best / random
      final allMoves = <LegalTarget>[];
      final board = ChessEngine.fenToBoard(_liveFen);
      for (int r = 0; r < 8; r++) {
        for (int f = 0; f < 8; f++) {
          final p = board[r][f];
          if (p != null && p.color == _liveTurn) {
            final sq = '${String.fromCharCode('a'.codeUnitAt(0) + f)}${r + 1}';
            allMoves.addAll(ChessEngine.getLegalMovesForSquare(_liveFen, sq));
          }
        }
      }

      if (allMoves.isEmpty) {
        _finishGame('Game Over', winner: 'draw');
        return;
      }

      // Pick move based on bot level
      final captures = allMoves.where((m) => m.isCapture).toList();
      LegalTarget chosen;
      final rnd = Random();

      if (captures.isNotEmpty && rnd.nextDouble() < (_botLevel * 0.18)) {
        chosen = captures[rnd.nextInt(captures.length)];
      } else {
        chosen = allMoves[rnd.nextInt(allMoves.length)];
      }

      from = chosen.from;
      to = chosen.to;
      promo = chosen.isPromotion ? 'q' : null;
    }

    if (from != null && to != null) {
      final res = ChessEngine.executeMove(_liveFen, from, to, promotion: promo);
      if (res != null && res['valid'] == true) {
        final san = res['san'] as String;
        final isCap = res['isCapture'] as bool;
        final isCheck = res['isCheck'] as bool;
        final isCheckmate = res['isCheckmate'] as bool;
        final isDraw = res['isDraw'] as bool;

        SoundEffects().playMoveSound(san: san, isCapture: isCap, isCheck: isCheck);

        final moveRecord = LastMoveInfo(from: from, to: to, san: san, isCapture: isCap);

        setState(() {
          _liveFen = res['newFen'];
          _liveTurn = res['turn'];
          _liveLastMove = moveRecord;

          // Return immediately to live mode when bot plays!
          _viewingPly = -1;

          _boardHistory.add({
            'ply': _boardHistory.length,
            'from': from,
            'to': to,
            'fen': res['newFen'],
            'lastMove': moveRecord,
            'turn': res['turn'],
            'san': san,
          });
        });

        if (isCheckmate) {
          _finishGame('Checkmate! Stockfish won.', winner: 'black');
        } else if (isDraw) {
          _finishGame('Draw by stalemate or repetition.', winner: 'draw');
        }
      }
    }
  }

  void _finishGame(String result, {required String winner}) {
    SoundEffects().playGameEnd();

    final movesList = _boardHistory.skip(1).map((h) => {
      'from': h['from'],
      'to': h['to'],
      'san': h['san'],
      'fen': h['fen'],
    }).toList();

    final record = SavedGameRecord(
      title: 'vs Bot Level $_botLevel',
      mode: 'vs Bot',
      date: DateTime.now().toLocal().toString().split('.')[0],
      whitePlayer: 'You (White)',
      blackPlayer: 'Stockfish Level $_botLevel',
      result: winner == 'white' ? '1-0' : (winner == 'black' ? '0-1' : '1/2-1/2'),
      finalFen: _liveFen,
      moves: movesList,
    );

    GameArchive.saveGame(record);

    setState(() {
      _isGameOver = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        title: const Row(
          children: [
            AppIcon(name: 'trophy', size: 20, color: AppColors.textPrimary),
            SizedBox(width: 10),
            Text(
              'Match Concluded',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Text(
          result,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetGame();
            },
            child: const Text('Play Again', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true); // Return true to trigger analysis
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
    });
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
  Widget build(BuildContext context) {
    final isLiveView = _viewingPly == -1 || _viewingPly == _boardHistory.length - 1;
    final currentEntry = !isLiveView && _viewingPly >= 0 && _viewingPly < _boardHistory.length
        ? _boardHistory[_viewingPly]
        : null;

    final displayFen = currentEntry != null ? currentEntry['fen'] as String : _liveFen;
    final displayLastMove = currentEntry != null ? currentEntry['lastMove'] as LastMoveInfo? : _liveLastMove;
    final displayTurn = currentEntry != null ? currentEntry['turn'] as PieceColor : _liveTurn;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        title: Row(
          children: [
            const AppIcon(name: 'smart_toy', size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              'Bot Match (Level $_botLevel)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const AppIcon(name: 'rotate-ccw', size: 16, color: AppColors.textMuted),
            tooltip: 'Restart Match',
            onPressed: _resetGame,
          ),
          IconButton(
            icon: const AppIcon(name: 'flag', size: 16, color: AppColors.red),
            tooltip: 'Resign',
            onPressed: () {
              _finishGame('You resigned the match.', winner: 'black');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Bot Opponent Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfacePanel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: AppIcon(name: 'smart_toy', size: 20, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stockfish Engine • Level $_botLevel',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _liveTurn != _playerColor ? 'Calculating optimal reply...' : 'Waiting for your move...',
                            style: TextStyle(
                              fontSize: 12,
                              color: _liveTurn != _playerColor ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Chess Board (Natural board view)
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
                    interactive: isLiveView && !_isGameOver && _liveTurn == _playerColor,
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

            // Player Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      child: Text('W', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You (White)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
