<script lang="ts">
	import { onMount } from 'svelte';
	import { Chess } from 'chess.js';
	import { goto } from '$app/navigation';
	import Icon from '$lib/components/icons/Icon.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import Badge from '$lib/components/ui/Badge.svelte';
	import Card from '$lib/components/ui/Card.svelte';
	import ChessBoard from '$lib/components/chess/ChessBoard.svelte';
	import UserBadge from '$lib/components/ui/UserBadge.svelte';
	import { INITIAL_FEN, executeMoveClient, type Color, type PieceType } from '$lib/chess/engine';
	import { soundEffects } from '$lib/audio/sounds';
	import { isNativeOrAppEnvironment } from '$lib/config';
	import { authStore } from '$lib/stores/auth';
	import { api } from '$lib/api/client';

	// Time control pairing presets for 1-tap quick play
	interface Preset {
		label: string;
		initial: number;
		increment: number;
		type: string;
		icon: 'zap' | 'flame' | 'timer' | 'hourglass';
		popular?: boolean;
	}

	const quickPresets: Preset[] = [
		{ label: '1 min', initial: 60, increment: 0, type: 'Bullet', icon: 'zap' },
		{ label: '2 | 1', initial: 120, increment: 1, type: 'Bullet', icon: 'zap' },
		{ label: '3 min', initial: 180, increment: 0, type: 'Blitz', icon: 'flame', popular: true },
		{ label: '3 | 2', initial: 180, increment: 2, type: 'Blitz', icon: 'flame' },
		{ label: '5 min', initial: 300, increment: 0, type: 'Blitz', icon: 'flame' },
		{ label: '10 min', initial: 600, increment: 0, type: 'Rapid', icon: 'timer' },
		{ label: '15 | 10', initial: 900, increment: 10, type: 'Rapid', icon: 'timer' },
		{ label: '30 min', initial: 1800, increment: 0, type: 'Classical', icon: 'hourglass' }
	];

	// Active game and recent matches state
	let activeOngoingGame: any = null;
	let recentGames: any[] = [];
	let loadingRecent = false;

	// Right widget mode: 'daily' (Daily Puzzle) or 'quick' (Interactive Board)
	let widgetTab: 'daily' | 'quick' = 'daily';

	// Daily Puzzle State
	let dailyPuzzle: any = null;
	let dailyFen = INITIAL_FEN;
	let dailyOrientation: Color = 'white';
	let dailyTurn: Color = 'white';
	let dailyLastMove: { from: string; to: string; san?: string; isCapture?: boolean; isPromotion?: boolean } | null = null;
	let dailyStatusMessage = "Today's Tactical Workout";
	let dailyStatusType: 'info' | 'success' | 'error' = 'info';
	let dailySolutionIndex = 0;
	let dailySolved = false;
	let dailyAnimating = false;

	// Interactive Free Play Board State
	let heroChess = new Chess();
	let heroFen = INITIAL_FEN;
	let heroTurn: Color = 'white';
	let heroLastMove: { from: string; to: string; san?: string; isCapture?: boolean; isPromotion?: boolean } | null = null;
	let heroMovesCount = 0;

	onMount(async () => {
		// Load active game and recent games if user is logged in
		if ($authStore.user) {
			try {
				const ag = await api.games.getActive();
				if (ag && ag.status === 'playing') {
					activeOngoingGame = ag;
				}
			} catch (_) {}

			try {
				loadingRecent = true;
				const games = await api.games.list({ limit: 4 });
				if (Array.isArray(games)) {
					recentGames = games.filter((g) => g.status !== 'waiting' && g.status !== 'playing');
				}
			} catch (_) {
			} finally {
				loadingRecent = false;
			}
		}

		// Load Daily Puzzle for the widget
		try {
			const p = await api.puzzles.getDaily();
			if (p && p.fen) {
				dailyPuzzle = p;
				dailyFen = p.fen;
				const parts = p.fen.split(' ');
				dailyTurn = parts[1] === 'w' ? 'white' : 'black';
				dailyOrientation = dailyTurn;

				// Fetch solution in background for responsive verification
				if (!p.solution || p.solution.length === 0) {
					api.puzzles.getSolution(p.id).then((solRes) => {
						if (dailyPuzzle && dailyPuzzle.id === p.id && solRes?.solution) {
							dailyPuzzle.solution = solRes.solution;
						}
					}).catch(() => {});
				}
			}
		} catch (_) {
			// Fallback to quick interactive board if daily puzzle fails to load
			widgetTab = 'quick';
		}
	});

	// Quick 1-tap matchmaking navigation
	function handleQuickPlay(preset: Preset) {
		if ($authStore.user) {
			goto(`/play/online?initial=${preset.initial}&increment=${preset.increment}&autostart=1`);
		} else {
			goto(`/play/online?initial=${preset.initial}&increment=${preset.increment}`);
		}
	}

	// Interactive Hero Board move handler
	function handleHeroMove(event: CustomEvent<{ from: string; to: string; promotion?: PieceType }>) {
		const { from, to, promotion } = event.detail;
		try {
			const m = heroChess.move({ from, to, promotion: promotion || 'q' });
			if (m) {
				heroFen = heroChess.fen();
				heroTurn = heroChess.turn() === 'w' ? 'white' : 'black';
				heroLastMove = { from, to, san: m.san, isCapture: m.captured !== undefined };
				heroMovesCount++;

				// Auto-respond with quick reply
				if (!heroChess.isGameOver()) {
					setTimeout(() => {
						const legalMoves = heroChess.moves({ verbose: true });
						if (legalMoves.length > 0) {
							const capture = legalMoves.find((lm) => lm.captured) || legalMoves[Math.floor(Math.random() * legalMoves.length)];
							heroChess.move(capture);
							heroFen = heroChess.fen();
							heroTurn = heroChess.turn() === 'w' ? 'white' : 'black';
							heroLastMove = { from: capture.from, to: capture.to, san: capture.san, isCapture: !!capture.captured };
							heroMovesCount++;
						}
					}, 320);
				}
			}
		} catch (e) {
			console.warn('Hero move invalid:', e);
		}
	}

	function resetHeroBoard() {
		heroChess = new Chess();
		heroFen = INITIAL_FEN;
		heroTurn = 'white';
		heroLastMove = null;
		heroMovesCount = 0;
		soundEffects.playGameStart();
	}

	// Daily puzzle widget move handler
	async function handleDailyMove(event: CustomEvent<{ from: string; to: string; promotion?: PieceType }>) {
		if (!dailyPuzzle || dailySolved || dailyAnimating) return;
		const { from, to, promotion } = event.detail;

		const uciMove = `${from}${to}${promotion || ''}`;
		let expectedMove = '';
		if (dailyPuzzle.solution && dailyPuzzle.solution.length > dailySolutionIndex) {
			expectedMove = dailyPuzzle.solution[dailySolutionIndex];
		}

		const isMoveMatch = expectedMove && (
			expectedMove.toLowerCase() === uciMove.toLowerCase() ||
			expectedMove.toLowerCase().startsWith(uciMove.toLowerCase())
		);

		if (isMoveMatch) {
			// Apply user's correct move locally
			const nextResult = executeMoveClient(dailyFen, from, to, promotion);
			if (nextResult && nextResult.valid) {
				dailyFen = nextResult.newFen;
				dailyTurn = nextResult.turn;
				dailyLastMove = { from, to, san: nextResult.san, isCapture: nextResult.isCapture };
				dailySolutionIndex++;
				if (nextResult.isCapture) {
					soundEffects.playCapture();
				} else {
					soundEffects.playNormalMove();
				}

				// Check if puzzle is finished or opponent responds
				if (dailyPuzzle.solution && dailySolutionIndex >= dailyPuzzle.solution.length) {
					dailySolved = true;
					dailyStatusMessage = 'Splendid! Puzzle solved correctly.';
					dailyStatusType = 'success';
					soundEffects.playGameEnd();
					return;
				}

				// Opponent's automatic response move
				if (dailyPuzzle.solution && dailySolutionIndex < dailyPuzzle.solution.length) {
					dailyStatusMessage = 'Best move! Opponent replying...';
					dailyStatusType = 'info';
					dailyAnimating = true;
					const opponentUci = dailyPuzzle.solution[dailySolutionIndex];
					const oppFrom = opponentUci.slice(0, 2);
					const oppTo = opponentUci.slice(2, 4);
					const oppProm = (opponentUci.length > 4 ? opponentUci.slice(4, 5) : undefined) as PieceType | undefined;

					setTimeout(() => {
						const oppResult = executeMoveClient(dailyFen, oppFrom, oppTo, oppProm);
						if (oppResult && oppResult.valid) {
							dailyFen = oppResult.newFen;
							dailyTurn = oppResult.turn;
							dailyLastMove = { from: oppFrom, to: oppTo, san: oppResult.san, isCapture: oppResult.isCapture };
							dailySolutionIndex++;
							if (oppResult.isCapture) {
								soundEffects.playCapture();
							} else {
								soundEffects.playNormalMove();
							}
							dailyStatusMessage = 'Your turn. Keep calculating!';
							dailyStatusType = 'info';
						}
						dailyAnimating = false;
					}, 380);
				}
			}
		} else {
			// Explicitly show player's attempted move on the board, then revert after displaying feedback
			const wrongResult = executeMoveClient(dailyFen, from, to, promotion);
			if (wrongResult && wrongResult.valid) {
				const prevFen = dailyFen;
				const prevTurn = dailyTurn;
				const prevLastMove = dailyLastMove;

				dailyFen = wrongResult.newFen;
				dailyTurn = wrongResult.turn;
				dailyLastMove = { from, to, san: wrongResult.san, isCapture: wrongResult.isCapture };
				soundEffects.playIllegal();
				dailyStatusMessage = `Incorrect: ${wrongResult.san} is not optimal. Retracting...`;
				dailyStatusType = 'error';
				dailyAnimating = true;

				setTimeout(() => {
					dailyFen = prevFen;
					dailyTurn = prevTurn;
					dailyLastMove = prevLastMove;
					dailyStatusMessage = 'Not the best move. Try again!';
					dailyAnimating = false;
				}, 800);
			} else {
				soundEffects.playIllegal();
				dailyStatusMessage = 'Illegal move. Try again!';
				dailyStatusType = 'error';
			}
		}
	}

	function resetDailyPuzzle() {
		if (!dailyPuzzle) return;
		dailyAnimating = false;
		dailyFen = dailyPuzzle.fen;
		const parts = dailyPuzzle.fen.split(' ');
		dailyTurn = parts[1] === 'w' ? 'white' : 'black';
		dailyOrientation = dailyTurn;
		dailySolutionIndex = 0;
		dailySolved = false;
		dailyLastMove = null;
		dailyStatusMessage = "Today's Tactical Workout";
		dailyStatusType = 'info';
		soundEffects.playGameStart();
	}
