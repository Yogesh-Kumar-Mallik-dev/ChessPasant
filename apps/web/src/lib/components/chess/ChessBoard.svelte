<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { Chess } from 'chess.js';
	import {
		fenToBoard,
		squareName,
		getLegalMovesForSquare,
		getCheckedKingSquare,
		isPromotionMove,
		detectMoveCategory,
		type Color,
		type Piece,
		type PieceType,
		type LegalTarget
	} from '$lib/chess/engine';
	import { playMoveSoundByCategory, soundEffects } from '$lib/audio/sounds';
	import ChessSquare from './ChessSquare.svelte';
	import ChessPiece from './ChessPiece.svelte';
	import PromotionDialog from './PromotionDialog.svelte';
	import Icon from '$lib/components/icons/Icon.svelte';

	import type { MoveClassification } from '$lib/chess/review';

	export let fen: string;
	export let orientation: Color = 'white';
	export let turn: Color = 'white';
	export let playerColor: Color | null = null;
	export let selectedSquare: string | null = null;
	export let lastMove: { from: string; to: string; san?: string; isCapture?: boolean; isPromotion?: boolean } | null = null;
	export let isCheck: boolean = false;
	export let interactive = true;
	export let animateMoves = true;
	export let showSoundToggle = false;
	export let gameOver = false;
	export let gameResult = '';
	export let gameOutcome = '';
	export let gameWinner = '';
	export let disableGameOverModal = false;
	export let mode: 'game' | 'puzzle' | 'analysis' = 'game';
	export let hintSquare: string | null = null;
	export let hintArrow: { from: string; to: string } | null = null;
	export let reviewMove: {
		from: string;
		to: string;
		classification: MoveClassification;
		bestMoveUci?: string;
	} | null = null;
	import { themeStore, type BoardTheme } from '$lib/stores/preferences';

	export let theme: BoardTheme = $themeStore;
	export let boardSizeClass: string = 'max-w-[min(100%,calc(100dvh-200px),600px)]';

	onMount(() => {
		const unsub = themeStore.subscribe((val) => {
			if (val) theme = val;
		});
		return () => unsub();
	});

	const dispatch = createEventDispatcher<{
		move: { from: string; to: string; promotion?: PieceType; isCapture?: boolean; isPromotion?: boolean };
		select: string;
		newGame: void;
		rematch: void;
		analyze: void;
	}>();

	let draggedFrom: string | null = null;
	let pendingPromotion: { from: string; to: string; isCapture?: boolean } | null = null;
	let soundMuted = false;
	let showGameOverModal = true;
	let losingKingReason: 'checkmate' | 'resignation' | 'timeout' = 'checkmate';

	// Animation state for multi-piece sliding (e.g. King + Rook in Castling)
	let prevProcessedMoveId = '';
	let animatingMap = new Map<string, { dx: number; dy: number }>();
	let isSliding = false;

	$: board = fenToBoard(fen);

	// Authoritative synchronous legal move generation using client chess engine.
	// Completely eliminates network race conditions, stale target retention, and visual move desyncs.
	$: legalTargets = selectedSquare ? getLegalMovesForSquare(fen, selectedSquare) : [];
	$: legalTargetMap = new Map<string, LegalTarget>(legalTargets.map((t) => [t.to, t]));
	$: legalTargetSquares = new Set(legalTargets.map((t) => t.to));
	$: legalCaptureSquares = new Set(legalTargets.filter((t) => t.isCapture).map((t) => t.to));

	// Engine state evaluation for game termination & check detection
	$: engineState = (() => {
		try {
			const c = new Chess(fen);
			return {
				isCheckmate: c.isCheckmate(),
				isDraw: c.isDraw(),
				inCheck: c.inCheck()
			};
		} catch {
			return { isCheckmate: false, isDraw: false, inCheck: false };
		}
	})();

	$: kingInCheckSquare = getCheckedKingSquare(fen) || (isCheck || engineState.inCheck ? getCheckedKingSquare(fen) : null);

	$: isCheckmate = gameOver ? gameOutcome === 'checkmate' : engineState.isCheckmate;
	$: isDraw = gameOver
		? gameResult === '1/2-1/2' || ['stalemate', 'threefold_repetition', 'fifty_moves', 'insufficient_material', 'draw_agreed'].includes(gameOutcome)
		: engineState.isDraw;
	$: isGameOver = mode === 'game' ? (gameOver || isCheckmate || isDraw) : false;

	$: winnerColor = mode === 'game' ? (gameOver ? gameWinner : (isCheckmate ? (turn === 'white' ? 'black' : 'white') : '')) : '';

	$: losingKingSquare = (() => {
		if (mode !== 'game') return null;
		if (isCheckmate) return getCheckedKingSquare(fen);
		if (gameOver && winnerColor && winnerColor !== 'draw') {
			const loserColor = winnerColor === 'white' ? 'black' : 'white';
			for (let r = 0; r < 8; r++) {
				for (let f = 0; f < 8; f++) {
					const p = board[r][f];
					if (p && p.type === 'k' && p.color === loserColor) {
						return squareName(f, r);
					}
				}
			}
		}
		return null;
	})();

	$: winningKingSquare = (() => {
		if (mode !== 'game') return null;
		if (!winnerColor || winnerColor === 'draw') return null;
		for (let r = 0; r < 8; r++) {
			for (let f = 0; f < 8; f++) {
				const p = board[r][f];
				if (p && p.type === 'k' && p.color === winnerColor) {
					return squareName(f, r);
				}
			}
		}
		return null;
	})();

	$: losingKingReason = (() => {
		if (gameOutcome === 'resignation') return 'resignation';
		if (gameOutcome === 'timeout') return 'timeout';
		return 'checkmate';
	})();

	$: modalTitle = isDraw ? 'Draw' : winnerColor === 'white' ? 'White Won' : 'Black Won';
	$: modalSubtitle = (() => {
		if (isCheckmate) return 'by checkmate';
		if (gameOutcome === 'resignation') return 'by resignation';
		if (gameOutcome === 'timeout') return 'by timeout';
		if (gameOutcome === 'stalemate') return 'by stalemate';
		if (gameOutcome === 'insufficient_material') return 'by insufficient material';
		if (gameOutcome === 'threefold_repetition') return 'by repetition';
		if (gameOutcome === 'fifty_moves') return 'by 50-move rule';
		if (isDraw) return 'by agreement';
		return 'game concluded';
	})();

	let prevFen = fen;

	// Trigger animation & sound on lastMove change
	$: if (lastMove) {
		const moveId = `${lastMove.from}-${lastMove.to}-${lastMove.san || ''}`;
		if (moveId !== prevProcessedMoveId) {
			prevProcessedMoveId = moveId;
			if (animateMoves) {
				triggerMoveEffects(lastMove.from, lastMove.to, prevFen, lastMove.san, lastMove.isCapture, lastMove.isPromotion);
			}
			prevFen = fen;
		} else {
			// Authoritative server FEN reconciliation or duplicate notification: do not re-animate or double-sound
			prevFen = fen;
		}
	} else {
		prevProcessedMoveId = '';
		prevFen = fen;
	}

	let prevGameOver = false;
	$: if (isGameOver && !prevGameOver) {
		prevGameOver = true;
		if (!isCheckmate && mode === 'game') {
			soundEffects.playGameEnd();
		}
	} else if (!isGameOver) {
		prevGameOver = false;
	}

	function getSlideDelta(fromSq: string, toSq: string) {
		if (
			typeof fromSq !== 'string' ||
			typeof toSq !== 'string' ||
			fromSq.length < 2 ||
			toSq.length < 2 ||
			fromSq[0] < 'a' ||
			fromSq[0] > 'h' ||
			toSq[0] < 'a' ||
			toSq[0] > 'h'
		) {
			return { dx: 0, dy: 0 };
		}

		const fromF = fromSq.charCodeAt(0) - 'a'.charCodeAt(0);
		const fromR = parseInt(fromSq[1], 10) - 1;
		const toF = toSq.charCodeAt(0) - 'a'.charCodeAt(0);
		const toR = parseInt(toSq[1], 10) - 1;

		let dx = (fromF - toF) * 100;
		let dy = (toR - fromR) * 100;

		if (orientation === 'black') {
			dx = -dx;
			dy = -dy;
		}

		return { dx, dy };
	}

	function triggerMoveEffects(
		fromSq: string,
		toSq: string,
		fenBefore?: string,
		san?: string,
		explicitCapture?: boolean,
		explicitPromotion?: boolean
	) {
		if (typeof fromSq !== 'string' || typeof toSq !== 'string' || fromSq.length < 2 || toSq.length < 2) {
			return;
		}

		// 1. Detect iconic move category: normal, capture, castle, en_passant, promote, check, or checkmate
		let category = detectMoveCategory(fen, fromSq, toSq, fenBefore, san, explicitPromotion);
		if (explicitPromotion && category !== 'checkmate') {
			category = 'promote';
		} else if (explicitCapture && (category === 'normal' || category === 'castle')) {
			category = 'capture';
		}
		if (mode === 'puzzle' && category === 'checkmate') {
			soundEffects.playCheck();
		} else {
			playMoveSoundByCategory(category);
		}

		// 2. Calculate primary slide animation delta
		const primaryDelta = getSlideDelta(fromSq, toSq);
		const newMap = new Map<string, { dx: number; dy: number }>();
		newMap.set(toSq, primaryDelta);

		// 3. If castling, simultaneously slide the accompanying Rook!
		if (category === 'castle') {
			let rookFrom = '';
			let rookTo = '';
			if (fromSq === 'e1' && toSq === 'g1') { rookFrom = 'h1'; rookTo = 'f1'; }
			else if (fromSq === 'e1' && toSq === 'c1') { rookFrom = 'a1'; rookTo = 'd1'; }
			else if (fromSq === 'e8' && toSq === 'g8') { rookFrom = 'h8'; rookTo = 'f8'; }
			else if (fromSq === 'e8' && toSq === 'c8') { rookFrom = 'a8'; rookTo = 'd8'; }

			if (rookFrom && rookTo) {
				newMap.set(rookTo, getSlideDelta(rookFrom, rookTo));
			}
		}

		animatingMap = newMap;
		isSliding = false;

		requestAnimationFrame(() => {
			requestAnimationFrame(() => {
				isSliding = true;
				animatingMap = new Map(Array.from(newMap.keys()).map((k) => [k, { dx: 0, dy: 0 }]));
			});
		});

		setTimeout(() => {
			animatingMap = new Map();
			isSliding = false;
		}, 200);
	}

	function toggleAudio() {
		soundMuted = !soundEffects.toggleSound();
	}

	function handleSquareClick(sq: string) {
		if (!interactive) return;

		// If playerColor is specified, you may only interact when it is your turn
		if (playerColor !== null && turn !== playerColor) return;

		// If a piece is already selected and user clicked another square
		if (selectedSquare) {
			if (selectedSquare === sq) {
				selectedSquare = null;
				return;
			}

			// Check if clicked user's own piece -> switch selection to that piece
			const [f, r] = [sq.charCodeAt(0) - 'a'.charCodeAt(0), parseInt(sq[1], 10) - 1];
			const targetPiece = board[r][f];
			if (targetPiece && targetPiece.color === turn && (playerColor === null || targetPiece.color === playerColor)) {
				selectedSquare = sq;
				dispatch('select', sq);
				return;
			}

			// If it's a legal move target, execute the move!
			if (legalTargetSquares.has(sq)) {
				const isCap = legalCaptureSquares.has(sq);
				if (isPromotionMove(fen, selectedSquare, sq)) {
					pendingPromotion = { from: selectedSquare, to: sq, isCapture: isCap };
					return;
				}

				executeMove(selectedSquare, sq, undefined, isCap);
				selectedSquare = null;
				return;
			}

			// Clicked an illegal/empty square -> deselect
			selectedSquare = null;
			return;
		}

		// No piece selected yet: select if it's the current player's piece
		const [f, r] = [sq.charCodeAt(0) - 'a'.charCodeAt(0), parseInt(sq[1], 10) - 1];
		const piece = board[r][f];
		if (piece && piece.color === turn && (playerColor === null || piece.color === playerColor)) {
			selectedSquare = sq;
			dispatch('select', sq);
		}
	}

	function handleDragStart(e: DragEvent, sq: string) {
		if (!interactive) return;
		if (playerColor !== null && turn !== playerColor) {
			e.preventDefault();
			return;
		}

		const [f, r] = [sq.charCodeAt(0) - 'a'.charCodeAt(0), parseInt(sq[1], 10) - 1];
		const piece = board[r][f];
		if (!piece || piece.color !== turn || (playerColor !== null && piece.color !== playerColor)) {
			e.preventDefault();
			return;
		}

		draggedFrom = sq;
		selectedSquare = sq;
		if (e.dataTransfer) {
			e.dataTransfer.setData('text/plain', sq);
			e.dataTransfer.effectAllowed = 'move';
		}
		dispatch('select', sq);
	}

	function handleDragEnd() {
		draggedFrom = null;
	}

	function handleDrop(e: CustomEvent<DragEvent>, targetSq: string) {
		if (!interactive) return;
		if (playerColor !== null && turn !== playerColor) {
			draggedFrom = null;
			return;
		}

		const sourceSq = e.detail.dataTransfer?.getData('text/plain') || draggedFrom || selectedSquare;
		if (!sourceSq || sourceSq === targetSq) {
			draggedFrom = null;
			return;
		}

		// Check if target is a legal move
		const legalForSource = legalTargets.length > 0 && selectedSquare === sourceSq ? legalTargets : getLegalMovesForSquare(fen, sourceSq);
		const targetMove = legalForSource.find((m) => m.to === targetSq);

		if (targetMove) {
			const isCap = targetMove.isCapture;
			if (isPromotionMove(fen, sourceSq, targetSq)) {
				pendingPromotion = { from: sourceSq, to: targetSq, isCapture: isCap };
				draggedFrom = null;
				return;
			}
			executeMove(sourceSq, targetSq, undefined, isCap);
		}

		draggedFrom = null;
		selectedSquare = null;
	}

	function executeMove(from: string, to: string, promo?: PieceType, isCapture?: boolean, isPromotion?: boolean) {
		dispatch('move', { from, to, promotion: promo, isCapture, isPromotion });
	}

	function handlePromotionSelect(event: CustomEvent<PieceType>) {
		if (pendingPromotion) {
			executeMove(pendingPromotion.from, pendingPromotion.to, event.detail, pendingPromotion.isCapture, true);
			pendingPromotion = null;
			selectedSquare = null;
		}
	}

	function squareToPercent(sq: string, isWhiteOriented: boolean): { x: number; y: number } {
		const f = sq.charCodeAt(0) - 'a'.charCodeAt(0);
		const r = parseInt(sq[1], 10) - 1;
		const x = isWhiteOriented ? (f + 0.5) * 12.5 : (7 - f + 0.5) * 12.5;
		const y = isWhiteOriented ? (7 - r + 0.5) * 12.5 : (r + 0.5) * 12.5;
		return { x, y };
	}

	// Calculate 8x8 squares in order depending on orientation
	$: ranks = orientation === 'white' ? [7, 6, 5, 4, 3, 2, 1, 0] : [0, 1, 2, 3, 4, 5, 6, 7];
	$: files = orientation === 'white' ? [0, 1, 2, 3, 4, 5, 6, 7] : [7, 6, 5, 4, 3, 2, 1, 0];
	$: effectiveDisableGameOverModal = disableGameOverModal || mode !== 'game';
