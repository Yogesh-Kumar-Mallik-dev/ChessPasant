<script lang="ts">
	import { onDestroy, onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto, beforeNavigate } from '$app/navigation';
	import { Chess } from 'chess.js';
	import { api } from '$lib/api/client';
	import { authStore } from '$lib/stores/auth';
	import { gameStore, resetGameStore } from '$lib/stores/game';
	import { GameSocket } from '$lib/websocket/gameSocket';
	import ChessBoard from '$lib/components/chess/ChessBoard.svelte';
	import GameClock from '$lib/components/game/GameClock.svelte';
	import MoveList from '$lib/components/game/MoveList.svelte';
	import CapturedPieces from '$lib/components/game/CapturedPieces.svelte';
	import GameResult from '$lib/components/game/GameResult.svelte';
	import Icon from '$lib/components/icons/Icon.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import UserBadge from '$lib/components/ui/UserBadge.svelte';
	import Modal from '$lib/components/ui/Modal.svelte';
	import { INITIAL_FEN, type Color, type PieceType } from '$lib/chess/engine';
	import { soundEffects } from '$lib/audio/sounds';
	import { saveLocalGame, stageGameForReview } from '$lib/stores/localGames';

	let gameId = $page.params.gameId || '';

	let socket: GameSocket | null = null;
	let showResultModal = true;
	let showResignModal = false;
	let showOfferDrawModal = false;
	let showLeaveModal = false;
	let pendingNavigation: (() => void) | null = null;
	let allowNavigation = false;
	let flipBoard = false;
	let showMobileMoves = false;

	// Determine current user's authenticated seat (check ID, username, and query params)
	$: myPlayerColor = (() => {
		const colorParam = $page.url.searchParams.get('color');
		if (!$authStore.user) {
			if (colorParam === 'black' || colorParam === 'white') return colorParam as Color;
			return null;
		}
		const uid = $authStore.user.id;
		const uname = $authStore.user.username;

		const isWhite = !!($gameStore.whitePlayer?.userId && $gameStore.whitePlayer.userId === uid) ||
			!!(uname && $gameStore.whitePlayer?.username && $gameStore.whitePlayer.username.toLowerCase() === uname.toLowerCase());

		const isBlack = !!($gameStore.blackPlayer?.userId && $gameStore.blackPlayer.userId === uid) ||
			!!(uname && $gameStore.blackPlayer?.username && $gameStore.blackPlayer.username.toLowerCase() === uname.toLowerCase());

		if (isWhite && isBlack) {
			// In self-play / same account testing across tabs, respect ?color query parameter!
			if (colorParam === 'black' || colorParam === 'white') return colorParam as Color;
			return 'white' as Color;
		}
		if (isWhite) return 'white' as Color;
		if (isBlack) return 'black' as Color;

		// Fallback to URL parameter if assigned via matchmaking or direct match
		if (colorParam === 'black' || colorParam === 'white') return colorParam as Color;
		return null;
	})();

	$: isPlayer = myPlayerColor !== null;
	$: isSpectator = !isPlayer;

	// Visual board orientation (defaults to player's color, or 'white' for spectators)
	$: defaultOrientation = (myPlayerColor || ($page.url.searchParams.get('color') as Color) || 'white') as Color;
	$: currentOrientation = (flipBoard
		? (defaultOrientation === 'white' ? 'black' : 'white')
		: defaultOrientation) as Color;

	$: topColor = (currentOrientation === 'white' ? 'black' : 'white') as Color;
	$: bottomColor = currentOrientation;

	$: topPlayer = currentOrientation === 'white' ? $gameStore.blackPlayer : $gameStore.whitePlayer;
	$: bottomPlayer = currentOrientation === 'white' ? $gameStore.whitePlayer : $gameStore.blackPlayer;

	$: topTimeMs = currentOrientation === 'white' ? $gameStore.blackTime : $gameStore.whiteTime;
	$: bottomTimeMs = currentOrientation === 'white' ? $gameStore.whiteTime : $gameStore.blackTime;

	$: isTopTurn = $gameStore.status === 'playing' && $gameStore.turn === topColor;
	$: isBottomTurn = $gameStore.status === 'playing' && $gameStore.turn === bottomColor;
	$: isMyTurn = isPlayer && $gameStore.status === 'playing' && $gameStore.turn === myPlayerColor;

	let copiedInvite = false;
	let opponentCountdown = 60;
	let countdownInterval: any = null;
	let clockTickerInterval: any = null;
	let lastClockTick: number = Date.now();

	// Smooth local clock ticker when match is actively playing
	$: if ($gameStore.status === 'playing') {
		if (!clockTickerInterval) {
			lastClockTick = Date.now();
			clockTickerInterval = setInterval(() => {
				const now = Date.now();
				const delta = now - lastClockTick;
				lastClockTick = now;

				gameStore.update((s) => {
					if (s.status !== 'playing') return s;
					if (s.turn === 'white') {
						return { ...s, whiteTime: Math.max(0, s.whiteTime - delta) };
					} else {
						return { ...s, blackTime: Math.max(0, s.blackTime - delta) };
					}
				});
			}, 100);
		}
	} else {
		if (clockTickerInterval) {
			clearInterval(clockTickerInterval);
			clockTickerInterval = null;
		}
	}

	// Track opponent disconnection countdown
	$: if (isPlayer && !$gameStore.opponentConnected && $gameStore.status === 'playing') {
		if (!countdownInterval) {
			opponentCountdown = 60;
			countdownInterval = setInterval(() => {
				if (opponentCountdown > 0) {
					opponentCountdown--;
				} else {
					clearInterval(countdownInterval);
					countdownInterval = null;
				}
			}, 1000);
		}
	} else {
		if (countdownInterval) {
			clearInterval(countdownInterval);
			countdownInterval = null;
		}
		opponentCountdown = 60;
	}

	// Warn before leaving active game
	beforeNavigate((nav) => {
		if (allowNavigation) return;
		if (isPlayer && $gameStore.status === 'playing') {
			nav.cancel();
			if (nav.to) {
				const dest = nav.to.url.pathname + nav.to.url.search;
				pendingNavigation = () => {
					allowNavigation = true;
					goto(dest);
				};
			}
			showLeaveModal = true;
		}
	});

	function confirmLeaveMatch() {
		showLeaveModal = false;
		if (pendingNavigation) {
			const action = pendingNavigation;
			pendingNavigation = null;
			action();
		}
	}

	function handleBeforeUnload(e: BeforeUnloadEvent) {
		if (isPlayer && $gameStore.status === 'playing') {
			e.preventDefault();
			e.returnValue = '';
			return '';
		}
	}

	function copyInviteLink() {
		if (typeof window !== 'undefined') {
			navigator.clipboard.writeText(window.location.href);
			copiedInvite = true;
			setTimeout(() => {
				copiedInvite = false;
			}, 2500);
		}
	}

	// Rollback snapshot for optimistic moves
	let rollbackSnapshot: {
		fen: string;
		turn: Color;
		moves: any[];
		lastMove: any;
		isCheck: boolean;
	} | null = null;

	// Board State History navigation & replay
	// -1 signifies viewing the active live match position
	let viewingPly: number = -1;

	// Computed full history array from ply 0 (initial state) to latest move
	$: boardHistory = (() => {
		const startFen = $gameStore.initialFen || INITIAL_FEN;
		const history: {
			ply: number;
			fen: string;
			lastMove: { from: string; to: string; san?: string; isCapture?: boolean; isPromotion?: boolean } | null;
			turn: Color;
			san?: string;
		}[] = [
			{
				ply: 0,
				fen: startFen,
				lastMove: null,
				turn: (startFen.split(' ')[1] === 'b' ? 'black' : 'white') as Color,
				san: 'Start'
			}
		];

		let c = new Chess(startFen);
		const mvs = $gameStore.moves || [];
		for (let i = 0; i < mvs.length; i++) {
			const m = mvs[i];
			let fen = m.fen;
			if (!fen) {
				try {
					c.move(m.san || { from: m.from, to: m.to });
					fen = c.fen();
				} catch (_) {
					fen = c.fen();
				}
			} else {
				try {
					c = new Chess(fen);
				} catch (_) {}
			}
			history.push({
				ply: i + 1,
				fen,
				lastMove: {
					from: m.from,
					to: m.to,
					san: m.san,
					isCapture: (m as any).isCapture ?? m.san?.includes('x'),
					isPromotion: (m as any).isPromotion ?? (m.san?.includes('=') || !!(m as any).promotion)
				},
				turn: (fen.split(' ')[1] === 'w' ? 'white' : 'black') as Color,
				san: m.san
			});
		}
		return history;
	})();

	// Forceful pull to latest move: whenever either player moves, immediately snap viewingPly to -1 (live)
	let prevMovesLength = 0;
	$: if ($gameStore.moves.length !== prevMovesLength) {
		prevMovesLength = $gameStore.moves.length;
		viewingPly = -1;
	}

	$: isLiveView = viewingPly === -1 || viewingPly === boardHistory.length - 1;
	$: currentHistoryEntry = (viewingPly >= 0 && viewingPly < boardHistory.length)
		? boardHistory[viewingPly]
		: null;

	$: displayFen = currentHistoryEntry ? currentHistoryEntry.fen : $gameStore.fen;
	$: displayLastMove = currentHistoryEntry ? currentHistoryEntry.lastMove : $gameStore.lastMove;
	$: displayTurn = currentHistoryEntry ? currentHistoryEntry.turn : $gameStore.turn;

	function jumpToPly(targetPly: number) {
		if (targetPly < 0 || targetPly >= boardHistory.length - 1) {
			viewingPly = -1;
		} else {
			viewingPly = targetPly;
		}
	}

	function goToFirst() {
		jumpToPly(0);
	}

	function goToPrevious() {
		const current = viewingPly === -1 ? boardHistory.length - 1 : viewingPly;
		if (current > 0) {
			jumpToPly(current - 1);
		}
	}

	function goToNext() {
		if (viewingPly === -1) return;
		if (viewingPly < boardHistory.length - 1) {
			jumpToPly(viewingPly + 1);
		} else {
			viewingPly = -1;
		}
	}

	function goToLive() {
		viewingPly = -1;
	}

	function handleKeydown(e: KeyboardEvent) {
		const target = e.target as HTMLElement | null;
		if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable)) {
			return;
		}
		if (e.key === 'ArrowLeft') {
			e.preventDefault();
			goToPrevious();
		} else if (e.key === 'ArrowRight') {
			e.preventDefault();
			goToNext();
		}
	}

	async function getResolvedUser(): Promise<any> {
		if ($authStore.user) return $authStore.user;
		if (!$authStore.loading) return null;
		return new Promise((resolve) => {
			const unsub = authStore.subscribe((state) => {
				if (!state.loading) {
					unsub();
					resolve(state.user);
				}
			});
		});
	}

	async function syncGameFromServer() {
		try {
			const info = await api.games.get(gameId);
			if (!info) return;
			gameStore.update((s) => ({
				...s,
				fen: info.fen || s.fen,
				turn: info.turn || s.turn,
				whitePlayer: info.white || s.whitePlayer,
				blackPlayer: info.black || s.blackPlayer,
				timeControl: info.timeControl || s.timeControl,
				whiteTime: info.whiteTime !== undefined ? info.whiteTime : s.whiteTime,
				blackTime: info.blackTime !== undefined ? info.blackTime : s.blackTime,
				status: info.status || s.status,
				result: info.result !== undefined ? info.result : s.result,
				outcome: info.outcome !== undefined ? info.outcome : s.outcome,
				moves: (info.moves || []).map((m: any) => ({
					from: m.from,
					to: m.to,
					san: m.san,
					fen: m.fen
				}))
			}));
		} catch (e) {
			console.warn('Sync game from server error:', e);
		}
	}

	function handleLifecycleWake() {
		soundEffects.unlockAudio();
		if (socket && !socket.isConnected()) {
			socket.reconnectNow();
		}
		syncGameFromServer();
	}

	onMount(async () => {
		resetGameStore();

		if (typeof window !== 'undefined') {
			window.addEventListener('beforeunload', handleBeforeUnload);
			window.addEventListener('keydown', handleKeydown);
			document.addEventListener('visibilitychange', () => {
				if (document.visibilityState === 'visible') {
					handleLifecycleWake();
				}
			});
			window.addEventListener('focus', handleLifecycleWake);
			window.addEventListener('online', handleLifecycleWake);
		}

		try {
			const currentUser = await getResolvedUser();
			let info = await api.games.get(gameId);

			// If current user is logged in, not white, and black seat is open/guest, claim the black seat!
			if (
				currentUser &&
				info.white?.userId !== currentUser.id &&
				(info.black?.userId === 'guest-opponent' || !info.black?.userId)
			) {
				try {
					const joined = await api.games.join(gameId);
					if (joined) {
						if (joined.white) info.white = joined.white;
						if (joined.black) info.black = joined.black;
					}
				} catch (e) {
					console.warn('Could not join match:', e);
				}
			}

			gameStore.update((s) => ({
				...s,
				gameId: info.id,
				initialFen: info.initialFen || INITIAL_FEN,
				fen: info.fen || info.initialFen || INITIAL_FEN,
				turn: info.turn || 'white',
				whitePlayer: info.white,
				blackPlayer: info.black,
				timeControl: info.timeControl,
				whiteTime: info.whiteTime || (info.timeControl?.initial * 1000) || 300000,
				blackTime: info.blackTime || (info.timeControl?.initial * 1000) || 300000,
				status: info.status,
				result: info.result,
				outcome: info.outcome,
				moves: (info.moves || []).map((m: any) => ({
					from: m.from,
					to: m.to,
					san: m.san,
					fen: m.fen
				}))
			}));
		} catch (e) {
			console.error('Failed to load initial game:', e);
		}

		const token = typeof window !== 'undefined' ? localStorage.getItem('access_token') : null;
		socket = new GameSocket(gameId, token);

		// Handle server move error with rollback
		socket.onError((errMsg) => {
			if (rollbackSnapshot) {
				console.warn('Server rejected move, rolling back:', errMsg);
				gameStore.update((s) => ({
					...s,
					fen: rollbackSnapshot!.fen,
					turn: rollbackSnapshot!.turn,
					moves: rollbackSnapshot!.moves,
					lastMove: rollbackSnapshot!.lastMove,
					isCheck: rollbackSnapshot!.isCheck
				}));
				rollbackSnapshot = null;
				soundEffects.playIllegal();
			}
		});

		socket.connect();
	});

	onDestroy(() => {
		if (typeof window !== 'undefined') {
			window.removeEventListener('beforeunload', handleBeforeUnload);
			window.removeEventListener('keydown', handleKeydown);
			window.removeEventListener('focus', handleLifecycleWake);
			window.removeEventListener('online', handleLifecycleWake);
		}
		if (countdownInterval) {
			clearInterval(countdownInterval);
			countdownInterval = null;
		}
		if (clockTickerInterval) {
			clearInterval(clockTickerInterval);
			clockTickerInterval = null;
		}
		if (socket) {
			socket.disconnect();
			socket = null;
		}
	});

	function handleMove(event: CustomEvent<{ from: string; to: string; promotion?: PieceType }>) {
		// Forcefully pull to latest move on any move attempt
		viewingPly = -1;

		const { from, to, promotion } = event.detail;

		// Only active players on their turn can submit moves
		if (!isPlayer || !isMyTurn || $gameStore.status !== 'playing') {
			return;
		}

		// Optimistic UI update: apply locally using chess.js immediately
		try {
			const c = new Chess($gameStore.fen);
			const moveRes = c.move({
				from,
				to,
				promotion: promotion || undefined
			});

			if (moveRes) {
				rollbackSnapshot = {
					fen: $gameStore.fen,
					turn: $gameStore.turn,
					moves: [...$gameStore.moves],
					lastMove: $gameStore.lastMove,
					isCheck: $gameStore.isCheck
				};

				const nextFen = c.fen();
				const nextTurn = c.turn() === 'w' ? 'white' : 'black';
				const isCap = moveRes.flags.includes('c') || moveRes.flags.includes('e');
				const isPromo = moveRes.flags.includes('p');

				gameStore.update((s) => ({
					...s,
					fen: nextFen,
					turn: nextTurn,
					lastMove: {
						from,
						to,
						san: moveRes.san,
						isCapture: isCap,
						isPromotion: isPromo
					},
					moves: [
						...s.moves,
						{
							from,
							to,
							san: moveRes.san,
							fen: nextFen
						}
					],
					isCheck: c.inCheck()
				}));

				if (socket) {
					socket.sendMove(from, to, promotion);
				}
				if (!socket || !socket.isConnected()) {
					api.games.makeMove(gameId, { from, to, promotion }).catch((e) => {
						console.warn('HTTP fallback move submission failed:', e);
					});
				}
				return;
			}
		} catch (e) {
			console.warn('Optimistic move execution fallback to server:', e);
		}

		if (socket && socket.isConnected()) {
			socket.sendMove(from, to, promotion);
		} else {
			api.games.makeMove(gameId, { from, to, promotion }).catch((e) => {
				console.warn('HTTP move submission failed:', e);
			});
		}
	}

	function handleResign() {
		if (!isPlayer || $gameStore.status !== 'playing') return;
		showResignModal = true;
	}

	async function confirmResign() {
		showResignModal = false;
		socket?.resign();
		try {
			await api.games.resign(gameId);
		} catch (_) {}
	}

	function handleOfferDraw() {
		if (!isPlayer || $gameStore.status !== 'playing') return;
		showOfferDrawModal = true;
	}

	async function confirmOfferDraw() {
		showOfferDrawModal = false;
		socket?.offerDraw();
		try {
			await api.games.offerDraw(gameId);
		} catch (_) {}
	}

	async function handleAcceptDraw() {
		if (!isPlayer || $gameStore.status !== 'playing') return;
		socket?.acceptDraw();
		try {
			await api.games.acceptDraw(gameId);
		} catch (_) {}
	}

	async function handleDeclineDraw() {
		if (!isPlayer || $gameStore.status !== 'playing') return;
		socket?.declineDraw();
		try {
			await api.games.declineDraw(gameId);
		} catch (_) {}
	}

	function handleNewGame() {
		goto('/play/online');
	}

	function handleAnalyze() {
		if (typeof window !== 'undefined' && $gameStore.moves.length > 0) {
			const c = new Chess();
			for (const m of $gameStore.moves) {
				try {
					c.move(m.san || { from: m.from, to: m.to });
				} catch (_) {}
			}
			const whiteName = $gameStore.whitePlayer?.username || 'White';
			const blackName = $gameStore.blackPlayer?.username || 'Black';
			const resStr = $gameStore.result || '*';

			c.header(
				'Event', 'Live Match',
				'Site', 'ChessPasant',
				'Date', new Date().toISOString().slice(0, 10).replace(/-/g, '.'),
				'White', whiteName,
				'Black', blackName,
				'Result', resStr
			);
			const pgn = c.pgn();
			stageGameForReview(pgn, whiteName, blackName);
			sessionStorage.setItem('review_moves', JSON.stringify($gameStore.moves));

			// Save to local games archive so guests and users can review anytime
			saveLocalGame({
				id: gameId,
				date: new Date().toISOString(),
				event: 'Live Match',
				white: whiteName,
				black: blackName,
				result: resStr,
				outcome: $gameStore.outcome || 'finished',
				winner: $gameStore.winner,
				movesCount: $gameStore.moves.length,
				pgn,
				startFen: INITIAL_FEN
			});

			goto(`/analysis?gameId=${gameId}&review=1`);
			return;
		}
		goto(`/analysis?gameId=${gameId}&review=1`);
	}

