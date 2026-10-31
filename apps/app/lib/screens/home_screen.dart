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
import '../chess/game_archive.dart';
import 'bot_game_screen.dart';
import 'game_screen.dart';
import 'pass_and_play_screen.dart';

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
  bool _obscurePassword = true;
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
  PieceColor _dailyPlayerColor = PieceColor.white;
  PieceColor _dailyOrientation = PieceColor.white;
  LastMoveInfo? _dailyLastMove;
  int _dailySolutionIdx = 0;
  bool _dailySolved = false;
  bool _isDailyAnimating = false;
  String? _dailyHintSquare;
  String? _dailyHintTarget;
  int _dailyHintCount = 0;
  bool _dailyIsSolutionRevealed = false;
  List<String> _dailySolutionMoves = [];
  String _dailyStatusMsg = "Today's Tactical Workout";
  Color _dailyStatusColor = AppColors.textMuted;
  int _selectedBotLevel = 2;

  // ==========================================
  // PUZZLES & TACTICS LAB STATE (PUZZLES TAB)
  // ==========================================
  String _puzzleMode = 'practice'; // 'practice', 'daily', 'weekly'
  String _puzzleCategory = 'all'; // 'all', 'mate', 'fork', 'pin', 'skewer', 'capture'
  int _puzzleTier = 0; // 0 = all, 1 = Novice, 2 = Intermediate, 3 = Advanced, 4 = Expert, 5 = Master
  List<dynamic> _puzzleWeeklyList = [];
  int _puzzleWeeklyIndex = 0;

  Map<String, dynamic>? _puzzleData;
  String _puzzleFen = initialFen;
  PieceColor _puzzleTurn = PieceColor.white;
  PieceColor _puzzlePlayerColor = PieceColor.white;
  PieceColor _puzzleOrientation = PieceColor.white;
  LastMoveInfo? _puzzleLastMove;
  int _puzzleSolutionIdx = 0;
  bool _puzzleSolved = false;
  bool _puzzleLoading = false;
  String _puzzleStatusMsg = 'Find the best tactical sequence in this position.';
  Color _puzzleStatusColor = AppColors.textPrimary;
  int? _puzzleRatingDiff;
  int _puzzleSolvedToday = 0;

  // Assistance and playback state
  String? _puzzleHintSquare;
  String? _puzzleHintTarget;
  int _puzzleHintCount = 0;
  bool _puzzleIsSolutionRevealed = false;
  List<String> _puzzleSolutionMoves = [];
  bool _puzzleIsOpponentReplying = false;
  bool _puzzleIsRetrying = false;
  bool _puzzleHasAssistance = false;

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
    _loadPuzzleTabPuzzle();
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
            final analyze = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => GameScreen(
                  gameId: gameId,
                  token: ApiClient().authToken ?? '',
                  currentUserId: _currentUser?['id']?.toString() ?? '',
                ),
              ),
            );
            if (analyze == true) {
              _loadLastPlayedGameIntoAnalysis();
            }
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
        ApiClient().getPuzzleSolution(p['id'].toString()).then((solRes) {
          if (solRes != null && solRes['solution'] != null) {
            if (mounted) {
              setState(() {
                _dailyPuzzle?['solution'] = solRes['solution'];
              });
            }
          }
        });
      }

      setState(() {
        _dailyPuzzle = p;
        _dailyFen = fen;
        _dailyTurn = turn;
        _dailyPlayerColor = turn;
        _dailyOrientation = turn; // Fixed: Orientation stays fixed, never flips on wrong move!
        _dailyLastMove = null;
        _dailySolutionIdx = 0;
        _dailySolved = false;
        _dailyHintSquare = null;
        _dailyHintTarget = null;
        _dailyHintCount = 0;
        _dailyIsSolutionRevealed = false;
        _dailySolutionMoves = [];
        _dailyStatusMsg = "Today's Tactical Workout";
        _dailyStatusColor = AppColors.textMuted;
      });
    }
  }

  void _onDailyMove(String from, String to, String? promo) {
    if (_dailySolved || _isDailyAnimating || _dailyPuzzle == null || _dailyIsSolutionRevealed) return;
    if (_dailyTurn != _dailyPlayerColor) return;

    final uci = '$from$to${promo?.toLowerCase() ?? ''}';
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
          _dailyHintSquare = null;
          _dailyHintTarget = null;
          _dailyHintCount = 0;
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
            if (!mounted) return;
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
          if (!mounted) return;
          setState(() {
            _dailyFen = prevFen;
            _dailyTurn = prevTurn;
            _dailyLastMove = prevLast;
            _dailyHintSquare = null;
            _dailyHintTarget = null;
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

  Future<void> _requestDailyHint() async {
    if (_dailyPuzzle == null || _dailySolved || _dailyIsSolutionRevealed) return;
    String? fromSq;
    String? toSq;

    final solList = _dailyPuzzle!['solution'] as List?;
    if (solList != null && _dailySolutionIdx < solList.length) {
      final uci = solList[_dailySolutionIdx].toString();
      if (uci.length >= 4) {
        fromSq = uci.substring(0, 2).toLowerCase();
        toSq = uci.substring(2, 4).toLowerCase();
      }
    }

    if (fromSq == null || toSq == null) {
      final hint = await ApiClient().getPuzzleHint(
        _dailyPuzzle!['id'].toString(),
        plyIndex: _dailySolutionIdx,
      );
      if (hint != null && hint['from'] != null) {
        fromSq = hint['from'].toString().toLowerCase();
        toSq = hint['to']?.toString().toLowerCase();
      }
    }

    if (!mounted) return;

    if (fromSq != null) {
      if (_dailyHintCount == 0) {
        setState(() {
          _dailyHintSquare = fromSq;
          _dailyHintTarget = null;
          _dailyStatusMsg = 'Tactical Hint: Focus on the piece on ${fromSq!.toUpperCase()}!';
          _dailyStatusColor = AppColors.textPrimary;
          _dailyHintCount = 1;
        });
      } else {
        setState(() {
          _dailyHintSquare = fromSq;
          _dailyHintTarget = toSq;
          _dailyStatusMsg = toSq != null
              ? 'Direct Hint: Move piece to ${toSq.toUpperCase()}!'
              : 'Direct Hint: Focus on ${fromSq!.toUpperCase()}!';
          _dailyStatusColor = AppColors.textPrimary;
        });
      }
    } else {
      setState(() {
        _dailyStatusMsg = 'No hint available for this position.';
      });
    }
  }

  Future<void> _revealDailySolution() async {
    if (_dailyPuzzle == null) return;
    final initialFenStr = _dailyPuzzle!['fen'] as String;
    final parts = initialFenStr.split(' ');
    final turn = parts.length > 1 && parts[1] == 'w' ? PieceColor.white : PieceColor.black;

    setState(() {
      _dailyIsSolutionRevealed = true;
      _isDailyAnimating = false;
      _dailyFen = initialFenStr;
      _dailyTurn = turn;
      _dailyPlayerColor = turn;
      _dailyOrientation = turn;
      _dailyLastMove = null;
      _dailyHintSquare = null;
      _dailyHintTarget = null;
      _dailyHintCount = 0;
      _dailySolutionIdx = 0;
      _dailyStatusMsg = 'Solution revealed. Playing through winning moves...';
      _dailyStatusColor = AppColors.textPrimary;
    });

    List<String> moves = [];
    if (_dailyPuzzle!['solution'] != null && (_dailyPuzzle!['solution'] as List).isNotEmpty) {
      moves = List<String>.from(_dailyPuzzle!['solution'] as List);
    } else {
      final sol = await ApiClient().getPuzzleSolution(_dailyPuzzle!['id'].toString());
      if (sol != null && sol['solution'] != null) {
        moves = List<String>.from(sol['solution'] as List);
        _dailyPuzzle!['solution'] = moves;
      }
    }

    if (!mounted || !_dailyIsSolutionRevealed) return;

    if (moves.isEmpty) {
      setState(() {
        _dailyIsSolutionRevealed = false;
        _dailyStatusMsg = 'Unable to fetch solution.';
        _dailyStatusColor = AppColors.red;
      });
      return;
    }

    _dailySolutionMoves = moves;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _dailyIsSolutionRevealed) {
        _playDailySolutionStep(0);
      }
    });
  }

  void _playDailySolutionStep(int idx) {
    if (!mounted || !_dailyIsSolutionRevealed) return;
    if (idx >= _dailySolutionMoves.length) {
      setState(() {
        _dailyStatusMsg = 'Solution complete! Review the tactical pattern.';
        _dailyStatusColor = AppColors.green;
      });
      return;
    }

    final moveUci = _dailySolutionMoves[idx];
    final from = moveUci.substring(0, 2);
    final to = moveUci.substring(2, 4);
    final promo = moveUci.length > 4 ? moveUci.substring(4, 5) : null;

    final res = ChessEngine.executeMove(_dailyFen, from, to, promotion: promo);
    if (res != null && res['valid'] == true) {
      final san = res['san'] as String;
      final isCap = res['isCapture'] as bool;
      SoundEffects().playMoveSound(san: san, isCapture: isCap);
      final isMate = res['isCheckmate'] == true;
      setState(() {
        _dailyFen = res['newFen'] as String;
        _dailyTurn = res['turn'] as PieceColor;
        _dailyLastMove = LastMoveInfo(from: from, to: to, san: san, isCapture: isCap);
        if (idx + 1 >= _dailySolutionMoves.length) {
          _dailyStatusMsg = isMate
              ? 'Solution complete: Decisive checkmate delivered!'
              : 'Solution complete! Review the tactical pattern.';
          _dailyStatusColor = AppColors.green;
        }
      });
    }

    if (idx + 1 < _dailySolutionMoves.length) {
      Future.delayed(const Duration(milliseconds: 600), () {
        _playDailySolutionStep(idx + 1);
      });
    }
  }

  void _resetDailyPuzzle() {
    if (_dailyPuzzle == null) return;
    final fen = _dailyPuzzle!['fen'] as String;
    final parts = fen.split(' ');
    final turn = parts.length > 1 && parts[1] == 'w' ? PieceColor.white : PieceColor.black;
    setState(() {
      _dailyFen = fen;
      _dailyTurn = turn;
      _dailyPlayerColor = turn;
      _dailyOrientation = turn;
      _dailySolutionIdx = 0;
      _dailySolved = false;
      _isDailyAnimating = false;
      _dailyIsSolutionRevealed = false;
      _dailyHintSquare = null;
      _dailyHintTarget = null;
      _dailyHintCount = 0;
      _dailyLastMove = null;
      _dailyStatusMsg = "Position reset. Find the optimal combination!";
      _dailyStatusColor = AppColors.textPrimary;
    });
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

  void _loadLastPlayedGameIntoAnalysis([SavedGameRecord? record]) {
    final game = record ?? GameArchive.lastPlayedGame;
    if (game == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved game available yet. Complete a match first!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _currentTabIndex = 3;
      _analysisHistory.clear();
      _analysisHistory.addAll(game.moves);

      if (_analysisHistory.isNotEmpty) {
        _jumpToPly(_analysisHistory.length);
      } else {
        _analysisFen = game.finalFen.isNotEmpty ? game.finalFen : initialFen;
        final parts = _analysisFen.split(' ');
        _analysisTurn = parts.length > 1 && parts[1] == 'w' ? PieceColor.white : PieceColor.black;
        _analysisCurrentPly = 0;
        _analysisLastMove = null;
        _triggerAnalysisEvaluation();
      }

      final myName = _currentUser?['username']?.toString().toLowerCase();
      if (myName != null && game.blackPlayer.toLowerCase().contains(myName)) {
        _analysisOrientation = PieceColor.black;
      } else {
        _analysisOrientation = PieceColor.white;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded ${game.title} into Analysis Studio'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _loadPgnIntoAnalysis(String pgn, {String? whiteName, String? blackName, String? title}) {
    final moves = ChessEngine.parsePgn(pgn);
    if (moves.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not parse any valid moves from PGN')),
      );
      return;
    }

    setState(() {
      _currentTabIndex = 3;
      _analysisHistory.clear();
      _analysisHistory.addAll(moves);
      _jumpToPly(_analysisHistory.length);

      final myName = _currentUser?['username']?.toString().toLowerCase();
      if (myName != null && blackName != null && blackName.toLowerCase().contains(myName)) {
        _analysisOrientation = PieceColor.black;
      } else {
        _analysisOrientation = PieceColor.white;
      }
    });

    GameArchive.saveGame(SavedGameRecord(
      title: title ?? 'Imported PGN',
      mode: 'PGN Review',
      date: DateTime.now().toLocal().toString().substring(0, 16),
      whitePlayer: whiteName ?? 'White',
      blackPlayer: blackName ?? 'Black',
      result: '*',
      finalFen: moves.last['fen'] as String,
      moves: moves,
      pgn: pgn,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded ${moves.length} moves into Analysis Studio')),
    );
  }

  void _showGameExplorerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        int selectedTab = 0; // 0: Recent/Saved, 1: Account Games, 2: Import PGN/FEN
        final pgnCtrl = TextEditingController();
        bool loadingGameId = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
              ),
              child: Column(
                children: [
                  // Modal handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            AppIcon(name: 'download', size: 20, color: AppColors.textPrimary),
                            SizedBox(width: 10),
                            Text(
                              'Game Explorer',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const AppIcon(name: 'x', size: 18, color: AppColors.textMuted),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Tabs
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfacePanel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedTab == 0 ? AppColors.textPrimary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'Recent Saved (${GameArchive.recentGames.length})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selectedTab == 0 ? AppColors.background : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedTab == 1 ? AppColors.textPrimary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'My Account',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selectedTab == 1 ? AppColors.background : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedTab = 2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedTab == 2 ? AppColors.textPrimary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'Import PGN',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selectedTab == 2 ? AppColors.background : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: AppColors.borderSubtle, height: 16),

                  // Tab Views
                  Expanded(
                    child: selectedTab == 0
                        ? _buildRecentSavedTab(ctx)
                        : selectedTab == 1
                            ? _buildAccountGamesTab(ctx, loadingGameId, (loading) {
                                setModalState(() => loadingGameId = loading);
                              })
                            : _buildImportPgnTab(ctx, pgnCtrl),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentSavedTab(BuildContext modalCtx) {
    final recent = GameArchive.recentGames;
    if (recent.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.surfacePanel,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: AppIcon(name: 'clock', size: 24, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No saved matches yet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Play a match in Online, Pass & Play, or Bot sparring to analyze it here anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: recent.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final g = recent[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfacePanel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            g.mode,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(g.date, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${g.whitePlayer} vs ${g.blackPlayer}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${g.result} • ${g.moves.length} moves played',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(modalCtx).pop();
                  _loadLastPlayedGameIntoAnalysis(g);
                },
                child: const Text('Analyze', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountGamesTab(BuildContext modalCtx, bool loading, Function(bool) setLoading) {
    if (_currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(name: 'user', size: 36, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text('Account Not Signed In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('Sign in to view and analyze your server match history.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.background,
                ),
                onPressed: () {
                  Navigator.of(modalCtx).pop();
                  setState(() => _currentTabIndex = 4); // Profile / Auth tab
                },
                child: const Text('Go to Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    final userId = _currentUser?['id']?.toString();
    return FutureBuilder<List<dynamic>>(
      future: ApiClient().listGames(userId: userId, limit: 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || loading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.textPrimary));
        }

        final games = snapshot.data ?? [];
        if (games.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No server games found for this account.\nPlay a live match to see it listed here!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: games.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final gm = games[idx] as Map<String, dynamic>;
            final gid = gm['id']?.toString() ?? '';
            final whiteUser = gm['white'] is Map ? gm['white']['username']?.toString() : 'White';
            final blackUser = gm['black'] is Map ? gm['black']['username']?.toString() : 'Black';
            final timeControl = '${(gm['initialTime'] ?? 600) ~/ 60}+${gm['increment'] ?? 0}';
            final result = gm['result']?.toString() ?? gm['status']?.toString() ?? '*';
            final date = gm['createdAt']?.toString().split('T').first ?? '';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfacePanel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                timeControl,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(date, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$whiteUser vs $blackUser',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Result: $result',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      setLoading(true);
                      try {
                        final pgn = await ApiClient().getGamePgn(gid);
                        if (pgn != null && pgn.isNotEmpty) {
                          if (modalCtx.mounted) {
                            Navigator.of(modalCtx).pop();
                          }
                          _loadPgnIntoAnalysis(
                            pgn,
                            whiteName: whiteUser,
                            blackName: blackUser,
                            title: '$whiteUser vs $blackUser',
                          );
                        } else {
                          // Try getting game moves directly
                          final gameData = await ApiClient().getGame(gid);
                          final movesList = gameData['moves'] as List?;
                          if (movesList != null && movesList.isNotEmpty) {
                            // Replay moves
                            final pgnMoves = movesList.map((m) => m['san']?.toString() ?? '').where((s) => s.isNotEmpty).join(' ');
                            if (modalCtx.mounted) {
                              Navigator.of(modalCtx).pop();
                            }
                            _loadPgnIntoAnalysis(
                              pgnMoves,
                              whiteName: whiteUser,
                              blackName: blackUser,
                              title: '$whiteUser vs $blackUser',
                            );
                          } else {
                            setLoading(false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No recorded moves found for this game')),
                              );
                            }
                          }
                        }
                      } catch (e) {
                        setLoading(false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to load game: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Analyze', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImportPgnTab(BuildContext modalCtx, TextEditingController pgnCtrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Paste PGN or Move Notation',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Paste standard PGN format with headers, or raw SAN move sequence (e.g., "1. e4 e5 2. Nf3 Nc6").',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TextField(
              controller: pgnCtrl,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '[Event "Casual Game"]\n1. e4 e5 2. Nf3 Nc6 3. Bb5...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfacePanel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      pgnCtrl.text = data!.text!;
                    }
                  },
                  child: const Text('Paste Clipboard'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final text = pgnCtrl.text.trim();
                    if (text.isNotEmpty) {
                      Navigator.of(modalCtx).pop();
                      _loadPgnIntoAnalysis(text);
                    }
                  },
                  child: const Text('Load into Studio', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  Future<void> _loadPuzzleTabPuzzle({String? overrideMode}) async {
    final mode = overrideMode ?? _puzzleMode;
    setState(() {
      _puzzleMode = mode;
      _puzzleLoading = true;
      _puzzleStatusMsg = mode == 'daily'
          ? "Today's Daily Challenge. Find the master combination!"
          : mode == 'weekly'
              ? 'Weekly Challenge ${_puzzleWeeklyIndex + 1} of ${_puzzleWeeklyList.isNotEmpty ? _puzzleWeeklyList.length : 7}. Calculate precisely!'
              : 'Find the best tactical sequence in this position.';
      _puzzleStatusColor = AppColors.textPrimary;
      _puzzleSolutionIdx = 0;
      _puzzleSolved = false;
      _puzzleLastMove = null;
      _puzzleRatingDiff = null;
      _puzzleIsRetrying = false;
      _puzzleHasAssistance = false;
      _puzzleHintSquare = null;
      _puzzleHintTarget = null;
      _puzzleHintCount = 0;
      _puzzleIsSolutionRevealed = false;
      _puzzleSolutionMoves = [];
      _puzzleIsOpponentReplying = false;
    });

    try {
      Map<String, dynamic>? p;
      if (mode == 'daily') {
        p = await ApiClient().getDailyPuzzle();
      } else if (mode == 'weekly') {
        if (_puzzleWeeklyList.isEmpty) {
          _puzzleWeeklyList = await ApiClient().getWeeklyPuzzles();
        }
        if (_puzzleWeeklyList.isNotEmpty) {
          final item = _puzzleWeeklyList[_puzzleWeeklyIndex % _puzzleWeeklyList.length];
          p = Map<String, dynamic>.from(item as Map);
        } else {
          p = await ApiClient().getRandomPuzzle();
        }
      } else {
        p = await ApiClient().getRandomPuzzle(
          category: _puzzleCategory != 'all' ? _puzzleCategory : null,
          tier: _puzzleTier > 0 ? _puzzleTier : null,
        );
      }

      if (p != null && p['fen'] != null) {
        final fen = p['fen'] as String;
        final parts = fen.split(' ');
        final turn = parts.length > 1 && parts[1] == 'w' ? PieceColor.white : PieceColor.black;

        // Prefetch solution if not already present
        if (p['solution'] == null || (p['solution'] as List).isEmpty) {
          ApiClient().getPuzzleSolution(p['id'].toString()).then((solRes) {
            if (solRes != null && solRes['solution'] != null && _puzzleData?['id'] == p?['id']) {
              setState(() {
                _puzzleData?['solution'] = solRes['solution'];
              });
            }
          });
        }

        setState(() {
          _puzzleData = p;
          _puzzleFen = fen;
          _puzzleTurn = turn;
          _puzzlePlayerColor = turn;
          _puzzleOrientation = turn;
        });
      } else {
        setState(() {
          _puzzleStatusMsg = 'Failed to load puzzle. Tap Next to retry.';
          _puzzleStatusColor = AppColors.red;
        });
      }
    } catch (e) {
      setState(() {
        _puzzleStatusMsg = 'Error fetching tactical position.';
        _puzzleStatusColor = AppColors.red;
      });
    } finally {
      setState(() => _puzzleLoading = false);
    }
  }

  Future<void> _onPuzzleMove(String from, String to, String? promo) async {
    if (_puzzleData == null ||
        _puzzleSolved ||
        _puzzleIsSolutionRevealed ||
        _puzzleIsOpponentReplying) {
      return;
    }
    if (_puzzleTurn != _puzzlePlayerColor) return;

    final uci = '$from$to${promo?.toLowerCase() ?? ''}';

    // Execute move locally first to ensure chess legality
    final localRes = ChessEngine.executeMove(_puzzleFen, from, to, promotion: promo);
    if (localRes == null || localRes['valid'] != true) {
      SoundEffects().playIllegal();
      return;
    }

    final san = localRes['san'] as String;
    final isCap = localRes['isCapture'] as bool;
    SoundEffects().playMoveSound(san: san, isCapture: isCap);

    setState(() {
      _puzzleFen = localRes['newFen'] as String;
      _puzzleTurn = localRes['turn'] as PieceColor;
      _puzzleLastMove = LastMoveInfo(from: from, to: to, san: san, isCapture: isCap);
      _puzzleHintSquare = null;
      _puzzleHintTarget = null;
    });

    final solutionList = _puzzleData!['solution'] as List?;
    if (solutionList != null && solutionList.isNotEmpty) {
      final expectedMove = (_puzzleSolutionIdx < solutionList.length)
          ? (solutionList[_puzzleSolutionIdx] as String)
          : '';

      final isCorrect = expectedMove.isNotEmpty &&
          (expectedMove.toLowerCase() == uci.toLowerCase() ||
              expectedMove.toLowerCase().startsWith(uci.toLowerCase()));

      if (isCorrect) {
        final isFinished = _puzzleSolutionIdx + 1 >= solutionList.length;
        if (isFinished) {
          SoundEffects().playGameEnd();
          setState(() {
            _puzzleSolved = true;
            _puzzleStatusMsg = _puzzleHasAssistance || _puzzleIsRetrying
                ? 'Puzzle solved with practice/assistance!'
                : 'Brilliant! Tactical combination completed successfully.';
            _puzzleStatusColor = AppColors.green;
            _puzzleSolvedToday++;
          });

          // Report solve to backend
          ApiClient().solvePuzzle(
            _puzzleData!['id'].toString(),
            move: uci,
            plyIndex: _puzzleSolutionIdx,
            isRetry: _puzzleIsRetrying,
            hasAssistance: _puzzleHasAssistance,
          ).then((check) {
            if (check != null && !_puzzleIsRetrying && !_puzzleHasAssistance) {
              if (check['diff'] != null) {
                setState(() {
                  _puzzleRatingDiff = check['diff'] is num ? (check['diff'] as num).toInt() : null;
                  if (check['newRating'] != null) {
                    _userRatings['puzzles'] = check['newRating'];
                  }
                });
              }
            }
          });
        } else {
          // Play opponent response
          final nextPly = _puzzleSolutionIdx + 1;
          final replyUci = solutionList[nextPly] as String;
          setState(() {
            _puzzleSolutionIdx = nextPly + 1;
            _puzzleStatusMsg = 'Best move found! Continue the tactical sequence...';
            _puzzleStatusColor = AppColors.textPrimary;
            _puzzleIsOpponentReplying = true;
          });

          // Report intermediate solve
          ApiClient().solvePuzzle(
            _puzzleData!['id'].toString(),
            move: uci,
            plyIndex: _puzzleSolutionIdx - 2,
            isRetry: _puzzleIsRetrying,
            hasAssistance: _puzzleHasAssistance,
          );

          Future.delayed(const Duration(milliseconds: 350), () {
            if (!mounted || _puzzleData == null) return;
            final replyFrom = replyUci.substring(0, 2);
            final replyTo = replyUci.substring(2, 4);
            final replyPromo = replyUci.length > 4 ? replyUci.substring(4, 5) : null;
            final replyRes = ChessEngine.executeMove(_puzzleFen, replyFrom, replyTo, promotion: replyPromo);
            if (replyRes != null && replyRes['valid'] == true) {
              final rSan = replyRes['san'] as String;
              final rCap = replyRes['isCapture'] as bool;
              SoundEffects().playMoveSound(san: rSan, isCapture: rCap);
              setState(() {
                _puzzleFen = replyRes['newFen'] as String;
                _puzzleTurn = replyRes['turn'] as PieceColor;
                _puzzleLastMove = LastMoveInfo(from: replyFrom, to: replyTo, san: rSan, isCapture: rCap);
                _puzzleIsOpponentReplying = false;
              });
            }
          });
        }
      } else {
        // Wrong move
        SoundEffects().playIllegal();
        setState(() {
          _puzzleStatusMsg = 'Not the optimal move. Resetting position...';
          _puzzleStatusColor = AppColors.red;
          _puzzleIsRetrying = true;
        });

        ApiClient().solvePuzzle(
          _puzzleData!['id'].toString(),
          move: uci,
          plyIndex: _puzzleSolutionIdx,
          isRetry: _puzzleIsRetrying,
          hasAssistance: _puzzleHasAssistance,
        ).then((check) {
          if (check != null && check['diff'] != null && !_puzzleHasAssistance) {
            setState(() {
              _puzzleRatingDiff = check['diff'] is num ? (check['diff'] as num).toInt() : null;
              if (check['newRating'] != null) {
                _userRatings['puzzles'] = check['newRating'];
              }
            });
          }
        });

        Future.delayed(const Duration(milliseconds: 850), () {
          if (!mounted || _puzzleData == null || _puzzleSolved) return;
          final fen = _puzzleData!['fen'] as String;
          final parts = fen.split(' ');
          final turn = parts.length > 1 && parts[1] == 'w' ? PieceColor.white : PieceColor.black;
          setState(() {
            _puzzleFen = fen;
            _puzzleTurn = turn;
            _puzzlePlayerColor = turn;
            _puzzleLastMove = null;
            _puzzleHintSquare = null;
            _puzzleHintTarget = null;
            _puzzleIsOpponentReplying = false;
            _puzzleStatusMsg = 'Try another tactical combination!';
            _puzzleStatusColor = AppColors.textPrimary;
          });
        });
      }
      return;
    }

    // Fallback: solve via API directly if solution not cached
    try {
      final check = await ApiClient().solvePuzzle(
        _puzzleData!['id'].toString(),
        move: uci,
        plyIndex: _puzzleSolutionIdx,
        isRetry: _puzzleIsRetrying,
        hasAssistance: _puzzleHasAssistance,
      );

      if (check != null && check['correct'] == true) {
        if (check['finished'] == true) {
          SoundEffects().playGameEnd();
          setState(() {
            _puzzleSolved = true;
            _puzzleStatusMsg = 'Brilliant! Tactical combination completed successfully.';
            _puzzleStatusColor = AppColors.green;
            _puzzleSolvedToday++;
            if (check['diff'] != null) {
              _puzzleRatingDiff = check['diff'] is num ? (check['diff'] as num).toInt() : null;
            }
            if (check['newRating'] != null) {
              _userRatings['puzzles'] = check['newRating'];
            }
          });
        } else {
          setState(() {
            _puzzleSolutionIdx += 2;
            _puzzleStatusMsg = 'Best move found! Continue the tactical sequence...';
            _puzzleStatusColor = AppColors.textPrimary;
          });
          if (check['replyMove'] != null) {
            final replyUci = check['replyMove'] as String;
            setState(() => _puzzleIsOpponentReplying = true);
            Future.delayed(const Duration(milliseconds: 350), () {
              if (!mounted) return;
              final replyFrom = replyUci.substring(0, 2);
              final replyTo = replyUci.substring(2, 4);
              final replyPromo = replyUci.length > 4 ? replyUci.substring(4, 5) : null;
              final replyRes = ChessEngine.executeMove(_puzzleFen, replyFrom, replyTo, promotion: replyPromo);
              if (replyRes != null && replyRes['valid'] == true) {
                final rSan = replyRes['san'] as String;
                final rCap = replyRes['isCapture'] as bool;
                SoundEffects().playMoveSound(san: rSan, isCapture: rCap);
                setState(() {
                  _puzzleFen = replyRes['newFen'] as String;
                  _puzzleTurn = replyRes['turn'] as PieceColor;
                  _puzzleLastMove = LastMoveInfo(from: replyFrom, to: replyTo, san: rSan, isCapture: rCap);
                  _puzzleIsOpponentReplying = false;
                });
              }
            });
          }
        }
      } else {
        SoundEffects().playIllegal();
        setState(() {
          _puzzleStatusMsg = 'Not the optimal move. Resetting position...';
          _puzzleStatusColor = AppColors.red;
          _puzzleIsRetrying = true;
        });
        Future.delayed(const Duration(milliseconds: 850), () {
          if (!mounted || _puzzleData == null) return;
          final fen = _puzzleData!['fen'] as String;
          final parts = fen.split(' ');
          final turn = parts.length > 1 && parts[1] == 'w' ? PieceColor.white : PieceColor.black;
          setState(() {
            _puzzleFen = fen;
            _puzzleTurn = turn;
            _puzzlePlayerColor = turn;
            _puzzleLastMove = null;
            _puzzleHintSquare = null;
            _puzzleHintTarget = null;
            _puzzleStatusMsg = 'Try another tactical combination!';
            _puzzleStatusColor = AppColors.textPrimary;
          });
        });
      }
    } catch (_) {}
  }

  Future<void> _requestPuzzleHint() async {
    if (_puzzleData == null || _puzzleSolved || _puzzleIsSolutionRevealed) return;
    setState(() => _puzzleHasAssistance = true);

    String? fromSq;
    String? toSq;

    // 1. Try local solution first for instant 0ms latency
    final solList = _puzzleData!['solution'] as List?;
    if (solList != null && _puzzleSolutionIdx < solList.length) {
      final uci = solList[_puzzleSolutionIdx].toString();
      if (uci.length >= 4) {
        fromSq = uci.substring(0, 2).toLowerCase();
        toSq = uci.substring(2, 4).toLowerCase();
      }
    }

    // 2. Fallback to API if not in local cache
    if (fromSq == null || toSq == null) {
      final hint = await ApiClient().getPuzzleHint(
        _puzzleData!['id'].toString(),
        plyIndex: _puzzleSolutionIdx,
      );
      if (hint != null && hint['from'] != null) {
        fromSq = hint['from'].toString().toLowerCase();
        toSq = hint['to']?.toString().toLowerCase();
      } else {
        final solRes = await ApiClient().getPuzzleSolution(_puzzleData!['id'].toString());
        if (solRes != null && solRes['solution'] != null) {
          final list = solRes['solution'] as List;
          _puzzleData!['solution'] = list;
          if (_puzzleSolutionIdx < list.length) {
            final uci = list[_puzzleSolutionIdx].toString();
            if (uci.length >= 4) {
              fromSq = uci.substring(0, 2).toLowerCase();
              toSq = uci.substring(2, 4).toLowerCase();
            }
          }
        }
      }
    }

    if (!mounted) return;

    if (fromSq != null) {
      if (_puzzleHintCount == 0) {
        // Level 1: Piece starting square
        setState(() {
          _puzzleHintSquare = fromSq;
          _puzzleHintTarget = null;
          _puzzleStatusMsg = 'Tactical Hint: Focus on the piece on ${fromSq!.toUpperCase()}!';
          _puzzleStatusColor = AppColors.textPrimary;
          _puzzleHintCount = 1;
        });
      } else {
        // Level 2: Target destination square
        setState(() {
          _puzzleHintSquare = fromSq;
          _puzzleHintTarget = toSq;
          _puzzleStatusMsg = toSq != null
              ? 'Direct Hint: Move piece to ${toSq.toUpperCase()}!'
              : 'Direct Hint: Focus on ${fromSq!.toUpperCase()}!';
          _puzzleStatusColor = AppColors.textPrimary;
        });
      }
    } else {
      setState(() {
        _puzzleStatusMsg = 'Could not retrieve hint for this position.';
      });
    }
  }

  Future<void> _revealPuzzleSolution() async {
    if (_puzzleData == null) return;
    final initialFenStr = _puzzleData!['fen'] as String;
    final parts = initialFenStr.split(' ');
    final turn = parts.length > 1 && parts[1] == 'w' ? PieceColor.white : PieceColor.black;

    setState(() {
      _puzzleHasAssistance = true;
      _puzzleIsSolutionRevealed = true;
      _puzzleIsOpponentReplying = false;
      _puzzleFen = initialFenStr;
      _puzzleTurn = turn;
      _puzzlePlayerColor = turn;
      _puzzleOrientation = turn;
      _puzzleLastMove = null;
      _puzzleHintSquare = null;
      _puzzleHintTarget = null;
      _puzzleHintCount = 0;
      _puzzleSolutionIdx = 0;
      _puzzleStatusMsg = 'Solution revealed. Playing through winning moves...';
      _puzzleStatusColor = AppColors.textPrimary;
    });

    List<String> moves = [];
    if (_puzzleData!['solution'] != null && (_puzzleData!['solution'] as List).isNotEmpty) {
      moves = List<String>.from(_puzzleData!['solution'] as List);
    } else {
      final sol = await ApiClient().getPuzzleSolution(_puzzleData!['id'].toString());
      if (sol != null && sol['solution'] != null) {
        moves = List<String>.from(sol['solution'] as List);
        _puzzleData!['solution'] = moves;
      }
    }

    if (!mounted || !_puzzleIsSolutionRevealed) return;

    if (moves.isEmpty) {
      setState(() {
        _puzzleIsSolutionRevealed = false;
        _puzzleStatusMsg = 'Unable to fetch solution for this puzzle.';
        _puzzleStatusColor = AppColors.red;
      });
      return;
    }

    _puzzleSolutionMoves = moves;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _puzzleIsSolutionRevealed) {
        _playSolutionStep(0);
      }
    });
  }

  void _playSolutionStep(int idx) {
    if (!mounted || !_puzzleIsSolutionRevealed) return;
    if (idx >= _puzzleSolutionMoves.length) {
      setState(() {
        _puzzleStatusMsg = 'Solution complete! Review the tactical pattern.';
        _puzzleStatusColor = AppColors.green;
      });
      return;
    }

    final moveUci = _puzzleSolutionMoves[idx];
    final from = moveUci.substring(0, 2);
    final to = moveUci.substring(2, 4);
    final promo = moveUci.length > 4 ? moveUci.substring(4, 5) : null;

    final res = ChessEngine.executeMove(_puzzleFen, from, to, promotion: promo);
    if (res != null && res['valid'] == true) {
      final san = res['san'] as String;
      final isCap = res['isCapture'] as bool;
      SoundEffects().playMoveSound(san: san, isCapture: isCap);
      final isMate = res['isCheckmate'] == true;
      setState(() {
        _puzzleFen = res['newFen'] as String;
        _puzzleTurn = res['turn'] as PieceColor;
        _puzzleLastMove = LastMoveInfo(from: from, to: to, san: san, isCapture: isCap);
        if (idx + 1 >= _puzzleSolutionMoves.length) {
          _puzzleStatusMsg = isMate
              ? 'Solution complete: Decisive checkmate delivered!'
              : 'Solution complete! Review the tactical pattern.';
          _puzzleStatusColor = AppColors.green;
        }
      });
    }

    if (idx + 1 < _puzzleSolutionMoves.length) {
      Future.delayed(const Duration(milliseconds: 600), () {
        _playSolutionStep(idx + 1);
      });
    }
  }

  void _resetPuzzle() {
    if (_puzzleData == null) return;
    final fen = _puzzleData!['fen'] as String;
    final parts = fen.split(' ');
    final turn = parts.length > 1 && parts[1] == 'w' ? PieceColor.white : PieceColor.black;
    setState(() {
      _puzzleFen = fen;
      _puzzleTurn = turn;
      _puzzlePlayerColor = turn;
      _puzzleOrientation = turn;
      _puzzleSolutionIdx = 0;
      _puzzleSolved = false;
      _puzzleIsRetrying = true;
      _puzzleHintSquare = null;
      _puzzleHintTarget = null;
      _puzzleHintCount = 0;
      _puzzleLastMove = null;
      _puzzleIsSolutionRevealed = false;
      _puzzleIsOpponentReplying = false;
      _puzzleStatusMsg = 'Position reset. Find the optimal tactical combination!';
      _puzzleStatusColor = AppColors.textPrimary;
    });
  }

  void _nextPuzzle() {
    if (_puzzleMode == 'weekly' && _puzzleWeeklyList.isNotEmpty) {
      _puzzleWeeklyIndex = (_puzzleWeeklyIndex + 1) % _puzzleWeeklyList.length;
    }
    _loadPuzzleTabPuzzle();
  }

  void _flipPuzzleBoard() {
    setState(() {
      _puzzleOrientation = _puzzleOrientation == PieceColor.white ? PieceColor.black : PieceColor.white;
    });
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
              onPressed: () async {
                final analyze = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => BotGameScreen(initialLevel: _selectedBotLevel)),
                );
                if (analyze == true) {
                  _loadLastPlayedGameIntoAnalysis();
                }
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
              orientation: _dailyOrientation,
              turn: _dailyTurn,
              playerColor: _dailyPlayerColor,
              lastMove: _dailyLastMove,
              hintSquare: _dailyHintSquare,
              hintTarget: _dailyHintTarget,
              interactive: !_dailySolved && !_isDailyAnimating && !_dailyIsSolutionRevealed,
              onMove: _onDailyMove,
            ),
          ),
          const SizedBox(height: 12),
          if (_dailySolved || _dailyIsSolutionRevealed) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: AppColors.background,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => setState(() => _currentTabIndex = 1),
                      icon: const AppIcon(name: 'puzzle', size: 14, color: AppColors.background),
                      label: const Text('More Puzzles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _resetDailyPuzzle,
                  icon: const AppIcon(name: 'rotate-ccw', size: 16, color: AppColors.textPrimary),
                  tooltip: 'Retry Puzzle',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfacePanel,
                    minimumSize: const Size(40, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _analysisFen = _dailyFen;
                      _currentTabIndex = 3;
                    });
                    _evaluateCurrentAnalysisPosition();
                  },
                  icon: const AppIcon(name: 'search', size: 16, color: AppColors.textPrimary),
                  tooltip: 'Analyze',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfacePanel,
                    minimumSize: const Size(40, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfacePanel,
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _dailyIsSolutionRevealed ? null : _requestDailyHint,
                      icon: const AppIcon(name: 'sparkles', size: 13, color: AppColors.textPrimary),
                      label: Text(
                        _dailyHintCount == 0 ? 'Hint' : 'Target',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfacePanel,
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _dailyIsSolutionRevealed ? null : _revealDailySolution,
                      icon: const AppIcon(name: 'eye', size: 13, color: AppColors.textMuted),
                      label: const Text(
                        'Solution',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _resetDailyPuzzle,
                  icon: const AppIcon(name: 'rotate-ccw', size: 15, color: AppColors.textMuted),
                  tooltip: 'Reset',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfacePanel,
                    minimumSize: const Size(38, 38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
            onPressed: () async {
              final analyze = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const PassAndPlayScreen()),
              );
              if (analyze == true) {
                _loadLastPlayedGameIntoAnalysis();
              }
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
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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
                            Text('$_customInitialMin min', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                            Text('+$_customIncrementSec sec', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
  // TAB 2: PUZZLES (TACTICS LAB & PUZZLE MODES)
  // ==========================================
  Widget _buildPuzzlesTab() {
    final categories = ['all', 'mate', 'fork', 'pin', 'skewer', 'capture'];
    final tiers = [
      {'tier': 0, 'label': 'All Levels'},
      {'tier': 1, 'label': 'Novice (<1000)'},
      {'tier': 2, 'label': 'Intermediate (1000-1400)'},
      {'tier': 3, 'label': 'Advanced (1400-1800)'},
      {'tier': 4, 'label': 'Expert (1800-2200)'},
      {'tier': 5, 'label': 'Master (2200+)'},
    ];

    final isWhiteTurn = _puzzleTurn == PieceColor.white;
    final puzzleRating = _puzzleData?['rating']?.toString() ?? '1500';
    final puzzleCategory = (_puzzleData?['category']?.toString() ?? 'tactics').toUpperCase();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 96),
        children: [
          // Header: Title & Quick Rating & Flip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tactics & Puzzles',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Master motifs and tactical patterns',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const AppIcon(name: 'trophy', size: 14, color: AppColors.textPrimary),
                        const SizedBox(width: 6),
                        Text(
                          '${_userRatings['puzzles'] ?? 400} Elo',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                        ),
                        if (_puzzleRatingDiff != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            _puzzleRatingDiff! > 0 ? '+${_puzzleRatingDiff!}' : '${_puzzleRatingDiff!}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _puzzleRatingDiff! > 0 ? AppColors.green : AppColors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const AppIcon(name: 'rotate-cw', size: 16, color: AppColors.textMuted),
                    onPressed: _flipPuzzleBoard,
                    tooltip: 'Flip Board',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceCard,
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mode Switcher: Practice, Daily, Weekly
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _puzzleModeButton(
                    mode: 'practice',
                    label: 'Practice',
                    icon: 'puzzle',
                    isSelected: _puzzleMode == 'practice',
                    onTap: () {
                      if (_puzzleMode != 'practice') {
                        _loadPuzzleTabPuzzle(overrideMode: 'practice');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _puzzleModeButton(
                    mode: 'daily',
                    label: 'Daily',
                    icon: 'flame',
                    isSelected: _puzzleMode == 'daily',
                    onTap: () {
                      if (_puzzleMode != 'daily') {
                        _loadPuzzleTabPuzzle(overrideMode: 'daily');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _puzzleModeButton(
                    mode: 'weekly',
                    label: 'Weekly',
                    icon: 'trophy',
                    badge: _puzzleWeeklyList.isNotEmpty ? '${_puzzleWeeklyIndex + 1}/${_puzzleWeeklyList.length}' : '7',
                    isSelected: _puzzleMode == 'weekly',
                    onTap: () {
                      if (_puzzleMode != 'weekly') {
                        _loadPuzzleTabPuzzle(overrideMode: 'weekly');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Category & Difficulty Selection (Visible in Practice Mode)
          if (_puzzleMode == 'practice') ...[
            // Category Chips
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final cat = categories[idx];
                  final isSel = _puzzleCategory == cat;
                  return GestureDetector(
                    onTap: () {
                      if (_puzzleCategory != cat) {
                        setState(() => _puzzleCategory = cat);
                        _loadPuzzleTabPuzzle();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.textPrimary : AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSel ? AppColors.textPrimary : AppColors.border),
                      ),
                      child: Center(
                        child: Text(
                          cat[0].toUpperCase() + cat.substring(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSel ? AppColors.background : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Tier / Difficulty Chips
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tiers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final t = tiers[idx];
                  final tierVal = t['tier'] as int;
                  final label = t['label'] as String;
                  final isSel = _puzzleTier == tierVal;
                  return GestureDetector(
                    onTap: () {
                      if (_puzzleTier != tierVal) {
                        setState(() => _puzzleTier = tierVal);
                        _loadPuzzleTabPuzzle();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.surfacePanel : AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? AppColors.textPrimary : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Status & Turn Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _puzzleSolved
                    ? AppColors.green.withValues(alpha: 0.5)
                    : _puzzleStatusColor == AppColors.red
                        ? AppColors.red.withValues(alpha: 0.5)
                        : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isWhiteTurn ? Colors.white : const Color(0xFF202020),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _puzzleStatusMsg,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _puzzleStatusColor,
                    ),
                  ),
                ),
                if (_puzzleLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Interactive Chess Board
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 390),
            child: ChessBoardWidget(
              fen: _puzzleFen,
              orientation: _puzzleOrientation,
              turn: _puzzleTurn,
              playerColor: _puzzlePlayerColor,
              lastMove: _puzzleLastMove,
              hintSquare: _puzzleHintSquare,
              hintTarget: _puzzleHintTarget,
              interactive: !_puzzleSolved && !_puzzleIsSolutionRevealed && !_puzzleIsOpponentReplying && !_puzzleIsRetrying,
              onMove: _onPuzzleMove,
            ),
          ),
          const SizedBox(height: 12),

          // Tactical Control Bar
          if (_puzzleSolved || _puzzleIsSolutionRevealed) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: AppColors.background,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _nextPuzzle,
                      icon: const AppIcon(name: 'arrow-right', size: 16, color: AppColors.background),
                      label: const Text('Next Puzzle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _resetPuzzle,
                  icon: const AppIcon(name: 'rotate-ccw', size: 18, color: AppColors.textPrimary),
                  tooltip: 'Retry Position',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceCard,
                    minimumSize: const Size(46, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _analysisFen = _puzzleFen;
                      _currentTabIndex = 3; // Switch to Analysis Tab
                    });
                    _evaluateCurrentAnalysisPosition();
                  },
                  icon: const AppIcon(name: 'search', size: 18, color: AppColors.textPrimary),
                  tooltip: 'Analyze Position',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceCard,
                    minimumSize: const Size(46, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceCard,
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _puzzleIsSolutionRevealed ? null : _requestPuzzleHint,
                      icon: const AppIcon(name: 'sparkles', size: 14, color: AppColors.textPrimary),
                      label: Text(
                        _puzzleHintCount == 0 ? 'Hint' : 'Target',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceCard,
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _puzzleIsSolutionRevealed ? null : _revealPuzzleSolution,
                      icon: const AppIcon(name: 'eye', size: 14, color: AppColors.textMuted),
                      label: const Text(
                        'Solution',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _resetPuzzle,
                  icon: const AppIcon(name: 'rotate-ccw', size: 16, color: AppColors.textMuted),
                  tooltip: 'Reset Board',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceCard,
                    minimumSize: const Size(42, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _nextPuzzle,
                  icon: const AppIcon(name: 'chevrons-right', size: 16, color: AppColors.textMuted),
                  tooltip: 'Skip Puzzle',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceCard,
                    minimumSize: const Size(42, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Puzzle Details & Meta Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                        puzzleCategory,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rating: $puzzleRating',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Text(
                  _puzzleMode == 'daily'
                      ? "Today's Daily"
                      : _puzzleMode == 'weekly'
                          ? 'Challenge ${_puzzleWeeklyIndex + 1} of ${_puzzleWeeklyList.isNotEmpty ? _puzzleWeeklyList.length : 7}'
                          : '$_puzzleSolvedToday solved today',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _puzzleModeButton({
    required String mode,
    required String label,
    required String icon,
    String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              name: icon,
              size: 14,
              color: isSelected ? AppColors.background : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.background : AppColors.textMuted,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Text(
                '($badge)',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: isSelected ? AppColors.background.withValues(alpha: 0.8) : AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
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
                    icon: const AppIcon(name: 'download', size: 16, color: AppColors.textPrimary),
                    onPressed: _showGameExplorerModal,
                    tooltip: 'Game Explorer (Saved & Server Games)',
                  ),
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
            // Logged Out / Elevated Studio Noir Auth Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Brand Emblem
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.surfacePanel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: AppIcon(name: 'crown', size: 26, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title & Subtitle
                  Text(
                    _isLoginMode ? 'Welcome Back' : 'Create Account',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLoginMode
                        ? 'Sign in to sync your official Elo, rated games, and tactical progression.'
                        : 'Join the zero-latency chess arena with official ratings.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
                  ),
                  const SizedBox(height: 16),

                  // Value Proposition Pills
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _authFeaturePill('zap', '0ms Moves'),
                      _authFeaturePill('trophy', 'Official Elo'),
                      _authFeaturePill('puzzle', 'Daily Tactics'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Segmented Switcher (Sign In vs Create Account)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfacePanel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _isLoginMode = true;
                              _authError = '';
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _isLoginMode ? AppColors.textPrimary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _isLoginMode ? AppColors.background : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _isLoginMode = false;
                              _authError = '';
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !_isLoginMode ? AppColors.textPrimary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: !_isLoginMode ? AppColors.background : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Username Input
                  TextField(
                    controller: _authUsernameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: AppIcon(name: 'user', size: 16, color: AppColors.textMuted),
                      ),
                      labelText: 'Username',
                      hintText: 'Enter your player handle',
                      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 13),
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
                        borderSide: const BorderSide(color: AppColors.textPrimary, width: 1.5),
                      ),
                    ),
                  ),

                  // Email Input (if register)
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _authEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(12),
                          child: AppIcon(name: 'mail', size: 16, color: AppColors.textMuted),
                        ),
                        labelText: 'Email Address',
                        hintText: 'player@example.com',
                        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 13),
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
                          borderSide: const BorderSide(color: AppColors.textPrimary, width: 1.5),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Password Input with Visibility Toggle
                  TextField(
                    controller: _authPasswordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: AppIcon(name: 'lock', size: 16, color: AppColors.textMuted),
                      ),
                      suffixIcon: IconButton(
                        icon: AppIcon(
                          name: _obscurePassword ? 'eye' : 'eye-off',
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      ),
                      labelText: 'Password',
                      hintText: '••••••••',
                      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 13),
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
                        borderSide: const BorderSide(color: AppColors.textPrimary, width: 1.5),
                      ),
                    ),
                  ),

                  // Error Banner
                  if (_authError.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const AppIcon(name: 'x', size: 14, color: AppColors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _authError,
                              style: const TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: AppColors.background,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isAuthLoading ? null : _handleAuthSubmit,
                      child: _isAuthLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _isLoginMode ? 'Signing In...' : 'Creating Account...',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.background),
                                ),
                              ],
                            )
                          : Text(
                              _isLoginMode ? 'Sign In' : 'Create Free Account',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Toggle Text Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLoginMode ? "Don't have an account?" : "Already have an account?",
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _isLoginMode = !_isLoginMode;
                          _authError = '';
                        }),
                        child: Text(
                          _isLoginMode ? 'Create one free' : 'Sign In',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
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
                    child: const Center(child: AppIcon(name: 'trophy', size: 22, color: AppColors.textPrimary)),
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

  Widget _authFeaturePill(String icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfacePanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(name: icon, size: 12, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
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
                      AppIcon(name: 'trophy', size: 20, color: AppColors.textPrimary),
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
                                        color: rank <= 3 ? Colors.white.withValues(alpha: 0.12) : AppColors.surfacePanel,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '#$rank',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: rank <= 3 ? AppColors.textPrimary : AppColors.textMuted,
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
