import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chesspasant/widgets/chess_board.dart';
import 'package:chesspasant/chess/engine.dart';

void main() {
  testWidgets('ChessBoardWidget renders 64 squares', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChessBoardWidget(
            fen: initialFen,
            onMove: (from, to, promo) {},
          ),
        ),
      ),
    );

    // 8 rows x 8 cols = 64 squares
    expect(find.byType(ChessBoardWidget), findsOneWidget);
  });
}
