enum PieceColor { white, black }

enum PieceType { pawn, knight, bishop, rook, queen, king }

class ChessPiece {
  final PieceColor color;
  final PieceType type;

  const ChessPiece({required this.color, required this.type});

  String get assetPath {
    final prefix = color == PieceColor.white ? 'w' : 'b';
    final char = switch (type) {
      PieceType.pawn => 'p',
      PieceType.knight => 'n',
      PieceType.bishop => 'b',
      PieceType.rook => 'r',
      PieceType.queen => 'q',
      PieceType.king => 'k',
    };
    return 'assets/pieces/${prefix}_$char.svg';
  }

  String get symbol {
    final s = switch (type) {
      PieceType.pawn => 'P',
      PieceType.knight => 'N',
      PieceType.bishop => 'B',
      PieceType.rook => 'R',
      PieceType.queen => 'Q',
      PieceType.king => 'K',
    };
    return color == PieceColor.white ? s : s.toLowerCase();
  }
}

class LegalTarget {
  final String from;
  final String to;
  final bool isCapture;
  final bool isEnPassant;
  final bool isCastle;
  final bool isPromotion;
  final String san;
  final String? promotion;

  const LegalTarget({
    required this.from,
    required this.to,
    required this.isCapture,
    required this.isEnPassant,
    required this.isCastle,
    required this.isPromotion,
    required this.san,
    this.promotion,
  });
}

class LastMoveInfo {
  final String from;
  final String to;
  final String san;
  final bool isCapture;
  final bool isPromotion;

  const LastMoveInfo({
    required this.from,
    required this.to,
    required this.san,
    this.isCapture = false,
    this.isPromotion = false,
  });
}
