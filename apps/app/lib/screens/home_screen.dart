import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../chess/models.dart';
import '../chess/engine.dart';
import '../audio/sounds.dart';
import '../widgets/chess_board.dart';
import '../widgets/eval_bar.dart';
import '../widgets/app_icon.dart';
import '../widgets/navigation_dock.dart';
import '../theme/app_theme.dart';
import '../api/api_client.dart';
import 'bot_game_screen.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  // ==========================================
  // AUTH & USER PROFILE STATE
  // ==========================================
  bool _isAuthLoading = false;
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic> _userRatings = {
    'bullet': 400,
    'blitz': 400,
    'rapid': 400,
    'classical': 400,
    'puzzles': 400,
  };
  bool _isLoginMode = true;
  final TextEditingController _authUsernameCtrl = TextEditingController();
  final TextEditingController _authEmailCtrl = TextEditingController();
  final TextEditingController _authPasswordCtrl = TextEditingController();
  String _authError = '';

  // Leaderboard Modal State
  bool _showLeaderboard = false;
  String _activeLeaderboardCat = 'blitz';
  List<dynamic> _leaderboardList = [];
  bool _isLeaderboardLoading = false;

  // ==========================================
  // ONLINE MATCHMAKING STATE
  // ==========================================
  final List<Map<String, dynamic>> _onlinePresets = [
    {'label': '1 min', 'initial': 60, 'increment': 0, 'type': 'Bullet', 'icon': 'zap', 'desc': 'Lightning reflex', 'pop': false},
    {'label': '2 | 1', 'initial': 120, 'increment': 1, 'type': 'Bullet', 'icon': 'zap', 'desc': 'Bullet with increment', 'pop': false},
    {'label': '3 min', 'initial': 180, 'increment': 0, 'type': 'Blitz', 'icon': 'flame', 'desc': 'Standard blitz', 'pop': true},
    {'label': '3 | 2', 'initial': 180, 'increment': 2, 'type': 'Blitz', 'icon': 'flame', 'desc': 'Competitive blitz', 'pop': false},
    {'label': '5 min', 'initial': 300, 'increment': 0, 'type': 'Blitz', 'icon': 'flame', 'desc': 'Full blitz', 'pop': false},
    {'label': '10 min', 'initial': 600, 'increment': 0, 'type': 'Rapid', 'icon': 'timer', 'desc': 'Deep tactical', 'pop': false},
    {'label': '15 | 10', 'initial': 900, 'increment': 10, 'type': 'Rapid', 'icon': 'timer', 'desc': 'Tournament rapid', 'pop': false},
    {'label': '30 min', 'initial': 1800, 'increment': 0, 'type': 'Classical', 'icon': 'hourglass', 'desc': 'Pure classical', 'pop': false},
  ];

  late Map<String, dynamic> _selectedOnlinePreset;
  bool _isSearchingMatch = false;
  int _searchWaitSec = 0;
  Timer? _searchTimer;
  Timer? _pollTimer;
  String _matchmakingError = '';
  bool _isCustomMode = false;
  int _customInitialMin = 5;
  int _customIncrementSec = 3;
  bool _customRated = true;
  String _customColorPref = 'random'; // random, white, black

  // ==========================================
  // DAILY PUZZLE STATE (PLAY TAB)
  // ==========================================
  Map<String, dynamic>? _dailyPuzzle;
  String _dailyFen = initialFen;
  PieceColor _dailyTurn = PieceColor.white;
  LastMoveInfo? _dailyLastMove;
  int _dailySolutionIdx = 0;
  bool _dailySolved = false;
  bool _isDailyAnimating = false;
  String _dailyStatusMsg = "Today's Tactical Workout";
  Color _dailyStatusColor = AppColors.textMuted;
  int _selectedBotLevel = 2;

  // ==========================================
  // TACTICS LAB STATE (PUZZLES TAB)
  // ==========================================
  String _tacticsFen = 'r1bqkb1r/pppp1ppp/2n5/4p3/2B1n3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 5';
  PieceColor _tacticsTurn = PieceColor.white;
  LastMoveInfo? _tacticsLastMove;
  String _tacticsStatus = 'White to play. Find the tactical motif!';
  bool _tacticsSolved = false;

  // ==========================================
  // ANALYSIS BOARD STATE (ANALYSIS TAB)
  // ==========================================
  String _analysisFen = initialFen;
  PieceColor _analysisTurn = PieceColor.white;
  PieceColor _analysisOrientation = PieceColor.white;
  LastMoveInfo? _analysisLastMove;
  final List<Map<String, dynamic>> _analysisHistory = []; // {from, to, san, fen}
  int _analysisCurrentPly = 0;
  bool _isEngineEnabled = true;
  int _analysisScoreCp = 0;
  bool _analysisIsMate = false;
  int? _analysisMateIn;
  String _analysisBestMove = '';
  List<String> _analysisPv = [];
  int _analysisDepth = 12;
  Timer? _evalDebounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedOnlinePreset = _onlinePresets[2]; // Default 3 min Blitz
    _loadAuthProfile();
    _loadDailyPuzzle();
    _evaluateCurrentAnalysisPosition();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _pollTimer?.cancel();
    _evalDebounceTimer?.cancel();
    _authUsernameCtrl.dispose();
    _authEmailCtrl.dispose();
    _authPasswordCtrl.dispose();
    super.dispose();
  }

  // ==========================================
  // AUTH LOGIC
  // ==========================================
  Future<void> _loadAuthProfile() async {
    if (!ApiClient().isAuthenticated) {
      setState(() {
        _currentUser = null;
      });
      return;
    }
    setState(() => _isAuthLoading = true);
    final data = await ApiClient().getMe();
    setState(() => _isAuthLoading = false);

    if (data != null && data['user'] != null) {
      setState(() {
        _currentUser = data['user'];
        if (data['ratings'] != null) {
          _userRatings = Map<String, dynamic>.from(data['ratings']);
        }
      });
    }
  }

  Future<void> _handleAuthSubmit() async {
    final username = _authUsernameCtrl.text.trim();
    final password = _authPasswordCtrl.text.trim();
    final email = _authEmailCtrl.text.trim();

    if (username.isEmpty || password.isEmpty || (!_isLoginMode && email.isEmpty)) {
      setState(() => _authError = 'Please fill out all required fields.');
      return;
    }

    setState(() {
      _isAuthLoading = true;
      _authError = '';
    });

    try {
      if (_isLoginMode) {
        await ApiClient().login(username, password);
      } else {
        await ApiClient().register(username, email, password);
      }
      await _loadAuthProfile();
      _authPasswordCtrl.clear();
      SoundEffects().playGameStart();
    } catch (e) {
      setState(() => _authError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isAuthLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    await ApiClient().logout();
    setState(() {
      _currentUser = null;
      _userRatings = {
        'bullet': 400,
        'blitz': 400,
        'rapid': 400,
        'classical': 400,
        'puzzles': 400,
      };
    });
  }

  // ==========================================
  // LEADERBOARD LOGIC
  // ==========================================
  Future<void> _loadLeaderboardCategory(String cat) async {
    setState(() {
      _activeLeaderboardCat = cat;
      _isLeaderboardLoading = true;
    });

    final list = await ApiClient().getLeaderboard(cat);

    setState(() {
      _leaderboardList = list;
      _isLeaderboardLoading = false;
    });
  }

  // ==========================================
  // ONLINE MATCHMAKING LOGIC
  // ==========================================
  void _startMatchmaking() async {
    if (!ApiClient().isAuthenticated) {
      setState(() {
        _currentTabIndex = 4; // Switch to Profile/Auth tab
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in or create an account to play online.'),
          backgroundColor: AppColors.surfaceCard,
        ),
      );
      return;
    }

    setState(() {
      _isSearchingMatch = true;
      _searchWaitSec = 0;
      _matchmakingError = '';
    });

    final initial = _isCustomMode ? _customInitialMin * 60 : (_selectedOnlinePreset['initial'] as int);
    final increment = _isCustomMode ? _customIncrementSec : (_selectedOnlinePreset['increment'] as int);

    try {
      await ApiClient().joinMatchmaking(initial: initial, increment: increment);

      _searchTimer?.cancel();
      _searchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _searchWaitSec++);
      });

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
        final status = await ApiClient().getMatchmakingStatus();
        if (status != null && status['status'] == 'matched') {
          _cancelMatchmaking();
          final gameId = status['gameId']?.toString() ?? '';
          if (gameId.isNotEmpty && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GameScreen(
                  gameId: gameId,
                  token: ApiClient().authToken ?? '',
                  currentUserId: _currentUser?['id']?.toString() ?? '',
                ),
              ),
            );
          }
        }
      });
    } catch (e) {
      setState(() {
        _isSearchingMatch = false;
        _matchmakingError = 'Could not enter matchmaking queue: $e';
      });
    }
  }

  void _cancelMatchmaking() {
    _searchTimer?.cancel();
    _pollTimer?.cancel();
    ApiClient().leaveMatchmaking();
    setState(() {
      _isSearchingMatch = false;
      _searchWaitSec = 0;
    });
  }

  String _getToleranceText() {
    if (_searchWaitSec < 10) return '±50 Elo';
    if (_searchWaitSec < 20) return '±100 Elo';
    if (_searchWaitSec < 35) return '±250 Elo';
    return 'Any Rating';
  }

  // ==========================================
  // DAILY PUZZLE LOGIC
  // ==========================================
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
        _dailySolutionIdx = 0;
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
    final expectedMove = (solution != null && solution.length > _dailySolutionIdx)
        ? solution[_dailySolutionIdx] as String
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
          _dailySolutionIdx++;
        });

        if (solution != null && _dailySolutionIdx >= solution.length) {
          SoundEffects().playGameEnd();
          setState(() {
            _dailySolved = true;
            _dailyStatusMsg = 'Splendid! Puzzle solved correctly.';
            _dailyStatusColor = AppColors.green;
          });
          return;
        }

        if (solution != null && _dailySolutionIdx < solution.length) {
          setState(() {
            _isDailyAnimating = true;
            _dailyStatusMsg = 'Best move! Opponent replying...';
            _dailyStatusColor = AppColors.textPrimary;
          });

          final oppUci = solution[_dailySolutionIdx] as String;
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
                _dailySolutionIdx++;
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

  // ==========================================
  // ANALYSIS BOARD LOGIC
  // ==========================================
  void _onAnalysisMove(String from, String to, String? promo) {
    final res = ChessEngine.executeMove(_analysisFen, from, to, promotion: promo);
    if (res != null && res['valid'] == true) {
      final san = res['san'] as String;
      final isCap = res['isCapture'] as bool;
      SoundEffects().playMoveSound(san: san, isCapture: isCap);

      // Truncate future branches if branching from earlier ply
      if (_analysisCurrentPly < _analysisHistory.length) {
        _analysisHistory.removeRange(_analysisCurrentPly, _analysisHistory.length);
      }

      final moveRecord = {
        'from': from,
        'to': to,
        'san': san,
        'fen': res['newFen'] as String,
      };
      _analysisHistory.add(moveRecord);
      _analysisCurrentPly = _analysisHistory.length;

      setState(() {
        _analysisFen = res['newFen'];
        _analysisTurn = res['turn'];
        _analysisLastMove = LastMoveInfo(from: from, to: to, san: san, isCapture: isCap);
      });

      _triggerAnalysisEvaluation();
    } else {
      SoundEffects().playIllegal();
    }
  }

  void _jumpToPly(int ply) {
    if (ply < 0 || ply > _analysisHistory.length) return;

    if (ply == 0) {
      setState(() {
        _analysisCurrentPly = 0;
        _analysisFen = initialFen;
        _analysisTurn = PieceColor.white;
        _analysisLastMove = null;
      });
    } else {
      final rec = _analysisHistory[ply - 1];
      final parts = (rec['fen'] as String).split(' ');
      final turn = parts.length > 1 && parts[1] == 'w' ? PieceColor.white : PieceColor.black;

      setState(() {
        _analysisCurrentPly = ply;
        _analysisFen = rec['fen'];
        _analysisTurn = turn;
        _analysisLastMove = LastMoveInfo(
          from: rec['from'],
          to: rec['to'],
          san: rec['san'],
        );
      });
    }

    _triggerAnalysisEvaluation();
  }

  void _triggerAnalysisEvaluation() {
    if (!_isEngineEnabled) return;
    _evalDebounceTimer?.cancel();
    _evalDebounceTimer = Timer(const Duration(milliseconds: 280), () {
      _evaluateCurrentAnalysisPosition();
    });
  }

  Future<void> _evaluateCurrentAnalysisPosition() async {
    if (!_isEngineEnabled) return;
    final targetFen = _analysisFen;
    final evalData = await ApiClient().evaluatePosition(targetFen, depth: _analysisDepth);

    if (evalData != null && _analysisFen == targetFen && mounted) {
      setState(() {
        _analysisScoreCp = evalData['scoreCp'] as int? ?? 0;
        _analysisIsMate = evalData['isMate'] as bool? ?? false;
        _analysisMateIn = evalData['mateIn'] as int?;
        _analysisBestMove = evalData['bestMove'] as String? ?? '';
        _analysisDepth = evalData['depth'] as int? ?? 12;
        if (evalData['pv'] is List) {
          _analysisPv = List<String>.from(evalData['pv']);
        }
      });
    }
  }

  void _resetAnalysisBoard() {
    setState(() {
      _analysisFen = initialFen;
      _analysisTurn = PieceColor.white;
      _analysisLastMove = null;
      _analysisHistory.clear();
      _analysisCurrentPly = 0;
      _analysisScoreCp = 0;
      _analysisIsMate = false;
      _analysisMateIn = null;
      _analysisBestMove = '';
      _analysisPv = [];
    });
    SoundEffects().playGameStart();
    _triggerAnalysisEvaluation();
  }

  void _showLoadFenDialog() {
    final ctrl = TextEditingController(text: _analysisFen);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Load FEN / Position', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Paste FEN string...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfacePanel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.textPrimary, foregroundColor: AppColors.background),
            onPressed: () {
              final newFen = ctrl.text.trim();
              if (newFen.isNotEmpty) {
                final parts = newFen.split(' ');
                final turn = parts.length > 1 && parts[1] == 'w' ? PieceColor.white : PieceColor.black;
                setState(() {
                  _analysisFen = newFen;
                  _analysisTurn = turn;
                  _analysisLastMove = null;
                  _analysisHistory.clear();
                  _analysisCurrentPly = 0;
                });
                _triggerAnalysisEvaluation();
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Load Position'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TACTICS LAB LOGIC
  // ==========================================
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

  // ==========================================
  // MAIN BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Active Tab Content
          IndexedStack(
            index: _currentTabIndex,
            children: [
              _buildPlayTab(),
              _buildOnlineTab(),
              _buildPuzzlesTab(),
              _buildAnalysisTab(),
              _buildProfileTab(),
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

          // Optional Modal for Leaderboard (Triggered via Profile)
          if (_showLeaderboard) _buildLeaderboardOverlay(),
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
          _buildHeaderBar(),
          const SizedBox(height: 18),
          _buildRatingPills(),
          const SizedBox(height: 20),
          _buildQuickPairingGrid(),
          const SizedBox(height: 22),
          _buildBotChallengeCard(),
          const SizedBox(height: 22),
          _buildDailyWorkoutCard(),
          const SizedBox(height: 22),
          _buildPassAndPlayCard(),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    final username = _currentUser?['username'] ?? 'Guest';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
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
              ),
              child: Image.asset(
                'assets/icons/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const AppIcon(name: 'crown', size: 20, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ChessPasant',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.4),
                ),
                Text(
                  'Signed in as $username',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            setState(() => _currentTabIndex = 4); // Go to profile
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(name: 'user', size: 13, color: _currentUser != null ? AppColors.green : AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  _currentUser != null ? username : 'Sign In',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ],
            ),
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
          _ratingPill(icon: 'zap', label: 'Bullet', rating: '${_userRatings['bullet'] ?? 400}'),
          const SizedBox(width: 8),
          _ratingPill(icon: 'flame', label: 'Blitz', rating: '${_userRatings['blitz'] ?? 400}'),
          const SizedBox(width: 8),
          _ratingPill(icon: 'timer', label: 'Rapid', rating: '${_userRatings['rapid'] ?? 400}'),
          const SizedBox(width: 8),
          _ratingPill(icon: 'hourglass', label: 'Classical', rating: '${_userRatings['classical'] ?? 400}'),
          const SizedBox(width: 8),
          _ratingPill(icon: 'puzzle', label: 'Tactics', rating: '${_userRatings['puzzles'] ?? 400}'),
        ],
      ),
    );
  }

  Widget _ratingPill({required String icon, required String label, required String rating}) {
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
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5),
              ),
              Text(
                rating,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPairingGrid() {
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
                  Text('Quick Pairing', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _currentTabIndex = 1);
                },
                child: const Row(
                  children: [
                    Text('Custom Game', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    SizedBox(width: 4),
                    AppIcon(name: 'chevron-right', size: 12, color: AppColors.textMuted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            itemCount: _onlinePresets.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (ctx, idx) {
              final item = _onlinePresets[idx];
              final isPop = item['pop'] as bool;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedOnlinePreset = item;
                    _currentTabIndex = 1;
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
                            child: const Text('HOT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.background)),
                          ),
                        ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon(name: item['icon'] as String, size: 16, color: AppColors.textMuted),
                          const SizedBox(height: 4),
                          Text(
                            item['label'] as String,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                          Text(
                            item['type'] as String,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textMuted),
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
                    Text('Spar with Bot', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text('Stockfish engine from 400 to 2000 Elo', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Skill Level:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
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
                            border: Border.all(color: isSel ? AppColors.textPrimary : AppColors.border),
                          ),
                          child: Center(
                            child: Text(
                              '$lvl',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSel ? AppColors.background : AppColors.textPrimary),
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
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BotGameScreen(initialLevel: _selectedBotLevel)),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(name: 'swords', size: 16, color: AppColors.background),
                  SizedBox(width: 8),
                  Text('Start Sparring', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  AppIcon(name: 'puzzle', size: 16, color: AppColors.textPrimary),
                  SizedBox(width: 8),
                  Text('Daily Tactical Workout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfacePanel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: _dailyStatusColor)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_dailyStatusMsg, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _dailyStatusColor)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
            child: const Center(child: AppIcon(name: 'handshake', size: 22, color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pass & Play', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text('Local two-player over the board', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
              setState(() => _currentTabIndex = 3);
            },
            child: const Text('Play Over Board', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: ONLINE MATCHMAKING (FULL OPTIONS)
  // ==========================================
  Widget _buildOnlineTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 96),
        children: [
          const Text('Online Matchmaking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const Text('Compete in ranked live chess across all time controls', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 18),

          // 1. Time Control Presets Selector (All 8 Options!)
          Container(
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
                    const Text('Select Time Control', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    GestureDetector(
                      onTap: () {
                        setState(() => _isCustomMode = !_isCustomMode);
                      },
                      child: Text(
                        _isCustomMode ? 'Standard Presets' : 'Custom Time Control',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.amber),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (!_isCustomMode) ...[
                  // 8 Presets Grid
                  GridView.builder(
                    itemCount: _onlinePresets.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    itemBuilder: (ctx, i) {
                      final p = _onlinePresets[i];
                      final isSelected = _selectedOnlinePreset['label'] == p['label'];

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedOnlinePreset = p);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.textPrimary : AppColors.surfacePanel,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? AppColors.textPrimary : AppColors.border),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppIcon(
                                name: p['icon'] as String,
                                size: 16,
                                color: isSelected ? AppColors.background : AppColors.textMuted,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                p['label'] as String,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? AppColors.background : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                p['type'] as String,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? AppColors.background : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  // Custom Time Control Inputs
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfacePanel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Initial Time:', style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                            Text('$_customInitialMin min', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.amber)),
                          ],
                        ),
                        Slider(
                          value: _customInitialMin.toDouble(),
                          min: 1,
                          max: 60,
                          divisions: 59,
                          activeColor: AppColors.textPrimary,
                          inactiveColor: AppColors.border,
                          onChanged: (v) => setState(() => _customInitialMin = v.round()),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Increment:', style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                            Text('+$_customIncrementSec sec', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.amber)),
                          ],
                        ),
                        Slider(
                          value: _customIncrementSec.toDouble(),
                          min: 0,
                          max: 30,
                          divisions: 30,
                          activeColor: AppColors.textPrimary,
                          inactiveColor: AppColors.border,
                          onChanged: (v) => setState(() => _customIncrementSec = v.round()),
                        ),
                        const Divider(color: AppColors.borderSubtle, height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Rated Match', style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                            Switch(
                              value: _customRated,
                              activeTrackColor: AppColors.textPrimary,
                              onChanged: (v) => setState(() => _customRated = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Color Preference:', style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                            Row(
                              children: [
                                _colorChoiceBtn('random', 'Random'),
                                const SizedBox(width: 4),
                                _colorChoiceBtn('white', 'White'),
                                const SizedBox(width: 4),
                                _colorChoiceBtn('black', 'Black'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Queue & Pairing Action Card
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
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.textPrimary),
                          )
                        : AppIcon(name: _selectedOnlinePreset['icon'] as String, size: 28, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isSearchingMatch ? 'Searching for an opponent...' : '${_selectedOnlinePreset['label']} ${_selectedOnlinePreset['type']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  _isSearchingMatch
                      ? 'Waiting: ${_searchWaitSec}s • Tolerance: ${_getToleranceText()}'
                      : _selectedOnlinePreset['desc'] as String,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                if (_matchmakingError.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_matchmakingError, style: const TextStyle(fontSize: 11, color: AppColors.red)),
                ],
                const SizedBox(height: 16),
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
                      if (_isSearchingMatch) {
                        _cancelMatchmaking();
                      } else {
                        _startMatchmaking();
                      }
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
          const SizedBox(height: 18),

          // 3. Challenge a Friend Card
          Container(
            padding: const EdgeInsets.all(16),
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
                    Text('Direct Challenge', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Invite a friend by username or private game code', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Enter username...',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          filled: true,
                          fillColor: AppColors.surfacePanel,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        ),
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfacePanel,
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Challenge sent! Waiting for response...')),
                        );
                      },
                      child: const Text('Challenge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PUZZLES (TACTICS LAB)
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
                  Text('Tactics Lab', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  Text('Master motifs and puzzle solving', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const AppIcon(name: 'trophy', size: 14, color: AppColors.amber),
                    const SizedBox(width: 6),
                    Text('${_userRatings['puzzles'] ?? 1500} Elo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                AppIcon(name: _tacticsSolved ? 'check' : 'puzzle', size: 16, color: _tacticsSolved ? AppColors.green : AppColors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_tacticsStatus, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _tacticsSolved ? AppColors.green : AppColors.textPrimary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

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
          const SizedBox(height: 14),

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
  // TAB 3: ANALYSIS BOARD (RICH STUDIO NOIR)
  // ==========================================
  Widget _buildAnalysisTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 96),
        children: [
          // Header & Tools
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analysis Studio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  Text('Stockfish engine & PGN exploration', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const AppIcon(name: 'upload', size: 16, color: AppColors.textMuted),
                    onPressed: _showLoadFenDialog,
                    tooltip: 'Load FEN',
                  ),
                  IconButton(
                    icon: const AppIcon(name: 'rotate-ccw', size: 16, color: AppColors.textMuted),
                    onPressed: () {
                      setState(() {
                        _analysisOrientation = _analysisOrientation == PieceColor.white ? PieceColor.black : PieceColor.white;
                      });
                    },
                    tooltip: 'Flip Board',
                  ),
                  IconButton(
                    icon: const AppIcon(name: 'rotate-cw', size: 16, color: AppColors.textMuted),
                    onPressed: _resetAnalysisBoard,
                    tooltip: 'Reset Board',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Board Row with Vertical EvalBar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vertical Eval Bar
              SizedBox(
                height: 340,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: EvalBar(
                    scoreCp: _analysisScoreCp,
                    isMate: _analysisIsMate,
                    mateIn: _analysisMateIn,
                    orientation: _analysisOrientation,
                  ),
                ),
              ),

              // Interactive Chess Board
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ChessBoardWidget(
                    fen: _analysisFen,
                    orientation: _analysisOrientation,
                    turn: _analysisTurn,
                    lastMove: _analysisLastMove,
                    interactive: true,
                    onMove: _onAnalysisMove,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Engine Evaluation Card (Depth, Score, Best Move Line)
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isEngineEnabled ? AppColors.green : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Stockfish 19 Engine • Depth $_analysisDepth',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isEngineEnabled,
                      activeTrackColor: AppColors.textPrimary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) {
                        setState(() => _isEngineEnabled = v);
                        if (v) _triggerAnalysisEvaluation();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfacePanel,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _analysisIsMate && _analysisMateIn != null
                            ? 'M${_analysisMateIn!.abs()}'
                            : (_analysisScoreCp >= 0 ? '+${(_analysisScoreCp / 100.0).toStringAsFixed(2)}' : (_analysisScoreCp / 100.0).toStringAsFixed(2)),
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _analysisBestMove.isNotEmpty
                            ? 'Best: $_analysisBestMove ${_analysisPv.take(4).join(' ')}'
                            : 'Analyzing position...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Move Navigation Controls (|<, <, >, >|)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const AppIcon(name: 'chevrons-left', size: 18, color: AppColors.textPrimary),
                onPressed: () => _jumpToPly(0),
                tooltip: 'Start of game',
              ),
              IconButton(
                icon: const AppIcon(name: 'chevron-left', size: 18, color: AppColors.textPrimary),
                onPressed: () => _jumpToPly(_analysisCurrentPly - 1),
                tooltip: 'Previous move',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfacePanel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Ply $_analysisCurrentPly / ${_analysisHistory.length}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                icon: const AppIcon(name: 'chevron-right', size: 18, color: AppColors.textPrimary),
                onPressed: () => _jumpToPly(_analysisCurrentPly + 1),
                tooltip: 'Next move',
              ),
              IconButton(
                icon: const AppIcon(name: 'chevrons-right', size: 18, color: AppColors.textPrimary),
                onPressed: () => _jumpToPly(_analysisHistory.length),
                tooltip: 'Latest move',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Interactive Move History Table
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
                const Text('Game Notation (Tap move to jump)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                if (_analysisHistory.isEmpty)
                  const Text('Play moves on the board or load FEN/PGN to explore', style: TextStyle(fontSize: 12, color: AppColors.textMuted))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate((_analysisHistory.length / 2).ceil(), (turnIdx) {
                      final whitePly = turnIdx * 2;
                      final blackPly = whitePly + 1;
                      final moveNumber = turnIdx + 1;

                      final whiteMove = _analysisHistory[whitePly];
                      final blackMove = blackPly < _analysisHistory.length ? _analysisHistory[blackPly] : null;

                      final isWhiteActive = _analysisCurrentPly == whitePly + 1;
                      final isBlackActive = blackMove != null && _analysisCurrentPly == blackPly + 1;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$moveNumber. ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          // White move pill
                          GestureDetector(
                            onTap: () => _jumpToPly(whitePly + 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: isWhiteActive ? AppColors.textPrimary : AppColors.surfacePanel,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                whiteMove['san'] as String,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isWhiteActive ? AppColors.background : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Black move pill (if exists)
                          if (blackMove != null) ...[
                            GestureDetector(
                              onTap: () => _jumpToPly(blackPly + 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isBlackActive ? AppColors.textPrimary : AppColors.surfacePanel,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  blackMove['san'] as String,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isBlackActive ? AppColors.background : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
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
  // TAB 4: PROFILE & USER AUTH (WITH RANKINGS ENTRY)
  // ==========================================
  Widget _buildProfileTab() {
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
                  Text('Player Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  Text('Account status and performance stats', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
              if (_currentUser != null)
                IconButton(
                  icon: const AppIcon(name: 'log-out', size: 18, color: AppColors.red),
                  onPressed: _handleLogout,
                  tooltip: 'Sign Out',
                ),
            ],
          ),
          const SizedBox(height: 18),

          // If Logged in: Profile Header & Stats
          if (_currentUser != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.surfacePanel,
                    child: Text(
                      (_currentUser?['username'] as String? ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser?['username'] ?? 'User',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          _currentUser?['email'] ?? 'Member',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Active Player', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.green)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Real Elo Ratings Matrix
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ratings Overview', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _ratingStatTile('Bullet', 'zap', '${_userRatings['bullet'] ?? 400}')),
                      const SizedBox(width: 8),
                      Expanded(child: _ratingStatTile('Blitz', 'flame', '${_userRatings['blitz'] ?? 400}')),
                      const SizedBox(width: 8),
                      Expanded(child: _ratingStatTile('Rapid', 'timer', '${_userRatings['rapid'] ?? 400}')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _ratingStatTile('Classical', 'hourglass', '${_userRatings['classical'] ?? 400}')),
                      const SizedBox(width: 8),
                      Expanded(child: _ratingStatTile('Tactics', 'puzzle', '${_userRatings['puzzles'] ?? 400}')),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // Logged Out / Auth Form
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
                  // Toggle Login / Register
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isLoginMode = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _isLoginMode ? AppColors.surfacePanel : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: _isLoginMode ? Border.all(color: AppColors.border) : null,
                            ),
                            child: Center(
                              child: Text(
                                'Sign In',
                                style: TextStyle(fontWeight: FontWeight.bold, color: _isLoginMode ? AppColors.textPrimary : AppColors.textMuted),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isLoginMode = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_isLoginMode ? AppColors.surfacePanel : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: !_isLoginMode ? Border.all(color: AppColors.border) : null,
                            ),
                            child: Center(
                              child: Text(
                                'Create Account',
                                style: TextStyle(fontWeight: FontWeight.bold, color: !_isLoginMode ? AppColors.textPrimary : AppColors.textMuted),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _authUsernameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.surfacePanel,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                  ),
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _authEmailCtrl,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: AppColors.surfacePanel,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _authPasswordCtrl,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.surfacePanel,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                  ),
                  if (_authError.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_authError, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isAuthLoading ? null : _handleAuthSubmit,
                      child: _isAuthLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                          : Text(_isLoginMode ? 'Sign In' : 'Play Free', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Prominent Action Card: Global Leaderboard (Accessible via Profile!)
          GestureDetector(
            onTap: () {
              setState(() => _showLeaderboard = true);
              _loadLeaderboardCategory('blitz');
            },
            child: Container(
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
                    child: const Center(child: AppIcon(name: 'trophy', size: 22, color: AppColors.amber)),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Global Leaderboard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text('View real player standings and rating pools', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const AppIcon(name: 'chevron-right', size: 16, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingStatTile(String label, String icon, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfacePanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(name: icon, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _colorChoiceBtn(String code, String label) {
    final isSel = _customColorPref == code;
    return GestureDetector(
      onTap: () => setState(() => _customColorPref = code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSel ? AppColors.textPrimary : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSel ? AppColors.textPrimary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSel ? AppColors.background : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // REAL LEADERBOARD OVERLAY (ACCESSIBLE VIA PROFILE)
  // ==========================================
  Widget _buildLeaderboardOverlay() {
    final categories = [
      {'id': 'blitz', 'label': 'Blitz', 'icon': 'flame'},
      {'id': 'bullet', 'label': 'Bullet', 'icon': 'zap'},
      {'id': 'rapid', 'label': 'Rapid', 'icon': 'timer'},
      {'id': 'classical', 'label': 'Classical', 'icon': 'hourglass'},
      {'id': 'puzzles', 'label': 'Puzzles', 'icon': 'puzzle'},
    ];

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      AppIcon(name: 'trophy', size: 20, color: AppColors.amber),
                      SizedBox(width: 10),
                      Text('Global Leaderboard', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                  IconButton(
                    icon: const AppIcon(name: 'x', size: 18, color: AppColors.textMuted),
                    onPressed: () => setState(() => _showLeaderboard = false),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Categories Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((c) {
                    final isAct = _activeLeaderboardCat == c['id'];
                    return GestureDetector(
                      onTap: () => _loadLeaderboardCategory(c['id'] as String),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAct ? AppColors.textPrimary : AppColors.surfacePanel,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isAct ? AppColors.textPrimary : AppColors.border),
                        ),
                        child: Row(
                          children: [
                            AppIcon(name: c['icon'] as String, size: 13, color: isAct ? AppColors.background : AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              c['label'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isAct ? AppColors.background : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Real Leaderboard List
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: _isLeaderboardLoading
                    ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.textPrimary)))
                    : _leaderboardList.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No players ranked in this category yet.\nPlay a live match to establish the first rating!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _leaderboardList.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderSubtle),
                            itemBuilder: (ctx, idx) {
                              final p = _leaderboardList[idx] as Map<String, dynamic>;
                              final rank = idx + 1;
                              final name = p['username']?.toString() ?? 'Player';
                              final rating = p['rating']?.toString() ?? '400';
                              final games = p['gamesPlayed']?.toString() ?? '0';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: rank <= 3 ? AppColors.amber.withValues(alpha: 0.15) : AppColors.surfacePanel,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '#$rank',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: rank <= 3 ? AppColors.amber : AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                                          Text('$games games played', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfacePanel,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        '$rating ELO',
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
        ),
      ),
    );
  }
}