</script>

<div class="flex-1 flex flex-col justify-center max-w-7xl mx-auto w-full px-2 py-1.5 sm:px-4 sm:py-2 lg:px-6 min-h-0 min-h-[calc(100dvh-4rem)] lg:h-[calc(100dvh-4rem)] lg:max-h-[calc(100dvh-4rem)] overflow-x-hidden overflow-y-auto">
	<div class="grid grid-cols-1 lg:grid-cols-12 gap-3 lg:gap-6 items-center justify-center my-auto min-h-0">
		
		<!-- Board Column (Hero centerpiece) -->
		<div class="lg:col-span-7 xl:col-span-8 flex flex-col items-center justify-center min-h-0 w-full">
			
			<div class="w-full max-w-[min(100%,calc(100dvh-240px),580px)] flex flex-col items-center">
				<!-- Opponent Disconnection Countdown Banner -->
				{#if isPlayer && !$gameStore.opponentConnected && $gameStore.status === 'playing'}
					<div class="w-full mb-1.5 p-2 bg-destructive/10 border border-destructive/30 rounded-xl flex items-center justify-between text-xs text-destructive animate-pulse shadow-sm">
						<div class="flex items-center gap-2 font-bold">
							<Icon name="wifi-off" size={14} />
							<span>Opponent disconnected</span>
						</div>
						<div class="font-mono text-[11px] font-bold bg-destructive/20 px-2 py-0.5 rounded border border-destructive/40">
							Claiming win in {opponentCountdown}s
						</div>
					</div>
				{/if}

				<!-- Top Player Bar (Opponent) -->
				<div class="w-full flex items-center justify-between py-1 px-1 text-sm font-semibold select-none mb-1 gap-2">
					<div class="flex items-center gap-1.5 sm:gap-2 min-w-0">
						{#if topPlayer?.username && topPlayer.username !== 'guest-opponent' && topPlayer.username !== 'Opponent'}
							<UserBadge
								username={topPlayer.username}
								avatar={topPlayer.avatar}
								rating={topPlayer.rating || 400}
								ratingCategory="blitz"
								size="sm"
								target="_blank"
							/>
						{:else}
							<div class="flex items-center gap-1.5 h-7 px-2 rounded-lg bg-secondary/50 border border-border shadow-xs text-foreground font-bold text-xs shrink-0">
								<div class="w-4 h-4 rounded bg-secondary border border-border flex items-center justify-center text-xs font-mono font-bold text-muted-foreground shadow-xs shrink-0">
									<Icon name="user" size={11} />
								</div>
								<span class="truncate max-w-[120px] sm:max-w-none">{topPlayer?.username || 'Opponent'}</span>
								<span class="text-[10px] sm:text-[11px] font-mono font-semibold px-1.5 py-0.5 rounded bg-card border border-border text-muted-foreground shrink-0">
									{topPlayer?.rating || 400}
								</span>
							</div>
						{/if}
						<CapturedPieces fen={displayFen} forColor={topColor} />
					</div>

					<GameClock timeMs={topTimeMs} isActive={isTopTurn} />
				</div>

				<!-- Chess Board -->
				<ChessBoard
					fen={displayFen}
					orientation={currentOrientation}
					turn={displayTurn}
					playerColor={isPlayer && isLiveView ? myPlayerColor : null}
					selectedSquare={isLiveView ? $gameStore.selectedSquare : null}
					lastMove={displayLastMove}
					isCheck={isLiveView ? $gameStore.isCheck : false}
					interactive={isLiveView && isPlayer && $gameStore.status === 'playing'}
					animateMoves={isLiveView}
					gameOver={$gameStore.status === 'finished'}
					gameResult={$gameStore.result || ''}
					gameOutcome={$gameStore.outcome || ''}
					gameWinner={$gameStore.winner || ''}
					disableGameOverModal={true}
					boardSizeClass="w-full"
					on:move={handleMove}
				/>

				<!-- Bottom Player Bar (Self) -->
				<div class="w-full flex items-center justify-between py-1 px-1 text-sm font-semibold select-none mt-1 gap-2">
					<div class="flex items-center gap-1.5 sm:gap-2 min-w-0">
						{#if bottomPlayer?.username && bottomPlayer.username !== 'guest-opponent'}
							<UserBadge
								username={bottomPlayer.username}
								avatar={bottomPlayer.avatar}
								rating={bottomPlayer.rating || 400}
								ratingCategory="blitz"
								size="sm"
								target="_blank"
							/>
						{:else}
							<div class="flex items-center gap-1.5 h-7 px-2 rounded-lg bg-secondary/50 border border-border shadow-xs text-foreground font-bold text-xs shrink-0">
								<div class="w-4 h-4 rounded bg-secondary border border-border flex items-center justify-center text-xs font-mono font-bold text-foreground shadow-xs shrink-0">
									<Icon name="crown" size={11} />
								</div>
								<span class="truncate max-w-[120px] sm:max-w-none">{bottomPlayer?.username || (isPlayer ? 'You' : 'White')}</span>
								<span class="text-[10px] sm:text-[11px] font-mono font-semibold px-1.5 py-0.5 rounded bg-card border border-border text-foreground shrink-0">
									{bottomPlayer?.rating || 400}
								</span>
							</div>
						{/if}
						<CapturedPieces fen={displayFen} forColor={bottomColor} />
					</div>

					<GameClock timeMs={bottomTimeMs} isActive={isBottomTurn} />
				</div>

				<!-- Board State History Navigation & Live Pull Bar -->
				<div class="w-full flex items-center justify-between gap-1.5 sm:gap-2 mt-2 px-2.5 py-1.5 bg-card/90 border border-border rounded-xl shadow-xs backdrop-blur-xs select-none">
					<div class="flex items-center gap-1">
						<button
							type="button"
							class="p-1.5 rounded-lg bg-secondary hover:bg-muted text-foreground transition disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
							on:click={goToFirst}
							disabled={boardHistory.length <= 1 || viewingPly === 0}
							title="Start position (ply 0)"
						>
							<Icon name="chevrons-left" size={15} />
						</button>
						<button
							type="button"
							class="p-1.5 rounded-lg bg-secondary hover:bg-muted text-foreground transition disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
							on:click={goToPrevious}
							disabled={boardHistory.length <= 1 || viewingPly === 0}
							title="Previous move (Left arrow)"
						>
							<Icon name="chevron-left" size={15} />
						</button>
						<button
							type="button"
							class="p-1.5 rounded-lg bg-secondary hover:bg-muted text-foreground transition disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
							on:click={goToNext}
							disabled={boardHistory.length <= 1 || isLiveView}
							title="Next move (Right arrow)"
						>
							<Icon name="chevron-right" size={15} />
						</button>
						<button
							type="button"
							class="p-1.5 rounded-lg bg-secondary hover:bg-muted text-foreground transition disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
							on:click={goToLive}
							disabled={boardHistory.length <= 1 || isLiveView}
							title="Current live position"
						>
							<Icon name="chevrons-right" size={15} />
						</button>
					</div>

					<!-- Status indicator: Live vs Historical Move -->
					<div class="flex items-center gap-2">
						{#if isLiveView}
							<div class="flex items-center gap-1.5 text-xs font-semibold text-emerald-500 bg-emerald-500/10 px-2.5 py-1 rounded-full border border-emerald-500/20">
								<span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
								<span class="text-[11px] font-bold tracking-wide">LIVE</span>
							</div>
						{:else}
							<button
								type="button"
								class="flex items-center gap-1.5 text-xs font-bold text-amber-500 hover:text-amber-400 bg-amber-500/10 hover:bg-amber-500/20 px-2.5 py-1 rounded-full border border-amber-500/30 transition shadow-xs cursor-pointer animate-pulse"
								on:click={goToLive}
								title="Click to jump to live position"
							>
								<Icon name="rotate-ccw" size={12} />
								<span class="text-[11px]">Move {viewingPly} / {boardHistory.length - 1} &bull; Return to Live</span>
							</button>
						{/if}
					</div>
				</div>

				<!-- Mobile Quick Action Bar -->
				<div class="lg:hidden w-full flex items-center justify-between gap-1.5 mt-2 px-2 py-1.5 bg-card border border-border rounded-xl shadow-md">
					{#if $gameStore.status === 'playing'}
						{#if isPlayer}
							<button
								class="flex-1 py-1.5 px-2 bg-secondary hover:bg-muted text-foreground font-semibold text-[11px] rounded-lg transition border border-border flex items-center justify-center gap-1 disabled:opacity-50"
								on:click={handleOfferDraw}
								disabled={$gameStore.drawOfferBy === myPlayerColor}
							>
								<Icon name="handshake" size={13} className="text-muted-foreground" />
								<span>{$gameStore.drawOfferBy === myPlayerColor ? 'Offered' : 'Draw'}</span>
							</button>

							<button
								class="flex-1 py-1.5 px-2 bg-secondary hover:bg-destructive/10 hover:text-destructive text-foreground font-semibold text-[11px] rounded-lg transition border border-border flex items-center justify-center gap-1"
								on:click={handleResign}
							>
								<Icon name="flag" size={13} className="text-destructive" />
								<span>Resign</span>
							</button>
						{/if}
						<button
							class="py-1.5 px-2.5 bg-secondary hover:bg-muted text-foreground font-semibold text-[11px] rounded-lg transition border border-border flex items-center justify-center gap-1"
							on:click={() => (flipBoard = !flipBoard)}
							title="Flip Board"
						>
							<Icon name="rotate-cw" size={13} />
						</button>
						<button
							class="py-1.5 px-2.5 bg-secondary hover:bg-muted text-foreground font-semibold text-[11px] rounded-lg transition border border-border flex items-center justify-center gap-1"
							on:click={() => (showMobileMoves = true)}
						>
							<Icon name="play" size={12} className="text-muted-foreground" />
							<span class="tabular-nums font-mono">{$gameStore.moves.length}</span>
						</button>
					{:else}
						<button
							class="flex-1 py-1.5 px-2 bg-foreground text-background font-bold text-[11px] uppercase tracking-wider rounded-lg transition flex items-center justify-center gap-1 shadow-xs"
							on:click={handleAnalyze}
						>
							<Icon name="search" size={13} />
							<span>Review</span>
						</button>
						<button
							class="flex-1 py-1.5 px-2 bg-secondary hover:bg-muted text-foreground font-semibold text-[11px] rounded-lg transition flex items-center justify-center gap-1 border border-border"
							on:click={handleNewGame}
						>
							<Icon name="zap" size={13} />
							<span>New Match</span>
						</button>
						<button
							class="py-1.5 px-2.5 bg-secondary hover:bg-muted text-foreground font-semibold text-[11px] rounded-lg transition border border-border flex items-center justify-center gap-1"
							on:click={() => (showMobileMoves = true)}
						>
							<Icon name="play" size={12} className="text-muted-foreground" />
							<span class="tabular-nums font-mono">{$gameStore.moves.length}</span>
						</button>
					{/if}
				</div>
			</div>

		</div>

		<!-- Right Panel: HUD, Move Ledger & Actions (Desktop) -->
		<div class="hidden lg:flex lg:col-span-5 xl:col-span-4 w-full flex-col h-[min(calc(100dvh-110px),640px)] bg-card border border-border rounded-xl overflow-hidden shadow-lg">
			
			<!-- HUD Header -->
			<div class="p-3 border-b border-border bg-secondary/40 flex items-center justify-between">
				<div class="flex items-center gap-2.5 text-xs font-bold">
					<span class="w-2 h-2 rounded-full {$gameStore.connectionStatus === 'connected' ? 'bg-foreground' : 'bg-destructive animate-ping'}"></span>
					<span class="font-mono text-foreground tabular-nums">
						{$gameStore.timeControl ? `${$gameStore.timeControl.initial / 60}+${$gameStore.timeControl.increment}` : '5+0'}
					</span>
					<span class="text-muted-foreground">•</span>
					<span class="uppercase tracking-wider text-[10px] font-mono font-extrabold {$gameStore.status === 'playing' ? 'text-foreground' : 'text-muted-foreground'}">
						{$gameStore.status}
					</span>
				</div>

				<button
					class="p-1.5 rounded-lg text-muted-foreground hover:text-foreground hover:bg-muted transition flex items-center gap-1 text-xs font-medium"
					on:click={() => (flipBoard = !flipBoard)}
					title="Flip Board View"
				>
					<Icon name="rotate-cw" size={13} />
					<span class="text-[11px] font-mono">Flip</span>
				</button>
			</div>

			<!-- Challenge Invite Link Banner -->
			{#if $gameStore.blackPlayer?.userId === 'guest-opponent' && $gameStore.status === 'playing'}
				<div class="p-3 bg-secondary/60 border-b border-border flex items-center justify-between text-xs animate-in fade-in duration-150">
					<div class="flex items-center gap-2 text-foreground font-semibold">
						<Icon name="sparkles" size={15} />
						<span>Share Link to Play</span>
					</div>
					<Button
						variant="primary"
						size="sm"
						className="text-xs"
						on:click={copyInviteLink}
					>
						{copiedInvite ? 'Copied Link!' : 'Copy Link'}
					</Button>
				</div>
			{/if}

			<!-- Draw Offer Banner -->
			{#if isPlayer && $gameStore.drawOfferBy && $gameStore.drawOfferBy !== myPlayerColor}
				<div class="p-3 bg-secondary/80 border-b border-border flex items-center justify-between text-xs animate-in fade-in duration-150">
					<div class="flex items-center gap-2 text-foreground font-semibold">
						<Icon name="handshake" size={16} />
						<span>Opponent offers draw</span>
					</div>
					<div class="flex gap-1.5">
						<Button
							variant="primary"
							size="sm"
							className="text-xs"
							on:click={handleAcceptDraw}
						>
							Accept
						</Button>
						<Button
							variant="outline"
							size="sm"
							className="text-xs"
							on:click={handleDeclineDraw}
						>
							Decline
						</Button>
					</div>
				</div>
			{/if}

			<!-- Move History Ledger -->
			<div class="flex-1 overflow-hidden p-1">
				<MoveList
					moves={$gameStore.moves}
					activePly={viewingPly === -1 ? boardHistory.length - 1 : viewingPly}
					whiteName={$gameStore.whitePlayer?.username || 'White'}
					blackName={$gameStore.blackPlayer?.username || 'Black'}
					on:selectPly={(e) => jumpToPly(e.detail)}
				/>
			</div>

			<!-- Action Controls -->
			<div class="p-3.5 border-t border-border bg-secondary/20 flex gap-2">
				{#if $gameStore.status === 'playing'}
					{#if isPlayer}
						<Button
							variant="secondary"
							size="default"
							className="flex-1 text-xs"
							on:click={handleOfferDraw}
							disabled={$gameStore.drawOfferBy === myPlayerColor}
						>
							<Icon name="handshake" size={14} className="text-muted-foreground" />
							<span>{$gameStore.drawOfferBy === myPlayerColor ? 'Draw Offered' : 'Offer Draw'}</span>
						</Button>

						<Button
							variant="outline"
							size="default"
							className="flex-1 text-xs hover:text-destructive hover:border-destructive/40"
							on:click={handleResign}
						>
							<Icon name="flag" size={14} className="text-destructive" />
							<span>Resign</span>
						</Button>
					{:else}
						<div class="flex-1 py-2.5 bg-secondary text-muted-foreground text-center text-xs font-medium rounded-lg border border-border flex items-center justify-center gap-2">
							<Icon name="user" size={14} />
							<span>Spectating Match</span>
						</div>
					{/if}
				{:else}
					<div class="flex flex-col gap-2 w-full">
						<Button
							variant="primary"
							size="default"
							className="w-full text-xs font-bold uppercase tracking-wider"
							on:click={handleAnalyze}
						>
							<Icon name="search" size={14} />
							<span>Game Review</span>
						</Button>

						<div class="grid grid-cols-2 gap-2 w-full">
							<Button
								variant="secondary"
								size="sm"
								className="text-xs"
								on:click={() => (showResultModal = true)}
							>
								<span>View Result</span>
							</Button>
							<Button
								variant="outline"
								size="sm"
								className="text-xs"
								on:click={handleNewGame}
							>
								<Icon name="zap" size={13} />
								<span>New Match</span>
							</Button>
						</div>
					</div>
				{/if}
			</div>

		</div>

	</div>
</div>

<!-- End Game Modal -->
{#if $gameStore.status === 'finished' && showResultModal}
	<GameResult
		result={$gameStore.result || '*'}
		outcome={$gameStore.outcome || ''}
		winner={$gameStore.winner || ''}
		playerColor={myPlayerColor || 'white'}
		ratingDiff={myPlayerColor === 'white' ? $gameStore.whiteDiff : myPlayerColor === 'black' ? $gameStore.blackDiff : null}
		on:newGame={handleNewGame}
		on:analyze={handleAnalyze}
		on:close={() => (showResultModal = false)}
	/>
{/if}

<!-- Custom Resign Confirmation Modal -->
<Modal
	isOpen={showResignModal}
	title="Concede & Resign?"
	description="Are you sure you want to resign this match? This will immediately conclude the game as a loss."
	icon="flag"
	iconBg="bg-rose-500/15 ring-1 ring-rose-500/30"
	iconColor="text-rose-400"
	confirmText="Yes, Resign"
	confirmVariant="danger"
	cancelText="Keep Playing"
	on:confirm={confirmResign}
	on:cancel={() => (showResignModal = false)}
	on:close={() => (showResignModal = false)}
/>

<!-- Custom Leave Match Warning Modal -->
<Modal
	isOpen={showLeaveModal}
	title="Leave Active Match?"
	description="You have a live online match in progress! If you leave now, you will have 60 seconds to reconnect before forfeiting by abandonment."
	icon="timer"
	iconBg="bg-amber-500/15 ring-1 ring-amber-500/30"
	iconColor="text-amber-400"
	confirmText="Leave Anyway"
	confirmVariant="warning"
	cancelText="Stay & Play"
	on:confirm={confirmLeaveMatch}
	on:cancel={() => {
		showLeaveModal = false;
		pendingNavigation = null;
	}}
	on:close={() => {
		showLeaveModal = false;
		pendingNavigation = null;
	}}
/>

<!-- Custom Draw Offer Modal (Received) -->
<Modal
	isOpen={isPlayer && !!$gameStore.drawOfferBy && $gameStore.drawOfferBy !== myPlayerColor}
	title="Draw Offered"
	description="Your opponent is proposing a mutual draw. Do you wish to accept and share the points?"
	icon="handshake"
	iconBg="bg-amber-500/15 ring-1 ring-amber-500/30"
	iconColor="text-amber-400"
	confirmText="Accept Draw"
	confirmVariant="primary"
	cancelText="Decline"
	on:confirm={handleAcceptDraw}
	on:cancel={handleDeclineDraw}
	on:close={handleDeclineDraw}
/>

<!-- Custom Offer Draw Confirmation Modal (Initiating) -->
<Modal
	isOpen={showOfferDrawModal}
	title="Propose a Draw?"
	description="Are you sure you want to offer a mutual draw to your opponent?"
	icon="handshake"
	iconBg="bg-amber-500/15 ring-1 ring-amber-500/30"
	iconColor="text-amber-400"
	confirmText="Offer Draw"
	confirmVariant="warning"
	cancelText="Keep Playing"
	on:confirm={confirmOfferDraw}
	on:cancel={() => (showOfferDrawModal = false)}
	on:close={() => (showOfferDrawModal = false)}
/>

<!-- Mobile Move History Modal -->
<Modal
	isOpen={showMobileMoves}
	title="Move History ({$gameStore.moves.length} moves)"
	on:close={() => (showMobileMoves = false)}
>
	<div class="max-h-72 overflow-y-auto p-1">
		<MoveList
			moves={$gameStore.moves}
			activePly={viewingPly === -1 ? boardHistory.length - 1 : viewingPly}
			whiteName={$gameStore.whitePlayer?.username || 'White'}
			blackName={$gameStore.blackPlayer?.username || 'Black'}
			on:selectPly={(e) => {
				jumpToPly(e.detail);
				showMobileMoves = false;
			}}
		/>
	</div>
</Modal>

