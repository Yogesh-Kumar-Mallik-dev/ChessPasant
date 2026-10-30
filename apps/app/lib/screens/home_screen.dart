import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../chess/models.dart';
import '../chess/engine.dart';
import '../audio/sounds.dart';
import '../widgets/chess_board.dart';
import '../widgets/app_icon.dart';
import '../widgets/navigation_dock.dart';
import '../theme/app_theme.dart';
import '../api/api_client.dart';
import 'bot_game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  // Daily Puzzle State
  Map<String, dynamic>? _dailyPuzzle;
  String _dailyFen = initialFen;
  PieceColor _dailyTurn = PieceColor.white;
  LastMoveInfo? _dailyLastMove;
  int _solutionIdx = 0;
  bool _dailySolved = false;
  bool _isDailyAnimating = false;
  String _dailyStatusMsg = "Today's Tactical Workout";
  Color _dailyStatusColor = AppColors.textMuted;

  // Bot quick level selection
  int _selectedBotLevel = 2;

  // Analysis board state
  String _analysisFen = initialFen;
  PieceColor _analysisTurn = PieceColor.white;
  PieceColor _analysisOrientation = PieceColor.white;
  LastMoveInfo? _analysisLastMove;
  final List<String> _analysisHistory = [];

  // Tactics board state
  String _tacticsFen = 'r1bqkb1r/pppp1ppp/2n5/4p3/2B1n3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 5';
  PieceColor _tacticsTurn = PieceColor.white;
  LastMoveInfo? _tacticsLastMove;
  String _tacticsStatus = 'White to play. Find the tactical motif!';
  bool _tacticsSolved = false;

  // Online Matchmaking state
  bool _isSearchingMatch = false;
  String? _selectedTimeControl = '3+0';

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
        _dailyStatusMsg = "Today's Tactical Workout";
        _dailyStatusColor = AppColors.textMuted;
      });
    }
  }

  void _onDailyMove(String from, String to, String? promo) {
    if (_dailySolved || _isDailyAnimating || _dailyPuzzle == null) return;

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

        if (solution != null && _solutionIdx >= solution.length) {
          SoundEffects().playGameEnd();
          setState(() {
            _dailySolved = true;
            _dailyStatusMsg = 'Splendid! Puzzle solved correctly.';
            _dailyStatusColor = AppColors.green;
          });
          return;
        }

        if (solution != null && _solutionIdx < solution.length) {
          setState(() {
            _isDailyAnimating = true;
            _dailyStatusMsg = 'Best move! Opponent replying...';
            _dailyStatusColor = AppColors.textPrimary;
          });

          final oppUci = solution[_solutionIdx] as String;
          final oppFrom = oppUci.substring(0, 2);
          final oppTo = oppUci.substring(2, 4);
          final oppPromo = oppUci.length > 4 ? oppUci.substring(4, 5) : null;

          Future.delayed(const Duration(milliseconds: 380), () {
            final oppRes = ChessEngine.executeMove(
              _dailyFen,
              oppFrom,
              oppTo,
              promotion: oppPromo,
            );
            if (oppRes != null && oppRes['valid'] == true) {
              final oppSan = oppRes['san'] as String;
              final oppCap = oppRes['isCapture'] as bool;
              SoundEffects().playMoveSound(san: oppSan, isCapture: oppCap);

              setState(() {
                _dailyFen = oppRes['newFen'];
                _dailyTurn = oppRes['turn'];
                _dailyLastMove = LastMoveInfo(
                  from: oppFrom,
                  to: oppTo,
                  san: oppSan,
                  isCapture: oppCap,
                );
                _solutionIdx++;
                _isDailyAnimating = false;
                _dailyStatusMsg = 'Your turn. Keep calculating!';
                _dailyStatusColor = AppColors.textPrimary;
              });
            } else {
              setState(() => _isDailyAnimating = false);
            }
          });
        }
      }
    } else {
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
          _dailyStatusMsg = 'Incorrect: $san is not optimal. Retracting...';
          _dailyStatusColor = AppColors.red;
          _isDailyAnimating = true;
        });

        Future.delayed(const Duration(milliseconds: 800), () {
          setState(() {
            _dailyFen = prevFen;
            _dailyTurn = prevTurn;
            _dailyLastMove = prevLast;
            _dailyStatusMsg = 'Not the best move. Try again!';
            _dailyStatusColor = AppColors.textMuted;
            _isDailyAnimating = false;
          });
        });
      } else {
        SoundEffects().playIllegal();
        setState(() {
          _dailyStatusMsg = 'Illegal move. Try again!';
          _dailyStatusColor = AppColors.red;
        });
      }
    }
  }

  void _onAnalysisMove(String from, String to, String? promo) {
    final res = ChessEngine.executeMove(_analysisFen, from, to, promotion: promo);
    if (res != null && res['valid'] == true) {
      final san = res['san'] as String;
      final isCap = res['isCapture'] as bool;
      SoundEffects().playMoveSound(san: san, isCapture: isCap);
      setState(() {
        _analysisFen = res['newFen'];
        _analysisTurn = res['turn'];
        _analysisLastMove = LastMoveInfo(from: from, to: to, san: san, isCapture: isCap);
        _analysisHistory.add(san);
      });
    } else {
      SoundEffects().playIllegal();
    }
  }

  void _resetAnalysisBoard() {
    setState(() {
      _analysisFen = initialFen;
      _analysisTurn = PieceColor.white;
      _analysisLastMove = null;
      _analysisHistory.clear();
    });
    SoundEffects().playGameStart();
  }

  void _onTacticsMove(String from, String to, String? promo) {
    if (_tacticsSolved) return;
    final res = ChessEngine.executeMove(_tacticsFen, from, to, promotion: promo);
    if (res != null && res['valid'] == true) {
      final san = res['san'] as String;
      final isCap = res['isCapture'] as bool;
      SoundEffects().playMoveSound(san: san, isCapture: isCap);
      setState(() {
        _tacticsFen = res['newFen'];
        _tacticsTurn = res['turn'];
        _tacticsLastMove = LastMoveInfo(from: from, to: to, san: san, isCapture: isCap);
        if (san.contains('Bxf7') || san.contains('Bxf7+')) {
          _tacticsSolved = true;
          _tacticsStatus = 'Splendid! Sacrifice opens the king.';
          SoundEffects().playGameEnd();
        } else {
          _tacticsStatus = 'Good move! Continue your line.';
        }
      });
    } else {
      SoundEffects().playIllegal();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main Body per active tab
          IndexedStack(
            index: _currentTabIndex,
            children: [
              _buildPlayTab(),
              _buildOnlineTab(),
              _buildPuzzlesTab(),
              _buildAnalysisTab(),
              _buildRankingsTab(),
            ],
          ),

          // Floating Signature Bottom Navigation Dock
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: NavigationDock(
              currentIndex: _currentTabIndex,
              onTabSelected: (index) {
                setState(() => _currentTabIndex = index);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 0: PLAY (NATIVE DASHBOARD)
  // ==========================================
  Widget _buildPlayTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 96),
        children: [
          // 1. Top Brand & Profile Header
          _buildHeaderBar(),
          const SizedBox(height: 18),

          // 2. Rating Pills Bar
          _buildRatingPills(),
          const SizedBox(height: 20),

          // 3. Quick Pairing 8-Preset Grid
          _buildQuickPairingGrid(),
          const SizedBox(height: 22),

          // 4. Spar with Bot Card
          _buildBotChallengeCard(),
          const SizedBox(height: 22),

          // 5. Daily Tactical Workout Card
          _buildDailyWorkoutCard(),
          const SizedBox(height: 22),

          // 6. Pass & Play Local Sparring
          _buildPassAndPlayCard(),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Brand Logo & Title
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/icons/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const AppIcon(
                  name: 'crown',
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ChessPasant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Studio Noir Edition',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Live Server Status Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Online',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingPills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _ratingPill(icon: 'zap', label: 'Bullet', rating: '400'),
          const SizedBox(width: 8),
          _ratingPill(icon: 'flame', label: 'Blitz', rating: '400'),
          const SizedBox(width: 8),
          _ratingPill(icon: 'timer', label: 'Rapid', rating: '400'),
          const SizedBox(width: 8),
          _ratingPill(icon: 'puzzle', label: 'Tactics', rating: '400'),
        ],
      ),
    );
  }

  Widget _ratingPill({
    required String icon,
    required String label,
    required String rating,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(name: icon, size: 14, color: AppColors.textPrimary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                rating,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPairingGrid() {
    final presets = [
      {'label': '1 min', 'type': 'Bullet', 'icon': 'zap', 'pop': false},
      {'label': '2 | 1', 'type': 'Bullet', 'icon': 'zap', 'pop': false},
      {'label': '3 min', 'type': 'Blitz', 'icon': 'flame', 'pop': true},
      {'label': '3 | 2', 'type': 'Blitz', 'icon': 'flame', 'pop': false},
      {'label': '5 min', 'type': 'Blitz', 'icon': 'flame', 'pop': false},
      {'label': '10 min', 'type': 'Rapid', 'icon': 'timer', 'pop': false},
      {'label': '15 | 10', 'type': 'Rapid', 'icon': 'timer', 'pop': false},
      {'label': '30 min', 'type': 'Classical', 'icon': 'hourglass', 'pop': false},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  AppIcon(name: 'zap', size: 16, color: AppColors.textPrimary),
                  SizedBox(width: 8),
                  Text(
                    'Quick Pairing',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _currentTabIndex = 1);
                },
                child: const Row(
                  children: [
                    Text(
                      'Custom Game',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    SizedBox(width: 4),
                    AppIcon(name: 'chevron-right', size: 12, color: AppColors.textMuted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 8-Preset Grid
          GridView.builder(
            itemCount: presets.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (ctx, idx) {
              final item = presets[idx];
              final isPop = item['pop'] as bool;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedTimeControl = item['label'] as String;
                    _currentTabIndex = 1;
                    _isSearchingMatch = true;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfacePanel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isPop)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'HOT',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: AppColors.background,
                              ),
                            ),
                          ),
                        ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon(
                            name: item['icon'] as String,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['label'] as String,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            item['type'] as String,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBotChallengeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfacePanel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: AppIcon(name: 'smart_toy', size: 22, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spar with Bot',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Stockfish engine from 400 to 2000 Elo',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bot Level Selector (1-5)
          Row(
            children: [
              const Text(
                'Skill Level:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: List.generate(5, (i) {
                    final lvl = i + 1;
                    final isSel = _selectedBotLevel == lvl;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedBotLevel = lvl);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.textPrimary : AppColors.surfacePanel,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSel ? AppColors.textPrimary : AppColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$lvl',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSel ? AppColors.background : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Play Bot Button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BotGameScreen(initialLevel: _selectedBotLevel),
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(name: 'swords', size: 16, color: AppColors.background),
                  SizedBox(width: 8),
                  Text(
                    'Start Sparring',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyWorkoutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  AppIcon(name: 'puzzle', size: 16, color: AppColors.textPrimary),
                  SizedBox(width: 8),
                  Text(
                    'Daily Tactical Workout',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const AppIcon(name: 'rotate-cw', size: 15, color: AppColors.textMuted),
                onPressed: _loadDailyPuzzle,
                tooltip: 'Reset Daily Puzzle',
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfacePanel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _dailyStatusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _dailyStatusMsg,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _dailyStatusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Interactive Chess Board
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: ChessBoardWidget(
              fen: _dailyFen,
              orientation: _dailyTurn,
              turn: _dailyTurn,
              lastMove: _dailyLastMove,
              interactive: !_dailySolved && !_isDailyAnimating,
              onMove: _onDailyMove,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassAndPlayCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfacePanel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: AppIcon(name: 'handshake', size: 22, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pass & Play',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Local two-player over the board',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfacePanel,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              setState(() => _currentTabIndex = 3); // Open analysis/free board
            },
            child: const Text('Play Over Board', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: ONLINE MATCHMAKING & LOBBY
  // ==========================================
  Widget _buildOnlineTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 96),
        children: [
          const Text(
            'Live Matchmaking',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          const Text(
            'Connect with chess enthusiasts worldwide',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),

          // Queue Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfacePanel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: _isSearchingMatch
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : const AppIcon(name: 'zap', size: 28, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isSearchingMatch ? 'Searching for an opponent...' : 'Ready to Duel',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _isSearchingMatch
                      ? 'Queue: $_selectedTimeControl Rated Pool'
                      : 'Selected Time Control: $_selectedTimeControl',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSearchingMatch ? AppColors.surfacePanel : AppColors.textPrimary,
                      foregroundColor: _isSearchingMatch ? AppColors.red : AppColors.background,
                      elevation: 0,
                      side: _isSearchingMatch ? const BorderSide(color: AppColors.red) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      setState(() => _isSearchingMatch = !_isSearchingMatch);
                    },
                    child: Text(
                      _isSearchingMatch ? 'Cancel Search' : 'Find Opponent',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Custom Friendly Challenge
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    AppIcon(name: 'users', size: 18, color: AppColors.textPrimary),
                    SizedBox(width: 8),
                    Text(
                      'Challenge a Friend',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Share an invite link or invite a registered player by username',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Enter username or challenge link',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surfacePanel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.textPrimary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PUZZLES & TACTICS LAB
  // ==========================================
  Widget _buildPuzzlesTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 96),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tactics Lab',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Master tactical motifs and puzzle streaks',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    AppIcon(name: 'trophy', size: 14, color: AppColors.amber),
                    SizedBox(width: 6),
                    Text(
                      '1540 Elo',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                AppIcon(
                  name: _tacticsSolved ? 'check' : 'puzzle',
                  size: 16,
                  color: _tacticsSolved ? AppColors.green : AppColors.amber,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _tacticsStatus,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _tacticsSolved ? AppColors.green : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tactics Chess Board
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 390),
            child: ChessBoardWidget(
              fen: _tacticsFen,
              orientation: PieceColor.white,
              turn: _tacticsTurn,
              lastMove: _tacticsLastMove,
              interactive: !_tacticsSolved,
              onMove: _onTacticsMove,
            ),
          ),
          const SizedBox(height: 16),

          // Next / Skip Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceCard,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  _tacticsFen = 'r1bqk2r/pppp1ppp/2n5/4p3/1bB1n3/5N2/PPPP1PPP/RNBQ1RK1 w kq - 2 6';
                  _tacticsSolved = false;
                  _tacticsStatus = 'Next Puzzle: White to move.';
                  _tacticsLastMove = null;
                });
              },
              child: const Text('Next Puzzle', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: GAME ANALYSIS BOARD
  // ==========================================
  Widget _buildAnalysisTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 96),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analysis Board',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Explore positions & variations freely',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const AppIcon(name: 'rotate-cw', size: 16, color: AppColors.textMuted),
                    onPressed: _resetAnalysisBoard,
                    tooltip: 'Reset Board',
                  ),
                  IconButton(
                    icon: const AppIcon(name: 'rotate-ccw', size: 16, color: AppColors.textMuted),
                    onPressed: () {
                      setState(() {
                        _analysisOrientation = _analysisOrientation == PieceColor.white
                            ? PieceColor.black
                            : PieceColor.white;
                      });
                    },
                    tooltip: 'Flip Board',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Analysis Board
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 390),
            child: ChessBoardWidget(
              fen: _analysisFen,
              orientation: _analysisOrientation,
              turn: _analysisTurn,
              lastMove: _analysisLastMove,
              interactive: true,
              onMove: _onAnalysisMove,
            ),
          ),
          const SizedBox(height: 14),

          // Move History Pills
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Move History',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                _analysisHistory.isEmpty
                    ? const Text(
                        'Make moves on the board to analyze variations',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: List.generate(_analysisHistory.length, (i) {
                          final san = _analysisHistory[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfacePanel,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              '${i + 1}. $san',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                        }),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: RANKINGS & LEADERBOARD
  // ==========================================
  Widget _buildRankingsTab() {
    final topPlayers = [
      {'rank': '1', 'name': 'Magnus C.', 'rating': '2882', 'win': '74%'},
      {'rank': '2', 'name': 'Hikaru N.', 'rating': '2875', 'win': '71%'},
      {'rank': '3', 'name': 'Alireza F.', 'rating': '2804', 'win': '68%'},
      {'rank': '4', 'name': 'Gukesh D.', 'rating': '2798', 'win': '66%'},
      {'rank': '5', 'name': 'Nodirbek A.', 'rating': '2783', 'win': '65%'},
      {'rank': '6', 'name': 'Ding L.', 'rating': '2778', 'win': '63%'},
      {'rank': '7', 'name': 'Fabiano C.', 'rating': '2776', 'win': '62%'},
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 96),
        children: [
          const Text(
            'Global Leaderboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          const Text(
            'Top rated acoustic grandmasters',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),

          // Leaderboard List
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topPlayers.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderSubtle),
              itemBuilder: (ctx, idx) {
                final p = topPlayers[idx];
                final rank = int.parse(p['rank']!);
                final isPodium = rank <= 3;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isPodium ? AppColors.amber.withValues(alpha: 0.15) : AppColors.surfacePanel,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPodium ? AppColors.amber : AppColors.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '#${p['rank']}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPodium ? AppColors.amber : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['name']!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Win Rate: ${p['win']}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfacePanel,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${p['rating']} ELO',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
