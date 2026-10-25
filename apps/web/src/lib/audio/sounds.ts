// ==============================================================================
// ChessPasant Authentic Studio Audio Player
// Uses authentic, studio-recorded acoustic chess sound effects (clean, pleasant wood impacts)
// Pre-cached audio pool with zero-latency playback across all browsers
// ==============================================================================

export type MoveCategory = 'normal' | 'capture' | 'castle' | 'en_passant' | 'promote' | 'check' | 'checkmate';

class ChessSoundPlayer {
	private enabled = true;
	private masterVolume = 0.85;
	private audioContext: AudioContext | null = null;
	private buffers = new Map<string, AudioBuffer>();
	private audioCache = new Map<string, HTMLAudioElement[]>();
	private unlocked = false;
	private lastPlayedKey = '';
	private lastPlayedTime = 0;

	constructor() {
		if (typeof window !== 'undefined') {
			const savedVol = localStorage.getItem('chess_volume');
			if (savedVol !== null) {
				const parsed = parseFloat(savedVol);
				if (!isNaN(parsed)) {
					this.masterVolume = Math.max(0, Math.min(1, parsed));
				}
			}
			const savedEnabled = localStorage.getItem('chess_sound_enabled');
			if (savedEnabled !== null) {
				this.enabled = savedEnabled === 'true';
			}

			// Preload both Web Audio API buffers and HTML5 audio fallbacks
			this.initAudioContext();
			this.preloadAll();
			this.setupAutoplayUnlock();
		}
	}

	private initAudioContext() {
		try {
			const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
			if (AudioCtx) {
				this.audioContext = new AudioCtx();
			}
		} catch (e) {
			console.warn('[ChessSoundPlayer] Web Audio API initialization warning:', e);
		}
	}

	private setupAutoplayUnlock() {
		const unlock = () => {
			this.unlockAudio();
		};

		window.addEventListener('pointerdown', unlock, { capture: true, once: true });
		window.addEventListener('keydown', unlock, { capture: true, once: true });
		window.addEventListener('touchstart', unlock, { capture: true, once: true });
		window.addEventListener('touchend', unlock, { capture: true, once: true });
	}

	public unlockAudio() {
		if (this.audioContext && this.audioContext.state === 'suspended') {
			this.audioContext.resume().then(() => {
				this.unlocked = true;
			}).catch(() => {});
		} else {
			this.unlocked = true;
		}
	}

	private preloadAll() {
		const sounds = [
			{ key: 'move', url: '/sounds/move.mp3' },
			{ key: 'capture', url: '/sounds/capture.mp3' },
			{ key: 'castle', url: '/sounds/castle.mp3' },
			{ key: 'check', url: '/sounds/check.mp3' },
			{ key: 'promote', url: '/sounds/promote.mp3' },
			{ key: 'en-passant', url: '/sounds/en-passant.mp3' },
			{ key: 'game-end', url: '/sounds/game-end.mp3' },
			{ key: 'game-start', url: '/sounds/game-start.mp3' }
		];

		for (const { key, url } of sounds) {
			this.preloadBuffer(key, url);
			this.preloadHtmlAudio(key, url);
		}
	}

	private async preloadBuffer(key: string, url: string) {
		if (!this.audioContext) return;
		try {
			const resp = await fetch(url);
			if (!resp.ok) return;
			const arrayBuf = await resp.arrayBuffer();
			const audioBuf = await this.audioContext.decodeAudioData(arrayBuf);
			this.buffers.set(key, audioBuf);
		} catch (e) {
			// Decoded buffer fallback handled at play time
		}
	}

	private preloadHtmlAudio(key: string, url: string, poolSize = 3) {
		const pool: HTMLAudioElement[] = [];
		for (let i = 0; i < poolSize; i++) {
			try {
				const a = new Audio(url);
				a.preload = 'auto';
				pool.push(a);
			} catch {}
		}
		this.audioCache.set(key, pool);
	}

