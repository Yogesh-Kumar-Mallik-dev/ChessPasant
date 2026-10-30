import 'dart:math';
import 'package:flutter/material.dart';
import '../chess/models.dart';
import '../chess/engine.dart';
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
  String _fen = initialFen;
  PieceColor _turn = PieceColor.white;
  final PieceColor _playerColor = PieceColor.white;
  LastMoveInfo? _lastMove;
  final List<String> _sanHistory = [];
  bool _isGameOver = false;
  late int _botLevel;

  @override
  void initState() {
    super.initState();
    _botLevel = widget.initialLevel;
    SoundEffects().playGameStart();
  }

  void _onPlayerMove(String from, String to, String? promo) {
    if (_isGameOver || _turn != _playerColor) return;

    final res = ChessEngine.executeMove(_fen, from, to, promotion: promo);
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

    setState(() {
      _fen = nextFen;
      _turn = nextTurn;
      _lastMove = LastMoveInfo(from: from, to: to, san: san, isCapture: isCap);
      _sanHistory.add(san);
    });

    if (isCheckmate) {
      _finishGame('Checkmate! You won.');
      return;
    } else if (isDraw) {
      _finishGame('Draw by stalemate or repetition.');
      return;
    }

    // Bot move after brief thinking delay
    Future.delayed(const Duration(milliseconds: 350), _triggerBotMove);
  }

  Future<void> _triggerBotMove() async {
    if (_isGameOver || _turn == _playerColor) return;

    // First try backend botMove if online
    Map<String, dynamic>? botRes;
    try {
      botRes = await ApiClient().botMove(_fen, _botLevel);
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
      final board = ChessEngine.fenToBoard(_fen);
      for (int r = 0; r < 8; r++) {
        for (int f = 0; f < 8; f++) {
          final p = board[r][f];
          if (p != null && p.color == _turn) {
            final sq = '${String.fromCharCode('a'.codeUnitAt(0) + f)}${r + 1}';
            allMoves.addAll(ChessEngine.getLegalMovesForSquare(_fen, sq));
          }
        }
      }

      if (allMoves.isEmpty) {
        _finishGame('Game Over');
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
      final res = ChessEngine.executeMove(_fen, from, to, promotion: promo);
      if (res != null && res['valid'] == true) {
        final san = res['san'] as String;
        final isCap = res['isCapture'] as bool;
        final isCheck = res['isCheck'] as bool;
        final isCheckmate = res['isCheckmate'] as bool;
        final isDraw = res['isDraw'] as bool;

        SoundEffects().playMoveSound(san: san, isCapture: isCap, isCheck: isCheck);

        setState(() {
          _fen = res['newFen'];
          _turn = res['turn'];
          _lastMove = LastMoveInfo(from: from!, to: to!, san: san, isCapture: isCap);
          _sanHistory.add(san);
        });

        if (isCheckmate) {
          _finishGame('Checkmate! Stockfish won.');
        } else if (isDraw) {
          _finishGame('Draw by stalemate or repetition.');
        }
      }
    }
  }

  void _finishGame(String result) {
    SoundEffects().playGameEnd();
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
            AppIcon(name: 'trophy', size: 20, color: AppColors.amber),
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
              Navigator.of(context).pop();
            },
            child: const Text('Exit to Hub', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _resetGame() {
    setState(() {
      _fen = initialFen;
      _turn = PieceColor.white;
      _lastMove = null;
      _sanHistory.clear();
      _isGameOver = false;
    });
    SoundEffects().playGameStart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        shape: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfacePanel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const AppIcon(name: 'swords', size: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 10),
            Text(
              'VS Stockfish Bot (Lvl $_botLevel)',
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
            icon: const AppIcon(name: 'rotate-cw', size: 18, color: AppColors.textMuted),
            onPressed: _resetGame,
            tooltip: 'Restart Match',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Opponent Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
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
                            _turn != _playerColor ? 'Calculating optimal reply...' : 'Waiting for move...',
                            style: TextStyle(
                              fontSize: 12,
                              color: _turn != _playerColor ? AppColors.amber : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Chess Board
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

            // Player Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
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
                        child: AppIcon(name: 'user', size: 20, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'You (White)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _turn == _playerColor ? 'Your turn to move' : 'Waiting for opponent...',
                            style: TextStyle(
                              fontSize: 12,
                              color: _turn == _playerColor ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                          ),
                        ],
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