</script>

<div class="relative w-full aspect-square {boardSizeClass} rounded-xl sm:rounded-2xl overflow-hidden shadow-2xl border-2 sm:border-4 border-border ring-1 ring-border/50 select-none {mode === 'game' && isCheckmate ? 'ring-2 ring-amber-400/80 animate-[boardImpact_450ms_ease-out]' : ''}">
	{#if showSoundToggle}
		<button
			class="absolute top-2 right-2 z-30 p-1.5 sm:p-2 rounded-lg bg-card/90 hover:bg-muted border border-border text-foreground transition shadow-md backdrop-blur-xs"
			on:click={toggleAudio}
			title={soundMuted ? 'Unmute Sound Effects' : 'Mute Sound Effects'}
		>
			<Icon name={soundMuted ? 'volume-x' : 'volume-2'} size={14} />
		</button>
	{/if}

	<div class="grid grid-cols-8 grid-rows-8 w-full h-full">
		{#each ranks as r, rIndex}
			{#each files as f, fIndex}
				{@const sq = squareName(f, r)}
				{@const isLight = (f + r) % 2 !== 0}
				{@const piece = board[r][f]}
				{@const isSelected = selectedSquare === sq}
				{@const isLastFrom = lastMove?.from === sq}
				{@const isLastTo = lastMove?.to === sq}
				{@const targetInfo = legalTargetMap.get(sq)}
				{@const isLegal = legalTargetSquares.has(sq)}
				{@const isCapture = legalCaptureSquares.has(sq) || (isLegal && piece !== null && piece.color !== turn)}
				{@const legalCategory = targetInfo?.category || (isCapture ? 'capture' : 'normal')}
				{@const isCheckSquare = kingInCheckSquare === sq}
				{@const anim = animatingMap.get(sq)}
				{@const showRank = fIndex === 0}
				{@const showFile = rIndex === 7}

				<ChessSquare
					file={f}
					rank={r}
					squareName={sq}
					{isLight}
					{isSelected}
					isLastMoveFrom={isLastFrom}
					isLastMoveTo={isLastTo}
					{isLegal}
					{isCapture}
					isHintSquare={hintSquare === sq}
					{legalCategory}
					isCheck={isCheckSquare && (mode !== 'game' || !isCheckmate)}
					isWinningKing={winningKingSquare === sq}
					isLosingKing={losingKingSquare === sq}
					{losingKingReason}
					isDrawKing={isDraw && piece?.type === 'k'}
					reviewClassification={reviewMove?.to === sq ? reviewMove.classification : null}
					showRankCoord={showRank}
					showFileCoord={showFile}
					{theme}
					on:click={() => handleSquareClick(sq)}
					on:drop={(e) => handleDrop(e, sq)}
				>
					{#if piece}
						<div
							class="w-full h-full"
							style={anim
								? `transform: translate(${anim.dx}%, ${anim.dy}%); transition: ${isSliding ? 'transform 180ms cubic-bezier(0.2, 0, 0.2, 1)' : 'none'}; z-index: 40; will-change: transform;`
								: ''}
						>
							<ChessPiece
								{piece}
								draggable={interactive && piece.color === turn && (playerColor === null || piece.color === playerColor)}
								isDragging={draggedFrom === sq}
								on:dragstart={(e) => handleDragStart(e, sq)}
								on:dragend={handleDragEnd}
							/>
						</div>
					{/if}
				</ChessSquare>
			{/each}
		{/each}
	</div>

	<!-- Tactical Hint Arrow Overlay (Clean gold vector arrow) -->
	{#if hintArrow && hintArrow.from && hintArrow.to}
		{@const hp1 = squareToPercent(hintArrow.from, orientation === 'white')}
		{@const hp2 = squareToPercent(hintArrow.to, orientation === 'white')}
		<svg class="absolute inset-0 w-full h-full pointer-events-none z-20 overflow-visible">
			<defs>
				<marker id="hint-target-arrow" markerWidth="6" markerHeight="6" refX="4" refY="3" orient="auto">
					<polygon points="0 0, 6 3, 0 6" fill="#f59e0b" />
				</marker>
			</defs>
			<line
				x1="{hp1.x}%"
				y1="{hp1.y}%"
				x2="{hp2.x}%"
				y2="{hp2.y}%"
				stroke="#f59e0b"
				stroke-width="5"
				stroke-linecap="round"
				marker-end="url(#hint-target-arrow)"
				opacity="0.9"
			/>
		</svg>
	{/if}

	<!-- Best Move Arrow Overlay (Clean emerald vector arrow) -->
	{#if reviewMove && reviewMove.bestMoveUci && reviewMove.bestMoveUci.length >= 4 && reviewMove.bestMoveUci !== `${reviewMove.from}${reviewMove.to}`}
		{@const bFrom = reviewMove.bestMoveUci.slice(0, 2)}
		{@const bTo = reviewMove.bestMoveUci.slice(2, 4)}
		{@const p1 = squareToPercent(bFrom, orientation === 'white')}
		{@const p2 = squareToPercent(bTo, orientation === 'white')}
		<svg class="absolute inset-0 w-full h-full pointer-events-none z-20 overflow-visible">
			<defs>
				<marker id="review-best-arrow" markerWidth="6" markerHeight="6" refX="4" refY="3" orient="auto">
					<polygon points="0 0, 6 3, 0 6" fill="#10b981" />
				</marker>
			</defs>
			<line
				x1="{p1.x}%"
				y1="{p1.y}%"
				x2="{p2.x}%"
				y2="{p2.y}%"
				stroke="#10b981"
				stroke-width="5"
				stroke-linecap="round"
				marker-end="url(#review-best-arrow)"
				opacity="0.9"
			/>
		</svg>
	{/if}

	<!-- Game Over Modal -->
	{#if isGameOver && !effectiveDisableGameOverModal && showGameOverModal}
		<div class="absolute inset-0 z-50 bg-black/75 flex items-center justify-center p-3 animate-in fade-in duration-150">
			<div class="relative bg-card border border-border rounded-xl p-6 shadow-2xl max-w-[320px] sm:max-w-[340px] w-full flex flex-col items-center text-center">
				<!-- Close 'X' button to dismiss modal and view the board freely -->
				<button
					class="absolute top-3 right-3 w-7 h-7 rounded-lg text-muted-foreground hover:text-foreground hover:bg-secondary flex items-center justify-center transition"
					on:click={() => (showGameOverModal = false)}
					title="Close and view board"
				>
					<Icon name="x" size={15} />
				</button>

				<!-- Winner Crown or Draw Emblem -->
				<div class="w-12 h-12 rounded-xl flex items-center justify-center mb-3 {isDraw ? 'bg-secondary text-foreground' : 'bg-amber-400/15 text-amber-400 border border-amber-400/30'}">
					{#if isDraw}
						<Icon name="handshake" size={24} />
					{:else}
						<Icon name="crown" size={24} className="text-amber-400" />
					{/if}
				</div>

				<!-- Result Title -->
				<h3 class="text-xl font-bold text-foreground tracking-tight">
					{modalTitle}
				</h3>

				<!-- Subtitle -->
				<p class="text-xs text-muted-foreground font-normal mt-1 mb-5">
					{modalSubtitle}
				</p>

				<!-- Actions -->
				<div class="flex flex-col gap-2 w-full">
					<a
						href="/analysis?fen={encodeURIComponent(fen)}"
						class="w-full py-2.5 px-4 bg-foreground hover:opacity-90 active:scale-[0.99] text-background font-semibold text-xs rounded-lg transition-all flex items-center justify-center gap-2 shadow-xs"
						on:click={() => dispatch('analyze')}
					>
						<Icon name="search" size={14} />
						<span>Game Review</span>
					</a>

					<div class="grid grid-cols-2 gap-2 w-full">
						<button
							class="py-2 px-3 bg-secondary hover:bg-accent text-foreground font-medium text-xs rounded-lg border border-border transition flex items-center justify-center gap-1.5 cursor-pointer"
							on:click={() => dispatch('rematch')}
						>
							<Icon name="rotate-ccw" size={13} />
							<span>Rematch</span>
						</button>
						<button
							class="py-2 px-3 bg-secondary hover:bg-accent text-foreground font-medium text-xs rounded-lg border border-border transition flex items-center justify-center gap-1.5 cursor-pointer"
							on:click={() => dispatch('newGame')}
						>
							<Icon name="zap" size={13} />
							<span>New Game</span>
						</button>
					</div>
				</div>
			</div>
		</div>
	{/if}

	<!-- Minimized Bottom Status Bar -->
	{#if isGameOver && !effectiveDisableGameOverModal && !showGameOverModal}
		<div class="absolute bottom-3 inset-x-3 z-40 bg-card border border-border shadow-xl rounded-lg py-2 px-3 flex items-center justify-between text-xs animate-in fade-in duration-150">
			<div class="flex items-center gap-2 truncate pr-2">
				{#if !isDraw}
					<div class="w-5 h-5 rounded-md bg-amber-400/15 border border-amber-400/30 flex items-center justify-center shrink-0 text-amber-400">
						<Icon name="crown" size={12} />
					</div>
				{/if}
				<span class="font-semibold text-foreground capitalize truncate">{modalTitle}</span>
				<span class="text-muted-foreground font-normal shrink-0">{modalSubtitle}</span>
			</div>
			<div class="flex items-center gap-2 shrink-0">
				<a
					href="/analysis?fen={encodeURIComponent(fen)}"
					class="px-2.5 py-1 bg-foreground text-background font-semibold text-[11px] rounded shadow-xs hover:opacity-90 transition"
				>
					Review
				</a>
				<button
					class="px-2.5 py-1 bg-secondary hover:bg-accent text-foreground font-medium text-[11px] rounded border border-border transition cursor-pointer"
					on:click={() => (showGameOverModal = true)}
				>
					Dialog
				</button>
			</div>
		</div>
	{/if}

	<!-- Promotion Dialog -->
	{#if pendingPromotion}
		<PromotionDialog color={turn} on:select={handlePromotionSelect} />
	{/if}
</div>

<style>
	@keyframes boardImpact {
		0% { transform: scale(1); }
		20% { transform: scale(0.985); }
		45% { transform: scale(1.018); }
		75% { transform: scale(0.995); }
		100% { transform: scale(1); }
	}
</style>
