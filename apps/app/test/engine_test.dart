import 'package:flutter_test/flutter_test.dart';
import 'package:chesspasant/chess/engine.dart';

void main() {
  group('ChessEngine Tests', () {
    test('Initial board has 32 pieces', () {
      final board = ChessEngine.fenToBoard(initialFen);
      int pieceCount = 0;
      for (final row in board) {
        for (final p in row) {
          if (p != null) pieceCount++;
        }
      }
      expect(pieceCount, 32);
    });

    test('Initial legal moves for e2 pawn are e3 and e4', () {
      final moves = ChessEngine.getLegalMovesForSquare(initialFen, 'e2');
      final targets = moves.map((m) => m.to).toList();
      expect(targets, containsAll(['e3', 'e4']));
      expect(targets.length, 2);
    });

    test('Initial legal moves for b1 knight are a3 and c3', () {
      final moves = ChessEngine.getLegalMovesForSquare(initialFen, 'b1');
      final targets = moves.map((m) => m.to).toList();
      expect(targets, containsAll(['a3', 'c3']));
      expect(targets.length, 2);
    });

    test('Invalid square returns empty legal targets', () {
      expect(ChessEngine.getLegalMovesForSquare(initialFen, ''), isEmpty);
      expect(ChessEngine.getLegalMovesForSquare(initialFen, 'z9'), isEmpty);
      expect(ChessEngine.getLegalMovesForSquare(initialFen, 'e4'), isEmpty);
    });

    test('Scholar\'s mate detection', () {
      // 1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6 4. Qxf7#
      final mateFen = 'r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4';
      final kingSq = ChessEngine.getCheckedKingSquare(mateFen);
      expect(kingSq, 'e8');

      final res = ChessEngine.executeMove(
        'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 4',
        'c4',
        'f7',
      );
      expect(res, isNotNull);
      expect(res!['isCheck'], isTrue);
      // c4 to f7 is not legal with Bishop when blocked, but Qf7# is
      final qRes = ChessEngine.executeMove(
        'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/7Q/PPPP1PPP/RNB1K1NR w KQkq - 0 4',
        'h3',
        'f7',
      );
      expect(qRes, isNull);
    });

    test('Castling detection', () {
      const castleFen = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1';
      final moves = ChessEngine.getLegalMovesForSquare(castleFen, 'e1');
      final castleMoves = moves.where((m) => m.isCastle).map((m) => m.to).toList();
      expect(castleMoves, containsAll(['g1', 'c1']));
    });

    test('parsePgn extracts move sequence and FEN states correctly', () {
      const pgn = '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6';
      final parsed = ChessEngine.parsePgn(pgn);
      expect(parsed.length, 6);
      expect(parsed[0]['san'], 'e4');
      expect(parsed[0]['from'], 'e2');
      expect(parsed[0]['to'], 'e4');
      expect(parsed[5]['san'], 'a6');
      expect(parsed[5]['fen'], contains(' '));
    });
  });
}
