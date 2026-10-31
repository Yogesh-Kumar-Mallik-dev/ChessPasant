import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  String _baseUrl = 'https://chess.yogeshmallik.in/api/v1';
  String? _authToken;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        return handler.next(options);
      },
    ));
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    final customUrl = prefs.getString('api_base_url');
    if (customUrl != null && customUrl.isNotEmpty) {
      _baseUrl = customUrl;
      _dio.options.baseUrl = _baseUrl;
    }
  }

  Future<void> setAuthToken(String? token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
  }

  String? get authToken => _authToken;
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  // Authentication
  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    final token = res.data['tokens']?['accessToken'] ??
        res.data['token'] ??
        res.data['accessToken'];
    if (token != null) {
      await setAuthToken(token.toString());
    }
    return res.data;
  }

  Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    final res = await _dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
    });
    final token = res.data['tokens']?['accessToken'] ??
        res.data['token'] ??
        res.data['accessToken'];
    if (token != null) {
      await setAuthToken(token.toString());
    }
    return res.data;
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
    await setAuthToken(null);
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final res = await _dio.get('/users/me');
      return res.data;
    } catch (_) {
      try {
        final res = await _dio.get('/auth/me');
        return res.data;
      } catch (_) {
        return null;
      }
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String username) async {
    try {
      final res = await _dio.get('/users/$username');
      return res.data;
    } catch (_) {
      return null;
    }
  }

  // Leaderboard
  Future<List<dynamic>> getLeaderboard(String category) async {
    try {
      final res = await _dio.get('/leaderboard', queryParameters: {'category': category});
      return res.data is List ? res.data : [];
    } catch (_) {
      return [];
    }
  }

  // Games
  Future<Map<String, dynamic>?> getActiveGame() async {
    try {
      final res = await _dio.get('/games/active');
      return res.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getGame(String gameId) async {
    final res = await _dio.get('/games/$gameId');
    return res.data;
  }

  Future<String?> getGamePgn(String gameId) async {
    try {
      final res = await _dio.get('/games/$gameId/pgn');
      return res.data.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> listGames({String? userId, int limit = 10}) async {
    final query = <String, dynamic>{'limit': limit};
    if (userId != null) query['userId'] = userId;
    try {
      final res = await _dio.get('/games', queryParameters: query);
      return res.data is List ? res.data : [];
    } catch (_) {
      return [];
    }
  }

  // Matchmaking
  Future<Map<String, dynamic>> joinMatchmaking({
    required int initial,
    required int increment,
  }) async {
    final res = await _dio.post('/matchmaking/join', data: {
      'initial': initial,
      'increment': increment,
    });
    return res.data;
  }

  Future<void> leaveMatchmaking() async {
    try {
      await _dio.post('/matchmaking/leave');
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getMatchmakingStatus() async {
    try {
      final res = await _dio.get('/matchmaking/status');
      return res.data;
    } catch (_) {
      return null;
    }
  }

  // Analysis & Engine
  Future<Map<String, dynamic>?> evaluatePosition(String fen, {int depth = 12}) async {
    try {
      final res = await _dio.post('/analysis/evaluate', data: {
        'fen': fen,
        'depth': depth,
      });
      return res.data;
    } catch (_) {
      return null;
    }
  }

  // Puzzles
  Future<Map<String, dynamic>?> getRandomPuzzle({
    String? category,
    int? tier,
    int? minRating,
    int? maxRating,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (category != null && category != 'all') query['category'] = category;
      if (tier != null && tier > 0) query['tier'] = tier;
      if (minRating != null) query['minRating'] = minRating;
      if (maxRating != null) query['maxRating'] = maxRating;

      final res = await _dio.get('/puzzles/random', queryParameters: query);
      return res.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDailyPuzzle() async {
    try {
      final res = await _dio.get('/puzzles/daily');
      return res.data;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> getWeeklyPuzzles() async {
    try {
      final res = await _dio.get('/puzzles/weekly');
      return res.data is List ? res.data : [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getPuzzleHint(String puzzleId, {int plyIndex = 0}) async {
    try {
      final res = await _dio.get('/puzzles/$puzzleId/hint', queryParameters: {'plyIndex': plyIndex});
      return res.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getPuzzleSolution(String puzzleId) async {
    try {
      final res = await _dio.get('/puzzles/$puzzleId/solution');
      return res.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> solvePuzzle(
    String puzzleId, {
    required String move,
    required int plyIndex,
    bool isRetry = false,
    bool hasAssistance = false,
  }) async {
    try {
      final res = await _dio.post('/puzzles/$puzzleId/solve', data: {
        'move': move,
        'plyIndex': plyIndex,
        'isRetry': isRetry,
        'hasAssistance': hasAssistance,
      });
      return res.data;
    } catch (_) {
      return null;
    }
  }

  // Challenges
  Future<Map<String, dynamic>> listChallenges() async {
    final res = await _dio.get('/friends/challenges');
    return res.data;
  }

  Future<Map<String, dynamic>> createChallenge({
    required String challengedId,
    required int initial,
    required int increment,
    required bool rated,
    String colorPref = 'random',
  }) async {
    final res = await _dio.post('/friends/challenges', data: {
      'challengedId': challengedId,
      'initial': initial,
      'increment': increment,
      'rated': rated,
      'colorPref': colorPref,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> respondChallenge(String challengeId, bool accept) async {
    final res = await _dio.post('/friends/challenges/$challengeId/respond', data: {
      'accept': accept,
    });
    return res.data;
  }

  // Cloud Bot Move Fallback
  Future<Map<String, dynamic>> botMove(String fen, int level) async {
    final res = await _dio.post('/chess/bot-move', data: {
      'fen': fen,
      'level': level,
    });
    return res.data;
  }
}
