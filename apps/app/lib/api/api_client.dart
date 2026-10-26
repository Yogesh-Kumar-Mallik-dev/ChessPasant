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

  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  // Authentication
  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    if (res.data['token'] != null) {
      await setAuthToken(res.data['token']);
    }
    return res.data;
  }

  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final res = await _dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
    });
    if (res.data['token'] != null) {
      await setAuthToken(res.data['token']);
    }
    return res.data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/auth/me');
    return res.data;
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

  Future<List<dynamic>> listGames({int limit = 10}) async {
    final res = await _dio.get('/games', queryParameters: {'limit': limit});
    return res.data is List ? res.data : [];
  }

  // Puzzles
  Future<Map<String, dynamic>?> getDailyPuzzle() async {
    try {
      final res = await _dio.get('/puzzles/daily');
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