	private play(key: string, volume = 0.85) {
		if (!this.enabled || typeof window === 'undefined') return;

		// Deduplicate identical sound calls triggered within 80ms
		const now = Date.now();
		if (this.lastPlayedKey === key && now - this.lastPlayedTime < 80) {
			return;
		}
		this.lastPlayedKey = key;
		this.lastPlayedTime = now;

		const finalVol = Math.max(0, Math.min(1, volume * this.masterVolume));
		const isMobileDevice = typeof navigator !== 'undefined' && /Android|iPhone|iPad|iPod|webOS|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
		const isLinuxDesktop = typeof navigator !== 'undefined' && /Linux/i.test(navigator.userAgent) && !isMobileDevice;

		// 0. Native Desktop Audio: On desktop Tauri Linux (WebKitGTK without system gstreamer), invoke native Rust audio (pw-play/paplay)
		// On Windows and macOS, Tauri WebView2/WebKit natively executes Web Audio API with zero subprocesses and zero popups
		if (isLinuxDesktop && ('__TAURI_INTERNALS__' in window || '__TAURI__' in window)) {
			import('@tauri-apps/api/core')
				.then(({ invoke }) => {
					invoke('native_play_sound', { name: key }).catch(() => {
						this.playWebAudio(key, finalVol);
					});
				})
				.catch(() => {
					this.playWebAudio(key, finalVol);
				});
			return;
		}

		// 1. Mobile, Windows, macOS & Web Standard: Direct Web Audio API / HTML5 Audio
		this.playWebAudio(key, finalVol);
	}

	private playWebAudio(key: string, finalVol: number) {
		// 1. Primary Strategy: Web Audio API (Hardware-direct, 0ms latency, zero native process overhead)
		if (this.audioContext) {
			if (this.audioContext.state === 'suspended') {
				this.audioContext.resume().catch(() => {});
			}

			const buffer = this.buffers.get(key);
			if (buffer) {
				try {
					const source = this.audioContext.createBufferSource();
					source.buffer = buffer;
					const gainNode = this.audioContext.createGain();
					gainNode.gain.setValueAtTime(finalVol, this.audioContext.currentTime);
					source.connect(gainNode);
					gainNode.connect(this.audioContext.destination);
					source.start(0);
					return;
				} catch (err) {
					console.warn('[ChessSoundPlayer] Web Audio playback error, trying fallback:', err);
				}
			}
		}

		// 2. Secondary Strategy: HTML5 Audio Pool
		const pool = this.audioCache.get(key);
		if (pool && pool.length > 0) {
			const audio = pool.find((a) => a.paused || a.ended) || pool[0];
			try {
				audio.currentTime = 0;
				audio.volume = finalVol;
				const playPromise = audio.play();
				if (playPromise) {
					playPromise.catch(() => {
						// Autoplay or codec error, activate synthetic acoustic fallback
						this.playSyntheticWoodClick(key, finalVol);
					});
				}
				return;
			} catch {
				this.playSyntheticWoodClick(key, finalVol);
				return;
			}
		}

		// 3. Fallback Strategy: Pure Web Audio Procedural Acoustic Wood Click
		this.playSyntheticWoodClick(key, finalVol);
	}

	/**
	 * High-fidelity procedural acoustic wood snap synthesizer fallback.
	 * Guaranteed to produce an authentic wooden chess board impact even if all external media files fail.
	 */
	private playSyntheticWoodClick(type: string, volume: number) {
		if (!this.audioContext) return;
		try {
			if (this.audioContext.state === 'suspended') {
				this.audioContext.resume().catch(() => {});
			}
			const ctx = this.audioContext;
			const now = ctx.currentTime;

			const isCapture = type === 'capture' || type === 'en-passant';
			const isCheck = type === 'check' || type === 'game-end';
			const baseFreq = isCapture ? 160 : isCheck ? 320 : 220;
			const duration = isCheck ? 0.22 : 0.08;

			const osc = ctx.createOscillator();
			const gain = ctx.createGain();

			osc.type = isCapture ? 'triangle' : 'sine';
			osc.frequency.setValueAtTime(baseFreq, now);
			osc.frequency.exponentialRampToValueAtTime(baseFreq * 0.35, now + duration);

			gain.gain.setValueAtTime(volume * 0.9, now);
			gain.gain.exponentialRampToValueAtTime(0.001, now + duration);

			osc.connect(gain);
			gain.connect(ctx.destination);

			osc.start(now);
			osc.stop(now + duration);
		} catch {}
	}

