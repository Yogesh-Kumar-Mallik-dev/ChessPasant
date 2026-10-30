import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../chess/models.dart';

class EvalBar extends StatelessWidget {
  final int scoreCp;
  final bool isMate;
  final int? mateIn;
  final PieceColor orientation;

  const EvalBar({
    super.key,
    this.scoreCp = 0,
    this.isMate = false,
    this.mateIn,
    this.orientation = PieceColor.white,
  });

  double _getWhitePercent() {
    if (isMate && mateIn != null) {
      return mateIn! > 0 ? 100.0 : 0.0;
    }
    final clamped = scoreCp.clamp(-1000, 1000);
    // Sigmoid curve for smooth advantage percentage
    final p = 50 + 50 * (2 / (1 + exp(-0.004 * clamped)) - 1);
    return p.clamp(4.0, 96.0);
  }

  String get formattedScore {
    if (isMate && mateIn != null) {
      return mateIn! > 0 ? 'M${mateIn!.abs()}' : '-M${mateIn!.abs()}';
    }
    final pawns = (scoreCp / 100.0).toStringAsFixed(1);
    if (scoreCp > 0) return '+$pawns';
    if (scoreCp < 0) return pawns;
    return '0.0';
  }

  @override
  Widget build(BuildContext context) {
    final whitePercent = _getWhitePercent();
    final bottomPercent = orientation == PieceColor.white
        ? whitePercent
        : 100.0 - whitePercent;

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Evaluation label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            formattedScore,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Slim vertical evaluation bar
        Expanded(
          child: Container(
            width: 14,
            decoration: BoxDecoration(
              color: AppColors.boardDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Top fill (Dark if orientation is white, Light if black)
                Container(
                  color: orientation == PieceColor.white
                      ? AppColors.boardDark
                      : AppColors.boardLight,
                ),

                // Bottom fill (Light if orientation is white, Dark if black)
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  heightFactor: (bottomPercent / 100.0).clamp(0.0, 1.0),
                  child: Container(
                    color: orientation == PieceColor.white
                        ? AppColors.boardLight
                        : AppColors.boardDark,
                  ),
                ),

                // Center equality line
                const Center(
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
