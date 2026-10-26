import 'package:flutter/material.dart';
import '../chess/models.dart';
import '../chess/engine.dart';
import '../audio/sounds.dart';
import '../widgets/chess_board.dart';
import '../api/api_client.dart';
import 'bot_game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _dailyPuzzle;
  String _dailyFen = initialFen;
  PieceColor _dailyTurn = PieceColor.white;
  LastMoveInfo? _dailyLastMove;
  int _solutionIdx = 0;
  bool _dailySolved = false;
  bool _isAnimating = false;
  String _statusMsg = "Today's Tactical Workout";
  Color _statusColor = Colors.white70;

  @override
  void initState() {
    super.initState();
    _loadDailyPuzzle();
  }

  Future<void> _loadDailyPuzzle() async {
    final p = await ApiClient().getDailyPuzzle();
    if (p != null && p['fen'] != null) {
      final fen = p['fen'] as String;
      final parts = fen.split(' ');
      final turn = parts.length > 1 && parts[1] == 'w' ? PieceColor.white : PieceColor.black;

      // Solution fetch
      if (p['solution'] == null || (p['solution'] as List).isEmpty) {
        ApiClient().getPuzzleSolution(p['id']).then((solRes) {
          if (solRes != null && solRes['solution'] != null) {
            setState(() {
              _dailyPuzzle?['solution'] = solRes['solution'];
            });
          }
        });
      }

      setState(() {
        _dailyPuzzle = p;
        _dailyFen = fen;
        _dailyTurn = turn;
        _dailyLastMove = null;
        _solutionIdx = 0;
        _dailySolved = false;
      });
    }
  }

  void _onDailyMove(String from, String to, String? promo) {
    if (_dailySolved || _isAnimating || _dailyPuzzle == null) return;

    final uci = '$from$to${promo ?? ''}';
    final solution = _dailyPuzzle!['solution'] as List?;
    final expectedMove = (solution != null && solution.length > _solutionIdx)
        ? solution[_solutionIdx] as String
        : '';

    final isMatch = expectedMove.isNotEmpty &&
        (expectedMove.toLowerCase() == uci.toLowerCase() ||
         expectedMove.toLowerCase().startsWith(uci.toLowerCase()));

    if (isMatch) {
      final res = ChessEngine.executeMove(_dailyFen, from, to, promotion: promo);
      if (res != null && res['valid'] == true) {
        final san = res['san'] as String;
        final isCap = res['isCapture'] as bool;
        SoundEffects().playMoveSound(san: san, isCapture: isCap);

        setState(() {
          _dailyFen = res['newFen'];
          _dailyTurn = res['turn'];
          _dailyLastMove = LastMoveInfo(from: from, to: to, san: san, isCapture: isCap);
          _solutionIdx++;
        });

        // Check if solved
        if (solution != null && _solutionIdx >= solution.length) {
          SoundEffects().playGameEnd();
          setState(() {
            _dailySolved = true;
            _statusMsg = 'Splendid! Puzzle solved correctly.';
            _statusColor = Colors.greenAccent;
          });
          return;
        }

        // Opponent automatic response
        if (solution != null && _solutionIdx < solution.length) {
          setState(() {
            _isAnimating = true;
            _statusMsg = 'Best move! Opponent replying...';
            _statusColor = Colors.white70;
          });

          final oppUci = solution[_solutionIdx] as String;
          final oppFrom = oppUci.substring(0, 2);
          final oppTo = oppUci.substring(2, 4);
          final oppPromo = oppUci.length > 4 ? oppUci.substring(4, 5) : null;

          Future.delayed(const Duration(milliseconds: 380), () {
            final oppRes = ChessEngine.executeMove(_dailyFen, oppFrom, oppTo, promotion: oppPromo);
            if (oppRes != null && oppRes['valid'] == true) {
              final oppSan = oppRes['san'] as String;
              final oppCap = oppRes['isCapture'] as bool;
              SoundEffects().playMoveSound(san: oppSan, isCapture: oppCap);

              setState(() {
                _dailyFen = oppRes['newFen'];
                _dailyTurn = oppRes['turn'];
                _dailyLastMove = LastMoveInfo(from: oppFrom, to: oppTo, san: oppSan, isCapture: oppCap);
                _solutionIdx++;
                _isAnimating = false;
                _statusMsg = 'Your turn. Keep calculating!';
              });
            } else {
              setState(() => _isAnimating = false);
            }
          });
        }
      }
    } else {
      // Wrong move: execute visually, show error and retract after 800ms
      final wrongRes = ChessEngine.executeMove(_dailyFen, from, to, promotion: promo);
      if (wrongRes != null && wrongRes['valid'] == true) {
        final prevFen = _dailyFen;
        final prevTurn = _dailyTurn;
        final prevLast = _dailyLastMove;
        final san = wrongRes['san'] as String;

        SoundEffects().playIllegal();
        setState(() {
          _dailyFen = wrongRes['newFen'];
          _dailyTurn = wrongRes['turn'];
          _dailyLastMove = LastMoveInfo(from: from, to: to, san: san);
          _statusMsg = 'Incorrect: $san is not optimal. Retracting...';
          _statusColor = Colors.redAccent;
          _isAnimating = true;
        });

        Future.delayed(const Duration(milliseconds: 800), () {
          setState(() {
            _dailyFen = prevFen;
            _dailyTurn = prevTurn;
            _dailyLastMove = prevLast;
            _statusMsg = 'Not the best move. Try again!';
            _statusColor = Colors.white70;
            _isAnimating = false;
          });
        });
      } else {
        SoundEffects().playIllegal();
        setState(() {
          _statusMsg = 'Illegal move. Try again!';
          _statusColor = Colors.redAccent;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141518),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2024),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield, color: Colors.greenAccent, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('ChessPasant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Match Grid
            const Text('Quick Duel', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: [
                _quickMatchBtn('1+0', 'Bullet', Icons.bolt, Colors.amberAccent),
                _quickMatchBtn('3+0', 'Blitz', Icons.flash_on, Colors.orangeAccent),
                _quickMatchBtn('5+0', 'Blitz', Icons.timer, Colors.cyanAccent),
                _quickMatchBtn('10+0', 'Rapid', Icons.access_time, Colors.greenAccent),
              ],
            ),

            const SizedBox(height: 24),

            // Bot Match Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2024),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.smart_toy, color: Colors.purpleAccent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('VS Stockfish Bot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 2),
                        Text('Offline & Online skill levels (1-5)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BotGameScreen()));
                    },
                    child: const Text('Play'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Daily Tactical Workout Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2024),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology, color: Colors.amberAccent, size: 20),
                      const SizedBox(width: 8),
                      const Text('Daily Puzzle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      Text(
                        _dailyTurn == PieceColor.white ? 'White to move' : 'Black to move',
                        style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_statusMsg, style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ChessBoardWidget(
                    fen: _dailyFen,
                    orientation: _dailyTurn,
                    turn: _dailyTurn,
                    playerColor: _dailyTurn,
                    lastMove: _dailyLastMove,
                    interactive: !_dailySolved && !_isAnimating,
                    onMove: _onDailyMove,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickMatchBtn(String time, String label, IconData icon, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        // Navigates to matchmaking or bot match
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BotGameScreen()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2024),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
