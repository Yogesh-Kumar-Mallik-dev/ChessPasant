import 'dart:math';
import 'package:flutter/material.dart';
import '../chess/models.dart';
import '../chess/engine.dart';
import '../audio/sounds.dart';
import '../widgets/chess_board.dart';
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
  String _gameResult = '';
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
        _finishGame('Game Over.');
        return;
      }

      // Prioritize captures/checks
      final tactical = allMoves.where((m) => m.isCapture || m.san.contains('+')).toList();
      final chosen = tactical.isNotEmpty
          ? tactical[Random().nextInt(tactical.length)]
          : allMoves[Random().nextInt(allMoves.length)];

      from = chosen.from;
      to = chosen.to;
      promo = chosen.promotion;
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
          _finishGame('Checkmate! Bot won.');
        } else if (isDraw) {
          _finishGame('Draw.');
        }
      }
    }
  }

  void _finishGame(String result) {
    SoundEffects().playGameEnd();
    setState(() {
      _isGameOver = true;
      _gameResult = result;
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        title: const Text('Game Ended', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(_gameResult, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetGame();
            },
            child: const Text('Play Again', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
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
      _gameResult = '';
    });
    SoundEffects().playGameStart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141518),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2024),
        title: Text('VS Stockfish Bot (Lvl $_botLevel)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF2A2D35),
                    child: Icon(Icons.smart_toy, color: Colors.greenAccent),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stockfish Lvl $_botLevel', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(_turn != _playerColor ? 'Thinking...' : 'Waiting...', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    ],
                  ),
                ],
              ),
            ),

            // Chess Board
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

            // Player Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF2A2D35),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('You', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(_turn == _playerColor ? 'Your turn to move' : 'Waiting for bot...', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
