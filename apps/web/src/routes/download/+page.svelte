<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { isNativeOrAppEnvironment } from '$lib/config';
	import Icon from '$lib/components/icons/Icon.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import Badge from '$lib/components/ui/Badge.svelte';
	import Card from '$lib/components/ui/Card.svelte';

	const GITHUB_REPO = 'https://github.com/Yogesh-Kumar-Mallik-dev/ChessPasant';
	let releaseTag = 'v0.1.9';
	let versionNum = '0.1.9';
	const RELEASES_PAGE = `${GITHUB_REPO}/releases`;

	// Download artifacts map - dynamically updated from GitHub Releases API
	let downloads = {
		android: {
			apk: `${GITHUB_REPO}/releases/download/${releaseTag}/ChessPasant_${versionNum}.apk`,
			release: `${GITHUB_REPO}/releases`
		},
		ios: {
			pwa: 'https://chess.yogeshmallik.in',
			ipa: `${GITHUB_REPO}/releases/download/${releaseTag}/ChessPasant_${versionNum}_ios_unsigned.ipa`
		},
		arch: {
			pkg: `${GITHUB_REPO}/releases/download/${releaseTag}/chesspasant-${versionNum}-1-x86_64.pkg.tar.zst`,
			tarball: `${GITHUB_REPO}/releases/download/${releaseTag}/ChessPasant_${versionNum}_x86_64.tar.gz`,
			pkgbuild: `${GITHUB_REPO}/blob/main/packaging/arch/PKGBUILD`
		},
		linux: {
			universal: `${GITHUB_REPO}/releases/download/${releaseTag}/ChessPasant_${versionNum}_linux_x64.tar.gz`,
			deb: `${GITHUB_REPO}/releases/download/${releaseTag}/chesspasant_${versionNum}_amd64.deb`
		},
		windows: {
			exe: `${GITHUB_REPO}/releases/download/${releaseTag}/ChessPasant_${versionNum}_x64_Setup.exe`,
			zip: `${GITHUB_REPO}/releases/download/${releaseTag}/ChessPasant_${versionNum}_windows_x64.zip`
		},
		macos: {
			dmg: `${GITHUB_REPO}/releases/download/${releaseTag}/ChessPasant_${versionNum}.dmg`,
			zip: `${GITHUB_REPO}/releases/download/${releaseTag}/ChessPasant_${versionNum}_macos.zip`
		}
	};

	let detectedOs: 'android' | 'ios' | 'arch' | 'linux' | 'windows' | 'macos' | 'other' = 'other';
	let copiedCommand: string | null = null;

	function copyCommand(cmd: string) {
		if (typeof navigator !== 'undefined' && navigator.clipboard) {
			navigator.clipboard.writeText(cmd);
			copiedCommand = cmd;
			setTimeout(() => {
				if (copiedCommand === cmd) copiedCommand = null;
			}, 2500);
		}
	}

	onMount(() => {
		if (isNativeOrAppEnvironment()) {
			goto('/play');
			return;
		}

		// Dynamically query GitHub Releases API to always serve the latest release and asset URLs
		fetch('https://api.github.com/repos/Yogesh-Kumar-Mallik-dev/ChessPasant/releases/latest')
			.then((res) => (res.ok ? res.json() : null))
			.then((data) => {
				if (data && data.tag_name) {
					releaseTag = data.tag_name;
					versionNum = data.tag_name.replace(/^v/, '');

					if (Array.isArray(data.assets)) {
						const findAsset = (pattern: RegExp) =>
							data.assets.find((a: any) => pattern.test(a.name))?.browser_download_url;

						const apk = findAsset(/\.apk$/i);
						const ipa = findAsset(/\.ipa$/i);
						const pkg = findAsset(/\.pkg\.tar\.zst$/i);
						const archTarball = findAsset(/x86_64.*\.tar\.gz$/i);
						const linuxTarball = findAsset(/linux.*\.tar\.gz$/i);
						const deb = findAsset(/\.deb$/i);
						const exe = findAsset(/_Setup\.exe$|setup\.exe$/i);
						const winZip = findAsset(/windows.*\.zip$/i);
						const dmg = findAsset(/\.dmg$/i);
						const macZip = findAsset(/macos.*\.zip$/i);

						if (apk) downloads.android.apk = apk;
						if (ipa) downloads.ios.ipa = ipa;
						if (pkg) downloads.arch.pkg = pkg;
						if (archTarball) downloads.arch.tarball = archTarball;
						if (linuxTarball) downloads.linux.universal = linuxTarball;
						if (deb) downloads.linux.deb = deb;
						if (exe) downloads.windows.exe = exe;
						if (winZip) downloads.windows.zip = winZip;
						if (dmg) downloads.macos.dmg = dmg;
						if (macZip) downloads.macos.zip = macZip;
						downloads = { ...downloads };
					}
				}
			})
			.catch(() => {});

		if (typeof window !== 'undefined' && navigator) {
			const ua = (navigator.userAgent || '').toLowerCase();
			const platform = ((navigator as any).userAgentData?.platform || navigator.platform || '').toLowerCase();

			// 1. Android
			if (ua.includes('android') || platform.includes('android')) {
				detectedOs = 'android';
			}
			// 2. iOS (iPhone, iPad, iPod)
			else if (
				ua.includes('iphone') ||
				ua.includes('ipad') ||
				ua.includes('ipod') ||
				platform.includes('iphone') ||
				platform.includes('ipad') ||
				(platform === 'macintel' && navigator.maxTouchPoints > 1)
			) {
				detectedOs = 'ios';
			}
			// 3. Windows
			else if (ua.includes('win') || platform.includes('win')) {
				detectedOs = 'windows';
			}
			// 4. macOS
			else if (ua.includes('mac') || platform.includes('mac') || ua.includes('darwin')) {
				detectedOs = 'macos';
			}
			// 5. Arch Linux
			else if (/arch|manjaro|endeavouros|garuda|cachyos/i.test(ua)) {
				detectedOs = 'arch';
			}
			// 6. Generic Linux
			else if (ua.includes('linux') || ua.includes('x11') || platform.includes('linux')) {
				detectedOs = 'linux';
			}
		}
	});
