<script lang="ts">
	import { onDestroy, onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { authStore } from '$lib/stores/auth';
	import { api } from '$lib/api/client';
	import Icon from '$lib/components/icons/Icon.svelte';
	import Button from '$lib/components/ui/Button.svelte';

	let incomingChallenges: any[] = [];
	let pollTimer: any = null;
	let accepting = false;
	let navigatingToGame = false;

	async function checkChallenges() {
		if (!$authStore.user || navigatingToGame) {
			incomingChallenges = [];
			return;
		}
		try {
			const res = await api.challenges.list();
			incomingChallenges = res.incoming || [];
			if (res.outgoing && res.outgoing.length > 0) {
				const accepted = res.outgoing.find((c: any) => c.status === 'accepted' && c.gameId);
				if (accepted && !navigatingToGame) {
					navigatingToGame = true;
					goto(`/game/${accepted.gameId}`);
				}
			}
		} catch (_) {}
	}

	onMount(() => {
		checkChallenges();
		pollTimer = setInterval(checkChallenges, 3500);
	});

	onDestroy(() => {
		if (pollTimer) clearInterval(pollTimer);
	});

	async function handleAccept(ch: any) {
		accepting = true;
		try {
			const res = await api.challenges.respond(ch.id, true);
			if (res.gameId) {
				incomingChallenges = incomingChallenges.filter((c) => c.id !== ch.id);
				goto(`/game/${res.gameId}`);
			}
		} catch (e) {
			console.warn('Failed to accept challenge:', e);
		} finally {
			accepting = false;
		}
	}

	async function handleDecline(ch: any) {
		try {
			await api.challenges.respond(ch.id, false);
			incomingChallenges = incomingChallenges.filter((c) => c.id !== ch.id);
		} catch (_) {}
	}
</script>

{#if incomingChallenges.length > 0}
	<div class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-sm w-full select-none animate-in fade-in slide-in-from-bottom-3 duration-300">
		{#each incomingChallenges as ch (ch.id)}
			<div class="p-3.5 bg-card/95 backdrop-blur-md border-2 border-emerald-500/50 rounded-2xl shadow-2xl ring-1 ring-border text-foreground flex items-center justify-between gap-3">
				<div class="min-w-0 flex-1">
					<div class="flex items-center gap-1.5 text-xs font-bold text-foreground">
						<span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
						<Icon name="swords" size={13} className="text-emerald-500" />
						<span class="truncate">{ch.challengerUsername}</span>
						<span class="text-[10px] font-mono text-muted-foreground font-semibold">({ch.challengerRating})</span>
					</div>
					<div class="text-[11px] text-muted-foreground mt-0.5 flex items-center gap-1.5">
						<span class="font-bold text-foreground">{ch.initial / 60}+{ch.increment}</span>
						<span>•</span>
						<span class="px-1.5 py-0.2 rounded text-[10px] font-bold {ch.rated ? 'bg-primary/20 text-primary' : 'bg-secondary text-muted-foreground'}">
							{ch.rated ? 'Rated' : 'Casual'}
						</span>
						<span>•</span>
						<span class="capitalize">{ch.colorPref}</span>
					</div>
				</div>

				<div class="flex items-center gap-1.5 shrink-0">
					<Button
						variant="primary"
						size="sm"
						className="text-xs py-1.5 px-3 font-bold bg-emerald-600 hover:bg-emerald-500 text-white shadow-xs"
						disabled={accepting}
						on:click={() => handleAccept(ch)}
					>
						<Icon name="check" size={13} />
						<span>Accept</span>
					</Button>
					<Button
						variant="secondary"
						size="sm"
						className="text-xs py-1.5 px-2"
						on:click={() => handleDecline(ch)}
					>
						<Icon name="x" size={13} />
					</Button>
				</div>
			</div>
		{/each}
	</div>
{/if}
