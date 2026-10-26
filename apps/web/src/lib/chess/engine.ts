import { Chess, type Square } from 'chess.js';

export type Color = 'white' | 'black';
export type PieceType = 'p' | 'n' | 'b' | 'r' | 'q' | 'k';

export interface Piece {
	type: PieceType;
	color: Color;
}

export interface SquareInfo {
	file: number; // 0..7
	rank: number; // 0..7
	name: string; // e.g. "e4"
	color: 'light' | 'dark';
}

export interface ClientMove {
	from: string;
	to: string;
	promotion?: string;
}

export interface LegalTarget {
	from: string;
	to: string;
	category: 'normal' | 'capture' | 'castle' | 'en_passant';
	isCapture: boolean;
	isEnPassant: boolean;
	isCastle: boolean;
	isPromotion: boolean;
	san: string;
	promotion?: string;
}

export function parseSquare(name: string): { file: number; rank: number } | null {
	if (name.length !== 2) return null;
	const file = name.charCodeAt(0) - 'a'.charCodeAt(0);
	const rank = parseInt(name[1], 10) - 1;
	if (file < 0 || file > 7 || rank < 0 || rank > 7) return null;
	return { file, rank };
}

export function squareName(file: number, rank: number): string {
	return `${String.fromCharCode('a'.charCodeAt(0) + file)}${rank + 1}`;
}

export function fenToBoard(fen: string): (Piece | null)[][] {
	const board: (Piece | null)[][] = Array(8)
		.fill(null)
		.map(() => Array(8).fill(null));

	const parts = fen.trim().split(' ');
	const placement = parts[0];
	const ranks = placement.split('/');

	for (let r = 0; r < 8; r++) {
		const rankStr = ranks[r];
		let file = 0;
		for (const ch of rankStr) {
			if (ch >= '1' && ch <= '8') {
				file += parseInt(ch, 10);
			} else {
				const isUpper = ch === ch.toUpperCase();
				const color: Color = isUpper ? 'white' : 'black';
				const type = ch.toLowerCase() as PieceType;
				// ranks[0] is rank 8 (index 7 in 0-indexed chess coordinates)
				const rankIndex = 7 - r;
				board[rankIndex][file] = { type, color };
				file++;
			}
		}
	}

	return board;
}

export function boardToFen(board: (Piece | null)[][], turn: Color = 'white'): string {
	let res = '';
	for (let r = 7; r >= 0; r--) {
		let empty = 0;
		for (let f = 0; f < 8; f++) {
			const piece = board[r][f];
			if (!piece) {
				empty++;
			} else {
				if (empty > 0) {
					res += empty;
					empty = 0;
				}
				const ch = piece.color === 'white' ? piece.type.toUpperCase() : piece.type;
				res += ch;
			}
		}
		if (empty > 0) res += empty;
		if (r > 0) res += '/';
	}
	res += ` ${turn === 'white' ? 'w' : 'b'} KQkq - 0 1`;
	return res;
}

export const INITIAL_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/**
 * Returns all legal destination squares for a given square in the position.
 */
export function getLegalMovesForSquare(fen: string, square: string): LegalTarget[] {
	if (!square || !/^[a-h][1-8]$/.test(square)) {
		return [];
	}
	try {
		const chess = new Chess(fen);
		const moves = chess.moves({ square: square as Square, verbose: true });
		return moves.map((m) => {
			const isEnPassant = m.flags.includes('e');
			const isCastle = m.flags.includes('k') || m.flags.includes('q');
			const isCapture = !!m.captured || m.flags.includes('c') || isEnPassant;
			const isPromotion = m.flags.includes('p');

			let category: 'normal' | 'capture' | 'castle' | 'en_passant' = 'normal';
			if (isEnPassant) category = 'en_passant';
			else if (isCastle) category = 'castle';
			else if (isCapture) category = 'capture';

			return {
				from: m.from,
				to: m.to,
				category,
				isCapture,
				isEnPassant,
				isCastle,
				isPromotion,
				san: m.san,
				promotion: m.promotion
			};
		});
	} catch {
		return [];
	}
}

/**
 * Returns the square of the King currently in check, or null if neither king is checked.
 */
export function getCheckedKingSquare(fen: string): string | null {
	try {
		const chess = new Chess(fen);
		if (!chess.inCheck()) return null;
		const turn = chess.turn();
		const board = chess.board();
		for (let r = 0; r < 8; r++) {
			for (let c = 0; c < 8; c++) {
				const piece = board[r][c];
				if (piece && piece.type === 'k' && piece.color === turn) {
					return piece.square;
				}
			}
		}
	} catch {}
	return null;
}

/**
 * Determines whether a candidate move requires pawn promotion.
 */
export function isPromotionMove(fen: string, from: string, to: string): boolean {
	try {
		const chess = new Chess(fen);
		const piece = chess.get(from as Square);
		if (!piece || piece.type !== 'p') return false;
		if (piece.color === 'w' && to[1] === '8') return true;
		if (piece.color === 'b' && to[1] === '1') return true;
	} catch {}
	return false;
}