</script>

<svelte:head>
	<title>Download ChessPasant — Mobile & Desktop</title>
	<meta name="description" content="Download ChessPasant application for Android, iOS, Arch Linux, Debian/Ubuntu, Windows, and macOS. Native performance, embedded Stockfish 19 NNUE, offline play, haptic feedback, and Studio Noir design." />
</svelte:head>

<div class="max-w-6xl mx-auto px-4 sm:px-6 py-10 sm:py-16 w-full flex-1 flex flex-col justify-center">
	<!-- Hero Header with Authentic Platform Logo -->
	<div class="text-center max-w-3xl mx-auto mb-12 sm:mb-16">
		<div class="inline-flex items-center justify-center p-3 sm:p-4 rounded-2xl bg-secondary/80 border border-border shadow-xs mb-5 group hover:border-foreground/30 transition-all">
			<img src="/logo.png" alt="ChessPasant" class="w-16 h-16 sm:w-20 sm:h-20 object-contain drop-shadow-md group-hover:scale-105 transition-transform" />
		</div>

		<div>
			<Badge variant="outline" className="mb-4 px-3 py-1 font-mono text-xs tracking-wider uppercase border-border text-muted-foreground">
				<span class="inline-block w-1.5 h-1.5 rounded-full bg-emerald-500 mr-2 animate-pulse"></span>
				<span>Official Release {releaseTag}</span>
			</Badge>
		</div>

		<h1 class="text-3xl sm:text-5xl lg:text-6xl font-black text-foreground tracking-tight mb-4">
			Download ChessPasant
		</h1>

		<p class="text-base sm:text-lg text-muted-foreground leading-relaxed">
			Ultra-fast native performance engineered with Rust and Tauri v2. Offline Stockfish 19 sparring, tactile vibration haptics, tactical analysis, and frameless Studio Noir design across Mobile & Desktop.
		</p>
	</div>

	<!-- Unified 6-Card Grid: 2 Rows of 3 Cards on Desktop -->
	<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-14">
		<!-- 1. Android Card -->
		<Card className="p-6 flex flex-col justify-between relative border-border hover:border-foreground/30 transition-all {detectedOs === 'android' ? 'ring-2 ring-emerald-500/50 bg-secondary/30' : 'bg-card'}">
			{#if detectedOs === 'android'}
				<div class="absolute -top-3 left-6">
					<span class="bg-emerald-500 text-black text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full shadow-xs">
						Detected Device
					</span>
				</div>
			{/if}

			<div>
				<div class="flex items-center justify-between mb-4">
					<div class="w-12 h-12 rounded-xl bg-secondary border border-border/80 flex items-center justify-center text-foreground font-bold shadow-2xs">
						<Icon name="brand-android" size={24} className="text-foreground" />
					</div>
					<span class="text-xs font-mono text-muted-foreground">ARM64 & x86_64</span>
				</div>

				<h2 class="text-lg font-bold text-foreground mb-1">Android</h2>
				<p class="text-xs text-muted-foreground mb-4">
					Native Android application with tactile vibration haptics, direct camera avatar upload, and background match synchronization.
				</p>
			</div>

			<div class="space-y-2 pt-4 border-t border-border">
				<a href={downloads.android.apk} class="block">
					<Button variant={detectedOs === 'android' ? 'primary' : 'secondary'} size="sm" className="w-full justify-between text-xs">
						<span>Download .apk Package</span>
						<Icon name="download" size={13} />
					</Button>
				</a>
				<a href={downloads.android.release} target="_blank" rel="noopener noreferrer" class="block">
					<Button variant="outline" size="sm" className="w-full justify-between text-xs">
						<span>GitHub APK Releases</span>
						<Icon name="external-link" size={13} />
					</Button>
				</a>
			</div>
		</Card>

		<!-- 2. iOS & iPadOS Card -->
		<Card className="p-6 flex flex-col justify-between relative border-border hover:border-foreground/30 transition-all {detectedOs === 'ios' ? 'ring-2 ring-emerald-500/50 bg-secondary/30' : 'bg-card'}">
			{#if detectedOs === 'ios'}
				<div class="absolute -top-3 left-6">
					<span class="bg-emerald-500 text-black text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full shadow-xs">
						Detected Device
					</span>
				</div>
			{/if}

			<div>
				<div class="flex items-center justify-between mb-4">
					<div class="w-12 h-12 rounded-xl bg-secondary border border-border/80 flex items-center justify-center text-foreground font-bold shadow-2xs">
						<Icon name="brand-apple" size={24} className="text-foreground" />
					</div>
					<span class="text-xs font-mono text-muted-foreground">iOS / iPadOS 15+</span>
				</div>

				<h2 class="text-lg font-bold text-foreground mb-1">iOS & iPadOS</h2>
				<p class="text-xs text-muted-foreground mb-4">
					Fluid touch gestures and full offline caching for iPhone and iPad. Install directly to your Home Screen for a seamless fullscreen experience.
				</p>
			</div>

			<div class="space-y-2 pt-4 border-t border-border">
				<a href={downloads.ios.pwa} class="block">
					<Button variant={detectedOs === 'ios' ? 'primary' : 'secondary'} size="sm" className="w-full justify-between text-xs">
						<span>Open & Add to Home Screen</span>
						<Icon name="external-link" size={13} />
					</Button>
				</a>
				<a href={downloads.ios.ipa} target="_blank" rel="noopener noreferrer" class="block">
					<Button variant="outline" size="sm" className="w-full justify-between text-xs">
						<span>Download Sideload .ipa</span>
						<Icon name="download" size={13} />
					</Button>
				</a>
			</div>
		</Card>

		<!-- 3. Arch Linux Card -->
		<Card className="p-6 flex flex-col justify-between relative border-border hover:border-foreground/30 transition-all {detectedOs === 'arch' ? 'ring-2 ring-emerald-500/50 bg-secondary/30' : 'bg-card'}">
			{#if detectedOs === 'arch'}
				<div class="absolute -top-3 left-6">
					<span class="bg-emerald-500 text-black text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full shadow-xs">
						Detected OS
					</span>
				</div>
			{/if}

			<div>
				<div class="flex items-center justify-between mb-4">
					<div class="w-12 h-12 rounded-xl bg-secondary border border-border/80 flex items-center justify-center text-foreground font-bold shadow-2xs">
						<Icon name="brand-arch" size={24} className="text-foreground" />
					</div>
					<span class="text-xs font-mono text-muted-foreground">x86_64</span>
				</div>

				<h2 class="text-lg font-bold text-foreground mb-1">Arch Linux</h2>
				<p class="text-xs text-muted-foreground mb-4">
					Native Pacman package (.pkg.tar.zst) and AUR PKGBUILD for Arch Linux, Manjaro, and EndeavourOS.
				</p>
			</div>

			<div class="space-y-2 pt-4 border-t border-border">
				<a href={downloads.arch.pkg} class="block">
					<Button variant={detectedOs === 'arch' ? 'primary' : 'secondary'} size="sm" className="w-full justify-between text-xs">
						<span>Download .pkg.tar.zst</span>
						<Icon name="download" size={13} />
					</Button>
				</a>

				<a href={downloads.arch.tarball} class="block">
					<Button variant="outline" size="sm" className="w-full justify-between text-xs">
						<span>Download .tar.gz Bundle</span>
						<Icon name="download" size={13} />
					</Button>
				</a>

				<!-- 1-Command Automated Repo Install -->
				<button
					type="button"
					on:click={() => copyCommand('curl -sSL https://chess.yogeshmallik.in/repo/setup-repo.sh | sudo bash')}
					class="w-full mt-1.5 px-2.5 py-1.5 rounded-lg bg-emerald-500/10 hover:bg-emerald-500/20 border border-emerald-500/30 text-left flex items-center justify-between text-[11px] font-mono text-emerald-400 hover:text-emerald-300 transition-colors cursor-pointer"
					title="Click to copy automated repository setup & install script"
				>
					<span class="truncate mr-2">curl -sSL .../setup-repo.sh | sudo bash</span>
					<Icon name={copiedCommand ? 'check' : 'copy'} size={12} className={copiedCommand ? 'text-emerald-500' : 'text-emerald-400'} />
				</button>

				<!-- Quick Copy Pacman Install Helper -->
				<button
					type="button"
					on:click={() => copyCommand('sudo pacman -Sy chesspasant')}
					class="w-full px-2.5 py-1 rounded-lg bg-secondary/60 hover:bg-secondary border border-border/60 text-left flex items-center justify-between text-[11px] font-mono text-muted-foreground hover:text-foreground transition-colors cursor-pointer"
					title="Click to copy Pacman command"
				>
					<span class="truncate mr-2">sudo pacman -Sy chesspasant</span>
					<Icon name={copiedCommand ? 'check' : 'copy'} size={12} className={copiedCommand ? 'text-emerald-500' : 'text-muted-foreground'} />
				</button>
			</div>
		</Card>

		<!-- 4. Universal Linux Card -->
		<Card className="p-6 flex flex-col justify-between relative border-border hover:border-foreground/30 transition-all {detectedOs === 'linux' ? 'ring-2 ring-emerald-500/50 bg-secondary/30' : 'bg-card'}">
			{#if detectedOs === 'linux'}
				<div class="absolute -top-3 left-6">
					<span class="bg-emerald-500 text-black text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full shadow-xs">
						Detected OS
					</span>
				</div>
			{/if}
			<div>
				<div class="flex items-center justify-between mb-4">
					<div class="w-12 h-12 rounded-xl bg-secondary border border-border/80 flex items-center justify-center text-foreground font-bold shadow-2xs">
						<Icon name="brand-linux" size={24} className="text-foreground" />
					</div>
					<span class="text-xs font-mono text-muted-foreground">amd64 / x86_64</span>
				</div>

				<h2 class="text-lg font-bold text-foreground mb-1">Linux (Debian / Universal)</h2>
				<p class="text-xs text-muted-foreground mb-4">
					Single-file .deb package for Debian, Ubuntu, and Linux Mint, plus standalone portable .tar.gz bundle.
				</p>
			</div>

			<div class="space-y-2 pt-4 border-t border-border">
				<a href={downloads.linux.deb} class="block">
					<Button variant={detectedOs === 'linux' ? 'primary' : 'secondary'} size="sm" className="w-full justify-between text-xs">
						<span>Download .deb Package</span>
						<Icon name="download" size={13} />
					</Button>
				</a>
				<a href={downloads.linux.universal} class="block">
					<Button variant="outline" size="sm" className="w-full justify-between text-xs">
						<span>Download .tar.gz Bundle</span>
						<Icon name="download" size={13} />
					</Button>
				</a>
			</div>
		</Card>

		<!-- 5. Windows Card -->
		<Card className="p-6 flex flex-col justify-between relative border-border hover:border-foreground/30 transition-all {detectedOs === 'windows' ? 'ring-2 ring-emerald-500/50 bg-secondary/30' : 'bg-card'}">
			{#if detectedOs === 'windows'}
				<div class="absolute -top-3 left-6">
					<span class="bg-emerald-500 text-black text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full shadow-xs">
						Detected OS
					</span>
				</div>
			{/if}

			<div>
				<div class="flex items-center justify-between mb-4">
					<div class="w-12 h-12 rounded-xl bg-secondary border border-border/80 flex items-center justify-center text-foreground font-bold shadow-2xs">
						<Icon name="brand-windows" size={24} className="text-foreground" />
					</div>
					<span class="text-xs font-mono text-muted-foreground">x64 (64-bit)</span>
				</div>

				<h2 class="text-lg font-bold text-foreground mb-1">Windows</h2>
				<p class="text-xs text-muted-foreground mb-4">
					Single-file Setup Wizard (.exe) with desktop and Start Menu shortcuts, or portable ZIP archive.
				</p>
			</div>

			<div class="space-y-2 pt-4 border-t border-border">
				<a href={downloads.windows.exe} class="block">
					<Button variant={detectedOs === 'windows' ? 'primary' : 'secondary'} size="sm" className="w-full justify-between text-xs">
						<span>Download .exe Setup</span>
						<Icon name="download" size={13} />
					</Button>
				</a>
				<a href={downloads.windows.zip} class="block">
					<Button variant="outline" size="sm" className="w-full justify-between text-xs">
						<span>Download Portable .zip</span>
						<Icon name="download" size={13} />
					</Button>
				</a>
			</div>
		</Card>

		<!-- 6. macOS Card -->
		<Card className="p-6 flex flex-col justify-between relative border-border hover:border-foreground/30 transition-all {detectedOs === 'macos' ? 'ring-2 ring-emerald-500/50 bg-secondary/30' : 'bg-card'}">
			{#if detectedOs === 'macos'}
				<div class="absolute -top-3 left-6">
					<span class="bg-emerald-500 text-black text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full shadow-xs">
						Detected OS
					</span>
				</div>
			{/if}

			<div>
				<div class="flex items-center justify-between mb-4">
					<div class="w-12 h-12 rounded-xl bg-secondary border border-border/80 flex items-center justify-center text-foreground font-bold shadow-2xs">
						<Icon name="brand-apple" size={24} className="text-foreground" />
					</div>
					<span class="text-xs font-mono text-muted-foreground">Universal / Apple Silicon</span>
				</div>

				<h2 class="text-lg font-bold text-foreground mb-1">macOS</h2>
				<p class="text-xs text-muted-foreground mb-4">
					Single-file Drag-and-Drop .dmg disk image installer and portable ZIP archive for Apple Silicon and Intel Macs.
				</p>
			</div>

			<div class="space-y-2 pt-4 border-t border-border">
				<a href={downloads.macos.dmg} class="block">
					<Button variant={detectedOs === 'macos' ? 'primary' : 'secondary'} size="sm" className="w-full justify-between text-xs">
						<span>Download .dmg Installer</span>
						<Icon name="download" size={13} />
					</Button>
				</a>
				<a href={downloads.macos.zip} class="block">
					<Button variant="outline" size="sm" className="w-full justify-between text-xs">
						<span>Download Portable .zip</span>
						<Icon name="download" size={13} />
					</Button>
				</a>
			</div>
		</Card>
	</div>

	<!-- GitHub Release Banner & Verification -->
	<Card className="p-6 sm:p-8 border-border bg-card/60 backdrop-blur-xs mb-14">
		<div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6">
			<div>
				<div class="flex items-center gap-2 mb-2">
					<span class="text-base font-bold text-foreground">GitHub Release Repository</span>
					<Badge variant="outline" className="text-[10px] font-mono">Open Source</Badge>
				</div>
				<p class="text-sm text-muted-foreground max-w-xl">
					All release binaries are automatically compiled and published through GitHub Actions. You can inspect SHA-256 checksums, full changelogs, PKGBUILD sources, and release assets on GitHub.
				</p>
			</div>

			<a href={RELEASES_PAGE} target="_blank" rel="noopener noreferrer" class="shrink-0 w-full sm:w-auto">
				<Button variant="outline" size="default" className="w-full sm:w-auto gap-2">
					<span>View on GitHub</span>
					<Icon name="external-link" size={14} />
				</Button>
			</a>
		</div>
	</Card>

	<!-- Key Platform Features Grid -->
	<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
		<div class="p-5 rounded-xl border border-border bg-card/40">
			<div class="w-8 h-8 rounded-lg bg-secondary flex items-center justify-center mb-3">
				<Icon name="zap" size={16} className="text-foreground" />
			</div>
			<h3 class="text-sm font-bold text-foreground mb-1">Stockfish 19 with NNUE</h3>
			<p class="text-xs text-muted-foreground leading-relaxed">
				Integrated neural network engine calculation at depth 14–16 for grandmaster tactical precision.
			</p>
		</div>

		<div class="p-5 rounded-xl border border-border bg-card/40">
			<div class="w-8 h-8 rounded-lg bg-secondary flex items-center justify-center mb-3">
				<Icon name="wifi-off" size={16} className="text-foreground" />
			</div>
			<h3 class="text-sm font-bold text-foreground mb-1">100% Offline Play</h3>
			<p class="text-xs text-muted-foreground leading-relaxed">
				Full game reviews, bot sparring, and pass-and-play matches function with zero internet connection.
			</p>
		</div>

		<div class="p-5 rounded-xl border border-border bg-card/40">
			<div class="w-8 h-8 rounded-lg bg-secondary flex items-center justify-center mb-3">
				<Icon name="sparkles" size={16} className="text-foreground" />
			</div>
			<h3 class="text-sm font-bold text-foreground mb-1">Studio Noir Design</h3>
			<p class="text-xs text-muted-foreground leading-relaxed">
				Custom desktop titlebar, high-contrast Staunton SVG vector pieces, and dynamic multi-theme engine.
			</p>
		</div>

		<div class="p-5 rounded-xl border border-border bg-card/40">
			<div class="w-8 h-8 rounded-lg bg-secondary flex items-center justify-center mb-3">
				<Icon name="shield" size={16} className="text-foreground" />
			</div>
			<h3 class="text-sm font-bold text-foreground mb-1">Under 60 MB RAM</h3>
			<p class="text-xs text-muted-foreground leading-relaxed">
				Native Tauri v2 + Rust architecture replaces heavy Electron runtimes with ultra-light native webviews.
			</p>
		</div>
	</div>
</div>
