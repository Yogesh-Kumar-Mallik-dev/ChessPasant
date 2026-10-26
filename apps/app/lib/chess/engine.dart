import 'package:chess/chess.dart' as chess_lib;
import 'models.dart';

const String initialFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class ChessEngine {
  static List<List<ChessPiece?>> fenToBoard(String fen) {
    final board = List.generate(8, (_) => List<ChessPiece?>.filled(8, null));
    final parts = fen.trim().split(' ');
    if (parts.isEmpty) return board;

    final ranks = parts[0].split('/');
    for (int r = 0; r < 8 && r < ranks.length; r++) {
      final rankStr = ranks[r];
      int file = 0;
      for (int i = 0; i < rankStr.length && file < 8; i++) {
        final ch = rankStr[i];
        final num = int.tryParse(ch);
        if (num != null) {
          file += num;
        } else {
          final isUpper = ch == ch.toUpperCase();
          final color = isUpper ? PieceColor.white : PieceColor.black;
          final type = switch (ch.toLowerCase()) {
            'p' => PieceType.pawn,
            'n' => PieceType.knight,
            'b' => PieceType.bishop,
            'r' => PieceType.rook,
            'q' => PieceType.queen,
            'k' => PieceType.king,
            _ => PieceType.pawn,
          };
          // rank 8 is index 7
          final rankIdx = 7 - r;
          board[rankIdx][file] = ChessPiece(color: color, type: type);
          file++;
        }
      }
    }
    return board;
  }

  static List<LegalTarget> getLegalMovesForSquare(String fen, String square) {
    if (square.length != 2) return const [];
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(square[1]);
    if (file < 0 || file > 7 || rank == null || rank < 1 || rank > 8) {
      return const [];
    }

    try {
      final chess = chess_lib.Chess.fromFEN(fen);
      final moves = chess.generate_moves({'square': square});
      final targets = <LegalTarget>[];

      for (final m in moves) {
        final toSq = m.toAlgebraic;
        final san = chess.move_to_san(m);
        final isEnPassant = m.flags & chess_lib.Chess.BITS_EP_CAPTURE != 0;
        final isCastle = (m.flags & chess_lib.Chess.BITS_KSIDE_CASTLE != 0) ||
            (m.flags & chess_lib.Chess.BITS_QSIDE_CASTLE != 0);
        final isCapture = (m.flags & chess_lib.Chess.BITS_CAPTURE != 0) || isEnPassant;
        final isPromotion = (m.flags & chess_lib.Chess.BITS_PROMOTION != 0);

        targets.add(LegalTarget(
          from: square,
          to: toSq,
          isCapture: isCapture,
          isEnPassant: isEnPassant,
          isCastle: isCastle,
          isPromotion: isPromotion,
          san: san,
          promotion: m.promotion?.name,
        ));
      }
      return targets;
    } catch (_) {
      return const [];
    }
  }

  static String? getCheckedKingSquare(String fen) {
    try {
      final chess = chess_lib.Chess.fromFEN(fen);
      if (!chess.in_check) return null;
      final turnColor = chess.turn;
      final board = fenToBoard(fen);
      for (int r = 0; r < 8; r++) {
        for (int f = 0; f < 8; f++) {
          final p = board[r][f];
          if (p != null && p.type == PieceType.king) {
            final isTurn = (p.color == PieceColor.white && turnColor == chess_lib.Color.WHITE) ||
                (p.color == PieceColor.black && turnColor == chess_lib.Color.BLACK);
            if (isTurn) {
              return '${String.fromCharCode('a'.codeUnitAt(0) + f)}${r + 1}';
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic>? executeMove(
    String fen,
    String from,
    String to, {
    String? promotion,
  }) {
    try {
      final chess = chess_lib.Chess.fromFEN(fen);
      final legalMoves = chess.generate_moves();
      chess_lib.Move? matchedMove;
      for (final m in legalMoves) {
        if (m.fromAlgebraic == from && m.toAlgebraic == to) {
          if (m.promotion == null ||
              promotion == null ||
              m.promotion!.name.toLowerCase() == promotion.toLowerCase()) {
            matchedMove = m;
            break;
          }
        }
      }
      if (matchedMove == null) return null;

      final san = chess.move_to_san(matchedMove);
      final isCap = (matchedMove.flags & chess_lib.Chess.BITS_CAPTURE != 0) ||
          (matchedMove.flags & chess_lib.Chess.BITS_EP_CAPTURE != 0);
      final isPromo = (matchedMove.flags & chess_lib.Chess.BITS_PROMOTION != 0);

      final ok = chess.move(matchedMove);
      if (!ok) return null;

      return {
        'valid': true,
        'newFen': chess.fen,
        'san': san,
        'isCapture': isCap,
        'isPromotion': isPromo,
        'isCheck': chess.in_check,
        'isCheckmate': chess.in_checkmate,
        'isDraw': chess.in_draw || chess.in_stalemate || chess.in_threefold_repetition,
        'turn': chess.turn == chess_lib.Color.WHITE ? PieceColor.white : PieceColor.black,
      };
    } catch (_) {
      return null;
    }
  }
}