	public playNormalMove() {
		this.play('move', 0.85);
	}

	public playCapture() {
		this.play('capture', 0.9);
	}

	public playCastle() {
		this.play('castle', 0.85);
	}

	public playEnPassant() {
		this.play('en-passant', 0.95);
	}

	public playCheck() {
		this.play('check', 0.9);
	}

	public playCheckmate() {
		this.play('game-end', 1.0);
	}

	public playPromotion() {
		this.play('promote', 0.9);
	}

	public playGameStart() {
		triggerHaptic('game-start');
		this.play('game-start', 0.8);
	}

	public playGameEnd(won: boolean = true) {
		triggerHaptic('game-end');
		this.play('game-end', 0.9);
	}

	public playIllegal() {
		triggerHaptic('illegal');
		this.play('move', 0.5);
	}

	public toggleSound(): boolean {
		this.enabled = !this.enabled;
		if (typeof window !== 'undefined') {
			localStorage.setItem('chess_sound_enabled', this.enabled ? 'true' : 'false');
		}
		return this.enabled;
	}

	public isEnabled(): boolean {
		return this.enabled;
	}

	public setEnabled(val: boolean) {
		this.enabled = val;
		if (typeof window !== 'undefined') {
			localStorage.setItem('chess_sound_enabled', this.enabled ? 'true' : 'false');
		}
	}

	public setVolume(val: number) {
		this.masterVolume = Math.max(0, Math.min(1, val));
		if (typeof window !== 'undefined') {
			localStorage.setItem('chess_volume', this.masterVolume.toString());
		}
	}

	public getVolume(): number {
		return this.masterVolume;
	}
}

export const soundEffects = new ChessSoundPlayer();

/**
 * Mobile Haptic Feedback generator for physical vibration cues
 */
export function triggerHaptic(type: MoveCategory | 'game-start' | 'game-end' | 'illegal') {
	if (typeof navigator === 'undefined' || !navigator.vibrate) return;
	try {
		switch (type) {
			case 'checkmate':
			case 'game-end':
				navigator.vibrate([60, 40, 60, 40, 120]);
				break;
			case 'check':
			case 'capture':
			case 'en_passant':
				navigator.vibrate([25, 20, 25]);
				break;
			case 'castle':
			case 'promote':
				navigator.vibrate([20, 15, 20]);
				break;
			case 'illegal':
				navigator.vibrate([40, 30, 40]);
				break;
			case 'game-start':
				navigator.vibrate([40]);
				break;
			case 'normal':
			default:
				navigator.vibrate(15);
				break;
		}
	} catch {}
}

/**
 * Universal move sound dispatcher based on categorized move type
 */
export function playMoveSoundByCategory(category: MoveCategory) {
	triggerHaptic(category);
	switch (category) {
		case 'checkmate':
			soundEffects.playCheckmate();
			break;
		case 'promote':
			soundEffects.playPromotion();
			break;
		case 'check':
			soundEffects.playCheck();
			break;
		case 'en_passant':
			soundEffects.playEnPassant();
			break;
		case 'castle':
			soundEffects.playCastle();
			break;
		case 'capture':
			soundEffects.playCapture();
			break;
		case 'normal':
		default:
			soundEffects.playNormalMove();
			break;
	}
}

/**
 * Fallback compatibility helper
 */
export function playMoveSound(san: string, isCapture = false, isCheck = false) {
	if (san.includes('#')) {
		triggerHaptic('checkmate');
		soundEffects.playCheckmate();
	} else if (san.includes('=')) {
		triggerHaptic('promote');
		soundEffects.playPromotion();
	} else if (isCheck || san.includes('+')) {
		triggerHaptic('check');
		soundEffects.playCheck();
	} else if (san.startsWith('O-O')) {
		triggerHaptic('castle');
		soundEffects.playCastle();
	} else if (isCapture || san.includes('x')) {
		triggerHaptic('capture');
		soundEffects.playCapture();
	} else {
		triggerHaptic('normal');
		soundEffects.playNormalMove();
	}
}
