class SavedGameRecord {
  final String title;
  final String mode; // 'Online Match', 'Pass & Play', 'vs Bot'
  final String date;
  final String whitePlayer;
  final String blackPlayer;
  final String result;
  final String finalFen;
  final List<Map<String, dynamic>> moves; // [{from, to, san, fen}]
  final String? pgn;
  final String? gameId;

  const SavedGameRecord({
    required this.title,
    required this.mode,
    required this.date,
    required this.whitePlayer,
    required this.blackPlayer,
    required this.result,
    required this.finalFen,
    required this.moves,
    this.pgn,
    this.gameId,
  });
}

class GameArchive {
  static SavedGameRecord? lastPlayedGame;
  static final List<SavedGameRecord> recentGames = [];

  static void saveGame(SavedGameRecord game) {
    lastPlayedGame = game;
    recentGames.removeWhere((g) => g.gameId != null && g.gameId == game.gameId);
    recentGames.insert(0, game);
    if (recentGames.length > 20) {
      recentGames.removeLast();
    }
  }
}
