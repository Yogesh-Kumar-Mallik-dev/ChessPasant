<script lang="ts">
	import { createEventDispatcher, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { api } from '$lib/api/client';
	import Icon from '$lib/components/icons/Icon.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import Modal from '$lib/components/ui/Modal.svelte';

	export let isOpen = false;
	export let opponentId: string;
	export let opponentUsername: string;
	export let opponentRating = 400;
	export let opponentAvatar = '';

	const dispatch = createEventDispatcher<{ close: void; created: any }>();

	const presetTimeControls = [
		{ label: '1+0', desc: 'Bullet', initial: 60, inc: 0 },
		{ label: '3+0', desc: 'Blitz', initial: 180, inc: 0 },
		{ label: '5+0', desc: 'Blitz', initial: 300, inc: 0 },
		{ label: '10+0', desc: 'Rapid', initial: 600, inc: 0 }
	];

	let selectedTc = presetTimeControls[2]; // Default 5+0
	let isRated = true; // Default with ELO
	let colorPref: 'random' | 'white' | 'black' = 'random';
	let loading = false;
	let error = '';
	let sentChallenge: any = null;
	let pollInterval: any = null;

	onDestroy(() => {
		if (pollInterval) clearInterval(pollInterval);
	});

	async function sendChallenge() {
		loading = true;
		error = '';
		try {
			const ch = await api.challenges.create({
				challengedId: opponentId,
				initial: selectedTc.initial,
				increment: selectedTc.inc,
				rated: isRated,
				colorPref
			});
			sentChallenge = ch;
			startPolling(ch.id);
			dispatch('created', ch);
		} catch (e: any) {
			error = e.message || 'Failed to send challenge';
		} finally {
			loading = false;
		}
	}

	function startPolling(challengeId: string) {
		if (pollInterval) clearInterval(pollInterval);
		pollInterval = setInterval(async () => {
			try {
				const list = await api.challenges.list();
				// Check if challenge is accepted or gone
				const ch = list.outgoing ? list.outgoing.find((c: any) => c.id === challengeId) : null;
				if (!ch) {
					// Fallback: check if an active game was already created for this match
					try {
						const active = await api.games.getActive();
						if (active && active.id) {
							clearInterval(pollInterval);
							pollInterval = null;
							isOpen = false;
							goto(`/game/${active.id}`);
							return;
						}
					} catch (_) {}
					clearInterval(pollInterval);
					pollInterval = null;
				} else if (ch.status === 'accepted' && ch.gameId) {
					clearInterval(pollInterval);
					pollInterval = null;
					isOpen = false;
					goto(`/game/${ch.gameId}`);
				} else if (ch.status === 'declined' || ch.status === 'canceled') {
					clearInterval(pollInterval);
					pollInterval = null;
					error = `Challenge was ${ch.status}.`;
					sentChallenge = null;
				}
			} catch (_) {}
		}, 1500);
	}

	async function cancelChallenge() {
		if (!sentChallenge) return;
		try {
			await api.challenges.cancel(sentChallenge.id);
		} catch (_) {}
		if (pollInterval) clearInterval(pollInterval);
		sentChallenge = null;
		isOpen = false;
		dispatch('close');
	}

	function handleClose() {
		if (pollInterval) clearInterval(pollInterval);
		sentChallenge = null;
		isOpen = false;
		dispatch('close');
	}
</script>

<Modal {isOpen} title="Challenge {opponentUsername}" on:close={handleClose}>
	<div class="space-y-4 text-foreground">
		<!-- Opponent Preview -->
		<div class="flex items-center gap-3 p-3 rounded-xl bg-secondary/50 border border-border">
			<div class="w-10 h-10 rounded-xl bg-card border border-border overflow-hidden flex items-center justify-center font-bold text-foreground">
				{#if opponentAvatar}
					<img src={opponentAvatar} alt={opponentUsername} class="w-full h-full object-cover" />
				{:else}
					<Icon name="user" size={18} />
				{/if}
			</div>
			<div class="min-w-0 flex-1">
				<div class="flex items-center gap-2">
					<span class="font-bold text-sm text-foreground truncate">{opponentUsername}</span>
					<span class="text-xs font-mono px-1.5 py-0.5 rounded bg-card border border-border text-foreground font-semibold">
						{opponentRating}
					</span>
				</div>
				<p class="text-[11px] text-muted-foreground">Select match parameters below to issue a direct duel.</p>
			</div>
		</div>

		{#if sentChallenge}
			<!-- Waiting State -->
			<div class="py-8 text-center space-y-3">
				<div class="w-12 h-12 rounded-full bg-emerald-500/10 border border-emerald-500/30 flex items-center justify-center mx-auto text-emerald-500 animate-pulse">
					<Icon name="swords" size={24} />
				</div>
				<h4 class="font-bold text-sm text-foreground">Challenge Sent!</h4>
				<p class="text-xs text-muted-foreground max-w-xs mx-auto">
					Waiting for <strong>{opponentUsername}</strong> to accept your {selectedTc.label} ({isRated ? 'Rated' : 'Casual'}) match...
				</p>
				<Button variant="outline" size="sm" className="mt-2" on:click={cancelChallenge}>
					Cancel Challenge
				</Button>
			</div>
		{:else}
			<!-- Form Controls -->
			{#if error}
				<div class="p-2.5 rounded-lg bg-destructive/10 border border-destructive/30 text-destructive text-xs font-medium">
					{error}
				</div>
			{/if}

			<!-- 1. Time Control -->
			<div>
				<label class="block text-xs font-bold text-foreground mb-1.5 flex items-center gap-1.5">
					<Icon name="clock" size={13} className="text-muted-foreground" />
					<span>Time Control</span>
				</label>
				<div class="grid grid-cols-4 gap-2">
					{#each presetTimeControls as tc}
						<button
							type="button"
							class="py-2 px-1.5 rounded-xl border text-center transition cursor-pointer {selectedTc.label === tc.label
								? 'bg-foreground text-background border-foreground font-bold shadow-xs'
								: 'bg-card hover:bg-secondary/80 border-border text-foreground'}"
							on:click={() => (selectedTc = tc)}
						>
							<div class="text-xs font-mono font-bold">{tc.label}</div>
							<div class="text-[10px] opacity-75">{tc.desc}</div>
						</button>
					{/each}
				</div>
			</div>

			<!-- 2. Mode: Rated (with ELO) vs Casual (without ELO) -->
			<div>
				<label class="block text-xs font-bold text-foreground mb-1.5 flex items-center gap-1.5">
					<Icon name="shield" size={13} className="text-muted-foreground" />
					<span>Game Mode</span>
				</label>
				<div class="grid grid-cols-2 gap-2">
					<button
						type="button"
						class="py-2.5 px-3 rounded-xl border text-left transition cursor-pointer {isRated
							? 'bg-foreground text-background border-foreground font-bold shadow-xs'
							: 'bg-card hover:bg-secondary/80 border-border text-foreground'}"
						on:click={() => (isRated = true)}
					>
						<div class="text-xs font-bold flex items-center gap-1.5">
							<span>Rated Match</span>
						</div>
						<div class="text-[10px] opacity-75 mt-0.5">Affects Blitz/Rapid ELO ratings</div>
					</button>

					<button
						type="button"
						class="py-2.5 px-3 rounded-xl border text-left transition cursor-pointer {!isRated
							? 'bg-foreground text-background border-foreground font-bold shadow-xs'
							: 'bg-card hover:bg-secondary/80 border-border text-foreground'}"
						on:click={() => (isRated = false)}
					>
						<div class="text-xs font-bold flex items-center gap-1.5">
							<span>Casual Match</span>
						</div>
						<div class="text-[10px] opacity-75 mt-0.5">Friendly match, ELO unchanged</div>
					</button>
				</div>
			</div>

			<!-- 3. Color Preference -->
			<div>
				<label class="block text-xs font-bold text-foreground mb-1.5 flex items-center gap-1.5">
					<Icon name="zap" size={13} className="text-muted-foreground" />
					<span>Color Preference</span>
				</label>
				<div class="grid grid-cols-3 gap-2">
					<button
						type="button"
						class="py-2 px-2 rounded-xl border text-center transition cursor-pointer {colorPref === 'random'
							? 'bg-foreground text-background border-foreground font-bold shadow-xs'
							: 'bg-card hover:bg-secondary/80 border-border text-foreground'}"
						on:click={() => (colorPref = 'random')}
					>
						<span class="text-xs font-semibold">Random</span>
					</button>
					<button
						type="button"
						class="py-2 px-2 rounded-xl border text-center transition flex items-center justify-center gap-1.5 cursor-pointer {colorPref === 'white'
							? 'bg-foreground text-background border-foreground font-bold shadow-xs'
							: 'bg-card hover:bg-secondary/80 border-border text-foreground'}"
						on:click={() => (colorPref = 'white')}
					>
						<span class="w-2.5 h-2.5 rounded-full bg-background border border-foreground/40"></span>
						<span class="text-xs font-semibold">White</span>
					</button>
					<button
						type="button"
						class="py-2 px-2 rounded-xl border text-center transition flex items-center justify-center gap-1.5 cursor-pointer {colorPref === 'black'
							? 'bg-foreground text-background border-foreground font-bold shadow-xs'
							: 'bg-card hover:bg-secondary/80 border-border text-foreground'}"
						on:click={() => (colorPref = 'black')}
					>
						<span class="w-2.5 h-2.5 rounded-full bg-foreground border border-background/40"></span>
						<span class="text-xs font-semibold">Black</span>
					</button>
				</div>
			</div>

			<!-- Submit Button -->
			<div class="pt-2">
				<Button variant="primary" className="w-full py-2.5 text-xs font-bold shadow-sm" on:click={sendChallenge} disabled={loading}>
					{#if loading}
						<span>Sending Challenge...</span>
					{:else}
						<Icon name="swords" size={14} />
						<span>Issue Challenge</span>
					{/if}
				</Button>
			</div>
		{/if}
	</div>
</Modal>