/**
 * Validates and executes a move client-side, returning standard FIDE SAN and updated state.
 */
export function executeMoveClient(
	fen: string,
	from: string,
	to: string,
	promotion?: string
): {
	valid: boolean;
	newFen: string;
	san: string;
	isCapture: boolean;
	isPromotion: boolean;
	isCheck: boolean;
	isCheckmate: boolean;
	isDraw: boolean;
	turn: Color;
	captured?: string;
} | null {
	try {
		const chess = new Chess(fen);
		const move = chess.move({
			from: from as Square,
			to: to as Square,
			promotion: (promotion ? promotion.toLowerCase() : 'q') as any
		});
		if (!move) return null;
		return {
			valid: true,
			newFen: chess.fen(),
			san: move.san,
			isCapture: !!move.captured || move.flags.includes('c') || move.flags.includes('e'),
			isPromotion: move.flags.includes('p') || !!move.promotion || move.san.includes('='),
			isCheck: chess.inCheck(),
			isCheckmate: chess.isCheckmate(),
			isDraw: chess.isDraw(),
			turn: (chess.turn() === 'w' ? 'white' : 'black') as Color,
			captured: move.captured
		};
	} catch {
		return null;
	}
}

import type { MoveCategory } from '$lib/audio/sounds';

/**
 * Detects move sound characteristics and category from resulting FEN and move coordinates.
 */
export function detectMoveCategory(
	fenAfter: string,
	from: string,
	to: string,
	fenBefore?: string,
	san?: string,
	isPromotion?: boolean
): MoveCategory {
	try {
		// 1. Definite notation signals
		if (san) {
			if (san.includes('#')) return 'checkmate';
			if (san.includes('=')) return 'promote';
			if (san.includes('+')) return 'check';
			if (san.startsWith('O-O')) return 'castle';
			if (san.includes('x')) return 'capture';
		}

		if (isPromotion) return 'promote';

		const chessAfter = new Chess(fenAfter);
		if (chessAfter.isCheckmate()) return 'checkmate';

		// Check pawn reaching promotion rank
		if (to[1] === '8' || to[1] === '1') {
			if (fenBefore) {
				try {
					const chessBefore = new Chess(fenBefore);
					const pieceBefore = chessBefore.get(from as Square);
					if (pieceBefore && pieceBefore.type === 'p') {
						return 'promote';
					}
				} catch {}
			}
		}

		if (chessAfter.inCheck()) return 'check';

		// 2. Exact move lookup or piece count delta from fenBefore
		if (fenBefore && fenBefore !== fenAfter) {
			try {
				const chessBefore = new Chess(fenBefore);
				const moves = chessBefore.moves({ verbose: true });
				const found = moves.find((m) => m.from === from && m.to === to);
				if (found) {
					if (found.flags.includes('p') || found.promotion) return 'promote';
					if (found.flags.includes('e')) return 'en_passant';
					if (found.flags.includes('k') || found.flags.includes('q')) return 'castle';
					if (found.captured || found.flags.includes('c')) return 'capture';
				}

				// Compare total piece counts across positions
				const countPieces = (f: string) => {
					const placement = f.split(' ')[0];
					let count = 0;
					for (const ch of placement) {
						if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) count++;
					}
					return count;
				};
				if (countPieces(fenAfter) < countPieces(fenBefore)) {
					return 'capture';
				}
			} catch {}
		}

		// 3. Castling fallback on fenAfter
		const piece = chessAfter.get(to as Square);
		if (piece?.type === 'k' && Math.abs(from.charCodeAt(0) - to.charCodeAt(0)) > 1) {
			return 'castle';
		}

		return 'normal';
	} catch {
		return 'normal';
	}
}

/**
 * Detects move sound characteristics from resulting FEN and move coordinates.
 */
export function detectMoveSoundType(
	fen: string,
	from: string,
	to: string
): { isCapture: boolean; isCheck: boolean; isCastle: boolean; isPromotion: boolean; san: string } {
	try {
		const chess = new Chess(fen);
		const inCheck = chess.inCheck();
		const isCheckmate = chess.isCheckmate();
		const piece = chess.get(to as Square);
		const isCastle = piece?.type === 'k' && Math.abs(from.charCodeAt(0) - to.charCodeAt(0)) > 1;
		const isPromotion =
			(piece?.type === 'q' || piece?.type === 'r' || piece?.type === 'b' || piece?.type === 'n') &&
			(to[1] === '8' || to[1] === '1');

		return {
			isCapture: false,
			isCheck: inCheck,
			isCastle,
			isPromotion,
			san: isCheckmate ? '#' : inCheck ? '+' : isCastle ? 'O-O' : ''
		};
	} catch {
		return { isCapture: false, isCheck: false, isCastle: false, isPromotion: false, san: '' };
	}
}