</script>

<div class="relative flex-1 max-w-7xl mx-auto w-full px-3 sm:px-6 py-4 sm:py-6 lg:py-8 flex flex-col gap-6">

	<!-- 1. Player Hub Bar / Native Platform Header -->
	<div class="surface-panel rounded-2xl p-4 sm:p-5 flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4 shadow-sm">
		<!-- Left: Profile / Guest Status -->
		<div class="flex items-center gap-3.5">
			{#if $authStore.user}
				<div class="w-12 h-12 rounded-xl bg-secondary border border-border flex items-center justify-center overflow-hidden shrink-0 shadow-xs">
					{#if $authStore.user.avatar}
						<img src={$authStore.user.avatar} alt={$authStore.user.username} class="w-full h-full object-cover" />
					{:else}
						<div class="font-bold text-foreground text-lg uppercase">
							{$authStore.user.username.slice(0, 2)}
						</div>
					{/if}
				</div>
				<div>
					<div class="flex items-center gap-2">
						<span class="text-base sm:text-lg font-bold text-foreground tracking-tight">
							{$authStore.user.username}
						</span>
						<span class="inline-block w-2 h-2 rounded-full bg-emerald-500 animate-pulse" title="Online"></span>
					</div>
					<div class="text-xs text-muted-foreground flex items-center gap-2">
						<span>Competitive Chess Hub</span>
						<span>•</span>
						<a href="/profile/{$authStore.user.username}" class="hover:text-foreground transition underline underline-offset-2">
							View Profile
						</a>
					</div>
				</div>
			{:else}
				<div class="w-12 h-12 rounded-xl bg-secondary border border-border flex items-center justify-center shrink-0 shadow-xs text-muted-foreground">
					<Icon name="user" size={24} />
				</div>
				<div>
					<div class="text-base sm:text-lg font-bold text-foreground tracking-tight">
						Guest Player
					</div>
					<div class="text-xs text-muted-foreground">
						Sign in to track Elo ratings and match history
					</div>
				</div>
			{/if}
		</div>

		<!-- Right: Rating Pills (Interactive) or Guest Quick Actions -->
		{#if $authStore.user}
			<div class="flex items-center gap-2 overflow-x-auto pb-1 md:pb-0 scrollbar-none">
				<div class="flex items-center gap-2 bg-secondary/60 border border-border rounded-xl px-3 py-1.5 shrink-0">
					<Icon name="zap" size={14} className="text-foreground" />
					<div class="text-left">
						<div class="text-[10px] text-muted-foreground uppercase font-semibold leading-none">Bullet</div>
						<div class="text-xs font-mono font-bold text-foreground leading-tight mt-0.5">
							{$authStore.ratings?.bullet || 400}
						</div>
					</div>
				</div>

				<div class="flex items-center gap-2 bg-secondary/60 border border-border rounded-xl px-3 py-1.5 shrink-0">
					<Icon name="flame" size={14} className="text-foreground" />
					<div class="text-left">
						<div class="text-[10px] text-muted-foreground uppercase font-semibold leading-none">Blitz</div>
						<div class="text-xs font-mono font-bold text-foreground leading-tight mt-0.5">
							{$authStore.ratings?.blitz || 400}
						</div>
					</div>
				</div>

				<div class="flex items-center gap-2 bg-secondary/60 border border-border rounded-xl px-3 py-1.5 shrink-0">
					<Icon name="timer" size={14} className="text-foreground" />
					<div class="text-left">
						<div class="text-[10px] text-muted-foreground uppercase font-semibold leading-none">Rapid</div>
						<div class="text-xs font-mono font-bold text-foreground leading-tight mt-0.5">
							{$authStore.ratings?.rapid || 400}
						</div>
					</div>
				</div>

				<div class="flex items-center gap-2 bg-secondary/60 border border-border rounded-xl px-3 py-1.5 shrink-0">
					<Icon name="puzzle" size={14} className="text-foreground" />
					<div class="text-left">
						<div class="text-[10px] text-muted-foreground uppercase font-semibold leading-none">Tactics</div>
						<div class="text-xs font-mono font-bold text-foreground leading-tight mt-0.5">
							{$authStore.ratings?.puzzles || 400}
						</div>
					</div>
				</div>
			</div>
		{:else}
			<div class="flex items-center gap-2.5">
				<a href="/login" class="flex-1 sm:flex-initial">
					<Button variant="outline" size="sm" className="w-full">
						Log In
					</Button>
				</a>
				<a href="/register" class="flex-1 sm:flex-initial">
					<Button variant="primary" size="sm" className="w-full">
						Play Free
					</Button>
				</a>
				{#if !isNativeOrAppEnvironment()}
					<a href="/download" class="hidden sm:inline-block">
						<Button variant="ghost" size="sm" className="text-muted-foreground hover:text-foreground">
							<Icon name="download" size={14} />
							<span>Get App</span>
						</Button>
					</a>
				{/if}
			</div>
		{/if}
	</div>

	<!-- 2. Active Match Warning Banner (if in progress) -->
	{#if activeOngoingGame}
		<div class="p-4 bg-amber-500/10 border border-amber-500/30 rounded-2xl flex flex-col sm:flex-row items-center justify-between gap-4 shadow-sm">
			<div class="flex items-center gap-3">
				<div class="w-10 h-10 rounded-xl bg-amber-500/20 text-amber-500 flex items-center justify-center font-bold shrink-0">
					<Icon name="swords" size={20} />
				</div>
				<div>
					<div class="text-sm font-bold text-foreground flex items-center gap-2">
						<span>Active Match in Progress</span>
						<span class="inline-block w-2 h-2 rounded-full bg-amber-500 animate-ping"></span>
					</div>
					<div class="text-xs text-muted-foreground">
						You have an ongoing game. Return to the board to avoid clock forfeiture.
					</div>
				</div>
			</div>
			<div class="flex items-center gap-2 w-full sm:w-auto">
				<Button
					variant="outline"
					size="sm"
					className="flex-1 sm:flex-initial text-destructive border-destructive/30 hover:bg-destructive/10"
					on:click={async () => {
						if (activeOngoingGame) {
							try {
								await api.games.resign(activeOngoingGame.id);
							} catch (_) {}
							activeOngoingGame = null;
						}
					}}
				>
					Forfeit
				</Button>
				<Button
					variant="primary"
					size="sm"
					className="flex-1 sm:flex-initial"
					on:click={() => goto(`/game/${activeOngoingGame.id}`)}
				>
					Resume Game
				</Button>
			</div>
		</div>
	{/if}

	<!-- 3. Primary Native Command Grid (Two-Column Desktop, Stacked Mobile) -->
	<div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">

		<!-- Left / Center Column (7 Cols on LG): Quick Play Matrix & Modes -->
		<div class="lg:col-span-7 flex flex-col gap-6">

			<!-- Quick Play Matchmaking Matrix (1-Tap Pairing) -->
			<div class="surface-panel rounded-2xl p-5 shadow-sm">
				<div class="flex items-center justify-between mb-4 pb-3 border-b border-border">
					<div class="flex items-center gap-2">
						<div class="w-7 h-7 rounded-lg bg-secondary flex items-center justify-center text-foreground">
							<Icon name="zap" size={15} />
						</div>
						<h2 class="text-base font-bold text-foreground tracking-tight">Quick Pairing</h2>
					</div>
					<a href="/play/online" class="text-xs font-semibold text-muted-foreground hover:text-foreground flex items-center gap-1 transition">
						<span>Custom Game</span>
						<Icon name="chevron-right" size={12} />
					</a>
				</div>

				<!-- 8-Preset 1-Tap Grid -->
				<div class="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
					{#each quickPresets as preset}
						<button
							class="surface-panel rounded-xl p-3 flex flex-col items-center justify-center gap-1 text-center hover:border-foreground/40 hover:bg-secondary/40 active:scale-[0.98] transition cursor-pointer relative group"
							on:click={() => handleQuickPlay(preset)}
							title="Queue for {preset.label} {preset.type}"
						>
							{#if preset.popular}
								<span class="absolute -top-1.5 right-2 px-1.5 py-0.2 text-[9px] font-mono font-bold uppercase rounded bg-foreground text-background shadow-xs">
									Popular
								</span>
							{/if}
							<div class="text-muted-foreground group-hover:text-foreground transition">
								<Icon name={preset.icon} size={16} />
							</div>
							<div class="text-sm font-black font-mono text-foreground tracking-tight">
								{preset.label}
							</div>
							<div class="text-[10px] text-muted-foreground uppercase font-semibold tracking-wider">
								{preset.type}
							</div>
						</button>
					{/each}
				</div>
			</div>

			<!-- Core Play Modes (Native Action Hub) -->
			<div class="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
				<!-- 1. Play Online -->
				<a href="/play/online" class="group block">
					<div class="surface-panel rounded-2xl p-4.5 hover:border-foreground/40 transition flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-secondary flex items-center justify-center text-foreground shrink-0 border border-border group-hover:scale-105 transition-transform">
							<Icon name="zap" size={22} />
						</div>
						<div class="flex-1 min-w-0">
							<div class="flex items-center justify-between">
								<h3 class="text-sm font-bold text-foreground">Play Online</h3>
								<Icon name="chevron-right" size={14} className="text-muted-foreground group-hover:text-foreground transition" />
							</div>
							<p class="text-xs text-muted-foreground line-clamp-1 mt-0.5">
								Ranked live matches across all tiers
							</p>
						</div>
					</div>
				</a>

				<!-- 2. Spar with Bot -->
				<a href="/play" class="group block">
					<div class="surface-panel rounded-2xl p-4.5 hover:border-foreground/40 transition flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-secondary flex items-center justify-center text-foreground shrink-0 border border-border group-hover:scale-105 transition-transform">
							<Icon name="swords" size={22} />
						</div>
						<div class="flex-1 min-w-0">
							<div class="flex items-center justify-between">
								<h3 class="text-sm font-bold text-foreground">Spar with Bot</h3>
								<Icon name="chevron-right" size={14} className="text-muted-foreground group-hover:text-foreground transition" />
							</div>
							<p class="text-xs text-muted-foreground line-clamp-1 mt-0.5">
								Stockfish engine from 400 to 2000 Elo
							</p>
						</div>
					</div>
				</a>

				<!-- 3. Daily Tactics Lab -->
				<a href="/puzzles" class="group block">
					<div class="surface-panel rounded-2xl p-4.5 hover:border-foreground/40 transition flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-secondary flex items-center justify-center text-foreground shrink-0 border border-border group-hover:scale-105 transition-transform">
							<Icon name="puzzle" size={22} />
						</div>
						<div class="flex-1 min-w-0">
							<div class="flex items-center justify-between">
								<h3 class="text-sm font-bold text-foreground">Tactics Lab</h3>
								<Icon name="chevron-right" size={14} className="text-muted-foreground group-hover:text-foreground transition" />
							</div>
							<p class="text-xs text-muted-foreground line-clamp-1 mt-0.5">
								Motif training and tactical streaks
							</p>
						</div>
					</div>
				</a>

				<!-- 4. Pass & Play (Local 2-Player) -->
				<a href="/play?mode=pass_and_play" class="group block">
					<div class="surface-panel rounded-2xl p-4.5 hover:border-foreground/40 transition flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-secondary flex items-center justify-center text-foreground shrink-0 border border-border group-hover:scale-105 transition-transform">
							<Icon name="handshake" size={22} />
						</div>
						<div class="flex-1 min-w-0">
							<div class="flex items-center justify-between">
								<h3 class="text-sm font-bold text-foreground">Pass & Play</h3>
								<Icon name="chevron-right" size={14} className="text-muted-foreground group-hover:text-foreground transition" />
							</div>
							<p class="text-xs text-muted-foreground line-clamp-1 mt-0.5">
								Local two-player over the board
							</p>
						</div>
					</div>
				</a>

				<!-- 5. Game Analysis & Review -->
				<a href="/analysis" class="group block sm:col-span-2">
					<div class="surface-panel rounded-2xl p-4.5 hover:border-foreground/40 transition flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-secondary flex items-center justify-center text-foreground shrink-0 border border-border group-hover:scale-105 transition-transform">
							<Icon name="search" size={22} />
						</div>
						<div class="flex-1 min-w-0">
							<div class="flex items-center justify-between">
								<h3 class="text-sm font-bold text-foreground">Game Analysis & PGN Explorer</h3>
								<Icon name="chevron-right" size={14} className="text-muted-foreground group-hover:text-foreground transition" />
							</div>
							<p class="text-xs text-muted-foreground line-clamp-1 mt-0.5">
								Deep Stockfish engine evaluations, move accuracy, and opening explorer
							</p>
						</div>
					</div>
				</a>
			</div>

			<!-- Recent Activity / Matches (if logged in and played) -->
			{#if $authStore.user && recentGames.length > 0}
				<div class="surface-panel rounded-2xl p-5 shadow-sm">
					<div class="flex items-center justify-between mb-3 pb-3 border-b border-border">
						<div class="flex items-center gap-2">
							<Icon name="clock" size={15} className="text-foreground" />
							<h3 class="text-sm font-bold text-foreground">Recent Matches</h3>
						</div>
						<a href="/profile/{$authStore.user.username}" class="text-xs text-muted-foreground hover:text-foreground transition">
							View All
						</a>
					</div>
					<div class="flex flex-col divide-y divide-border">
						{#each recentGames as game}
							{@const isWhite = game.whiteId === $authStore.user?.id}
							{@const opponent = isWhite ? game.blackUsername || 'Opponent' : game.whiteUsername || 'Opponent'}
							{@const won = (isWhite && game.winner === 'white') || (!isWhite && game.winner === 'black')}
							{@const draw = game.status === 'draw' || game.winner === 'draw'}
							<div class="py-2.5 flex items-center justify-between gap-3 text-xs">
								<div class="flex items-center gap-2.5">
									<span class="w-2 h-2 rounded-full {won ? 'bg-emerald-500' : draw ? 'bg-zinc-500' : 'bg-rose-500'}"></span>
									<span class="font-medium text-foreground">{opponent}</span>
									<span class="text-muted-foreground font-mono">
										{game.initial ? `${Math.round(game.initial / 60)}m` : 'Live'}
									</span>
								</div>
								<div class="flex items-center gap-2">
									<span class="font-mono font-semibold {won ? 'text-emerald-500' : draw ? 'text-muted-foreground' : 'text-rose-500'}">
										{won ? 'Won' : draw ? 'Draw' : 'Lost'}
									</span>
									<a href="/game/{game.id}" class="text-muted-foreground hover:text-foreground transition underline underline-offset-2">
										Review
									</a>
								</div>
							</div>
						{/each}
					</div>
				</div>
			{:else}
				<!-- Platform Integrity Stats Bar -->
				<div class="grid grid-cols-3 gap-3 surface-panel rounded-2xl p-4 shadow-sm text-center">
					<div>
						<div class="text-base sm:text-lg font-black font-mono text-foreground tracking-tight">400–2800</div>
						<div class="text-[10px] text-muted-foreground uppercase font-semibold">FIDE Elo Pools</div>
					</div>
					<div>
						<div class="text-base sm:text-lg font-black font-mono text-foreground tracking-tight">Sub-10ms</div>
						<div class="text-[10px] text-muted-foreground uppercase font-semibold">Clock Sync</div>
					</div>
					<div>
						<div class="text-base sm:text-lg font-black font-mono text-foreground tracking-tight">Stockfish 16</div>
						<div class="text-[10px] text-muted-foreground uppercase font-semibold">Engine Core</div>
					</div>
				</div>
			{/if}
		</div>

		<!-- Right Column (5 Cols on LG): Interactive Board & Daily Puzzle Hub -->
		<div class="lg:col-span-5 flex flex-col items-center w-full">
			<div class="w-full max-w-[440px] surface-panel rounded-2xl p-3 shadow-xl">

				<!-- Widget Tabs (Daily Puzzle vs Quick Sparring Board) -->
				<div class="flex items-center justify-between pb-2.5 mb-2.5 border-b border-border">
					<div class="flex items-center gap-1.5 p-1 bg-secondary/70 rounded-xl border border-border">
						<button
							class="px-2.5 py-1 rounded-lg text-xs font-semibold transition cursor-pointer {widgetTab === 'daily'
								? 'bg-foreground text-background shadow-xs'
								: 'text-muted-foreground hover:text-foreground'}"
							on:click={() => (widgetTab = 'daily')}
						>
							Daily Puzzle
						</button>
						<button
							class="px-2.5 py-1 rounded-lg text-xs font-semibold transition cursor-pointer {widgetTab === 'quick'
								? 'bg-foreground text-background shadow-xs'
								: 'text-muted-foreground hover:text-foreground'}"
							on:click={() => (widgetTab = 'quick')}
						>
							Quick Board
						</button>
					</div>

					{#if widgetTab === 'daily'}
						{#if dailyPuzzle}
							<div class="flex items-center gap-1.5">
								<span class="text-[11px] font-mono font-bold text-foreground">
									{dailyPuzzle.rating || 1500} Elo
								</span>
								<button
									class="p-1 rounded text-muted-foreground hover:text-foreground transition cursor-pointer"
									on:click={resetDailyPuzzle}
									title="Reset puzzle"
								>
									<Icon name="rotate-ccw" size={13} />
								</button>
							</div>
						{/if}
					{:else}
						{#if heroMovesCount > 0}
							<button
								class="text-[11px] text-muted-foreground hover:text-foreground font-medium flex items-center gap-1 transition"
								on:click={resetHeroBoard}
								title="Reset board"
							>
								<Icon name="rotate-ccw" size={12} />
								<span>Reset</span>
							</button>
						{/if}
					{/if}
				</div>

				<!-- Status Banner for Active Tab -->
				<div class="px-1.5 pb-2 text-xs flex items-center justify-between">
					{#if widgetTab === 'daily'}
						<div class="flex items-center gap-2">
							<span class="w-2 h-2 rounded-full {dailyStatusType === 'success' ? 'bg-emerald-500' : dailyStatusType === 'error' ? 'bg-rose-500' : 'bg-foreground'}"></span>
							<span class="font-medium text-foreground text-[11px] truncate">
								{dailyStatusMessage}
							</span>
						</div>
						<span class="text-[10px] text-muted-foreground uppercase font-mono font-semibold">
							{dailyTurn === 'white' ? 'White' : 'Black'} to move
						</span>
					{:else}
						<div class="flex items-center gap-2">
							<span class="w-2 h-2 rounded-full bg-foreground animate-pulse"></span>
							<span class="font-medium text-foreground text-[11px]">
								{heroMovesCount === 0 ? 'Make a move • Local reply' : `Move ${heroMovesCount} • ${heroTurn} to play`}
							</span>
						</div>
					{/if}
				</div>

				<!-- Board Canvas -->
				<div class="rounded-xl overflow-hidden border border-border">
					{#if widgetTab === 'daily'}
						<ChessBoard
							fen={dailyFen}
							orientation={dailyOrientation}
							turn={dailyTurn}
							lastMove={dailyLastMove}
							interactive={!dailySolved}
							boardSizeClass="w-full"
							disableGameOverModal={true}
							on:move={handleDailyMove}
						/>
					{:else}
						<ChessBoard
							fen={heroFen}
							orientation="white"
							turn={heroTurn}
							lastMove={heroLastMove}
							interactive={true}
							boardSizeClass="w-full"
							disableGameOverModal={true}
							on:move={handleHeroMove}
						/>
					{/if}
				</div>

				<!-- Board Footer Actions -->
				<div class="pt-3 mt-2 border-t border-border flex items-center justify-between gap-2">
					{#if widgetTab === 'daily'}
						<a href="/puzzles" class="w-full">
							<Button variant="secondary" size="sm" className="w-full justify-center">
								<Icon name="puzzle" size={14} />
								<span>Open Full Tactics Lab</span>
							</Button>
						</a>
					{:else}
						<a href="/play" class="flex-1">
							<Button variant="secondary" size="sm" className="w-full justify-center">
								<Icon name="swords" size={14} />
								<span>Spar with Engine</span>
							</Button>
						</a>
						<a href="/analysis" class="flex-1">
							<Button variant="outline" size="sm" className="w-full justify-center">
								<Icon name="search" size={14} />
								<span>Analysis Board</span>
							</Button>
						</a>
					{/if}
				</div>
			</div>
		</div>
	</div>
</div>
