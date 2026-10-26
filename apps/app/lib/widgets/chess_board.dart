import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../chess/models.dart';
import '../chess/engine.dart';

class ChessBoardWidget extends StatefulWidget {
  final String fen;
  final PieceColor orientation;
  final PieceColor turn;
  final PieceColor? playerColor;
  final LastMoveInfo? lastMove;
  final bool interactive;
  final Function(String from, String to, String? promotion) onMove;

  const ChessBoardWidget({
    super.key,
    required this.fen,
    this.orientation = PieceColor.white,
    this.turn = PieceColor.white,
    this.playerColor,
    this.lastMove,
    this.interactive = true,
    required this.onMove,
  });

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget> {
  String? _selectedSquare;
  List<LegalTarget> _legalTargets = [];

  void _onSquareTapped(String sq, ChessPiece? piece) {
    if (!widget.interactive) return;
    if (widget.playerColor != null && widget.turn != widget.playerColor) return;

    if (_selectedSquare != null) {
      if (_selectedSquare == sq) {
        setState(() {
          _selectedSquare = null;
          _legalTargets = [];
        });
        return;
      }

      // Check if clicking another of player's own pieces
      if (piece != null && piece.color == widget.turn &&
          (widget.playerColor == null || piece.color == widget.playerColor)) {
        setState(() {
          _selectedSquare = sq;
          _legalTargets = ChessEngine.getLegalMovesForSquare(widget.fen, sq);
        });
        return;
      }

      // Check if clicked square is a legal move target
      final target = _legalTargets.where((t) => t.to == sq).firstOrNull;
      if (target != null) {
        final fromSq = _selectedSquare!;
        setState(() {
          _selectedSquare = null;
          _legalTargets = [];
        });

        if (target.isPromotion) {
          _showPromotionDialog(fromSq, sq);
        } else {
          widget.onMove(fromSq, sq, null);
        }
        return;
      }

      // Clicked outside legal moves
      setState(() {
        _selectedSquare = null;
        _legalTargets = [];
      });
      return;
    }

    // Select piece
    if (piece != null && piece.color == widget.turn &&
        (widget.playerColor == null || piece.color == widget.playerColor)) {
      setState(() {
        _selectedSquare = sq;
        _legalTargets = ChessEngine.getLegalMovesForSquare(widget.fen, sq);
      });
    }
  }

  void _showPromotionDialog(String from, String to) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final color = widget.turn;
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2024),
          title: const Text('Promote Pawn', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _promoOption(ctx, color, PieceType.queen, 'q', from, to),
              _promoOption(ctx, color, PieceType.rook, 'r', from, to),
              _promoOption(ctx, color, PieceType.bishop, 'b', from, to),
              _promoOption(ctx, color, PieceType.knight, 'n', from, to),
            ],
          ),
        );
      },
    );
  }

  Widget _promoOption(BuildContext ctx, PieceColor color, PieceType type, String char, String from, String to) {
    final p = ChessPiece(color: color, type: type);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.of(ctx).pop();
        widget.onMove(from, to, char);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: SvgPicture.asset(p.assetPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = ChessEngine.fenToBoard(widget.fen);
    final checkedKingSq = ChessEngine.getCheckedKingSquare(widget.fen);
    final isWhiteOriented = widget.orientation == PieceColor.white;

    final targetSquares = _legalTargets.map((t) => t.to).toSet();
    final captureSquares = _legalTargets.where((t) => t.isCapture).map((t) => t.to).toSet();

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3B4048), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: List.generate(8, (rowIdx) {
            final rank = isWhiteOriented ? 7 - rowIdx : rowIdx;
            return Expanded(
              child: Row(
                children: List.generate(8, (colIdx) {
                  final file = isWhiteOriented ? colIdx : 7 - colIdx;
                  final sqName = '${String.fromCharCode('a'.codeUnitAt(0) + file)}${rank + 1}';
                  final piece = board[rank][file];

                  final isLight = (file + rank) % 2 != 0;
                  final isSelected = _selectedSquare == sqName;
                  final isLastMoveFrom = widget.lastMove?.from == sqName;
                  final isLastMoveTo = widget.lastMove?.to == sqName;
                  final isCheck = checkedKingSq == sqName;
                  final isTarget = targetSquares.contains(sqName);
                  final isCaptureTarget = captureSquares.contains(sqName);

                  // Colors: Emerald Theme
                  Color sqColor = isLight ? const Color(0xFFEEEED2) : const Color(0xFF69884A);
                  if (isSelected) {
                    sqColor = const Color(0xFFF7D963);
                  } else if (isLastMoveFrom || isLastMoveTo) {
                    sqColor = isLight ? const Color(0xFFCED378) : const Color(0xFFAAB83C);
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onSquareTapped(sqName, piece),
                      child: Container(
                        color: sqColor,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // In check radial indicator
                            if (isCheck)
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [Colors.redAccent.withValues(alpha: 0.85), Colors.transparent],
                                  ),
                                ),
                              ),

                            // Piece Icon
                            if (piece != null)
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: SvgPicture.asset(
                                  piece.assetPath,
                                  fit: BoxFit.contain,
                                ),
                              ),

                            // Legal move dot / capture ring
                            if (isTarget)
                              if (isCaptureTarget)
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      width: 4.5,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.25),
                                  ),
                                ),

                            // Rank coordinate
                            if (colIdx == 0)
                              Positioned(
                                top: 2,
                                left: 3,
                                child: Text(
                                  '${rank + 1}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isLight ? const Color(0xFF69884A) : const Color(0xFFEEEED2),
                                  ),
                                ),
                              ),

                            // File coordinate
                            if (rowIdx == 7)
                              Positioned(
                                bottom: 1,
                                right: 3,
                                child: Text(
                                  String.fromCharCode('a'.codeUnitAt(0) + file),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isLight ? const Color(0xFF69884A) : const Color(0xFFEEEED2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ),
    );
  }
}
