## ChessPasant (v0.1.8)

Welcome to the official cross-platform release of **ChessPasant v0.1.8** — a modern, distraction-free chess platform, tactical workout studio, and true native cross-platform application engineered with **Flutter 3.47**, **Dart 3.13**, and **Go 1.24**.

---

### 📦 Official Download Packages

| Platform | Package | Architecture | Format / Target |
| :--- | :--- | :--- | :--- |
| <img src="https://raw.githubusercontent.com/Yogesh-Kumar-Mallik-dev/ChessPasant/main/apps/web/static/icons/archlinux.svg" width="16" height="16" valign="middle" /> **Arch Linux** | `chesspasant-0.1.8-1-x86_64.pkg.tar.zst` | x86_64 | Pacman (`sudo pacman -U`) |
| <img src="https://raw.githubusercontent.com/Yogesh-Kumar-Mallik-dev/ChessPasant/main/apps/web/static/icons/archlinux.svg" width="16" height="16" valign="middle" /> **Arch Linux / AUR** | `ChessPasant_0.1.8_x86_64.tar.gz` | x86_64 | Standalone / AUR `makepkg` |
| <img src="https://raw.githubusercontent.com/Yogesh-Kumar-Mallik-dev/ChessPasant/main/apps/web/static/icons/tux.svg" width="16" height="16" valign="middle" /> **Linux (Universal)** | `ChessPasant_0.1.8_linux_x64.tar.gz` | x86_64 | Portable Standalone Bundle |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/android.svg" width="16" height="16" valign="middle" /> **Android (Universal)** | `ChessPasant_0.1.8.apk` | Universal (arm64, armv7, x86_64) | Sideload / Install on Android 5.0+ |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/googleplay.svg" width="16" height="16" valign="middle" /> **Android (Google Play)** | `ChessPasant_0.1.8.aab` | Universal Bundle | Play Console Publishing |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/windows11.svg" width="16" height="16" valign="middle" /> **Windows (x64)** | `ChessPasant_0.1.8_windows_x64.zip` | x64 | Native `chesspasant.exe` Bundle |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/apple.svg" width="16" height="16" valign="middle" /> **macOS** | `ChessPasant_0.1.8_macos.zip` | Universal / Apple Silicon & Intel | Native `ChessPasant.app` Bundle |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/apple.svg" width="16" height="16" valign="middle" /> **iOS** | `ChessPasant_0.1.8_ios_unsigned.ipa` | arm64 | Sideload via AltStore, SideStore, TrollStore |

---

### 🚀 Highlights in this Release

#### 1. True Native Multiplatform Client
- **Zero Webviews & Direct GPU Canvas**: Compiles down to native machine code with zero webview overhead, drastically reducing memory footprint and offering 120 FPS buttery-smooth board rendering.
- **Staunton Vector Aesthetic**: Crisp, hand-crafted vector pieces that scale infinitely without pixelation.
- **Acoustic Wooden Audio**: Authentic acoustic sound engine providing realistic tactile wood clicks for moves, captures, castling, and checks.
- **Synchronous 0ms FIDE Engine**: Client-side move validator capable of computing full legal moves, checkmate detection, en passant, and promotions with zero latency and no network lag.
- **Tactical Workout Studio**: Interactive Daily Puzzle with mistake detection, error messages, and auto-retraction.
- **Stockfish AI Bots**: Play offline or online against 5 distinct difficulty levels.
- **Live Clock Timers**: Real-time multiplayer synchronization with countdown clocks and flag-fall detection.

#### 2. Engine & UI Bug Fixes
- **Eliminated Knight/Bishop Visual Target Bug**: Fixed race condition where asynchronous network fetches could overwrite piece legal move indicators with previously clicked pieces.
- **Eliminated Windows CMD Flashes**: Move sounds and subprocess spawns on Windows now execute silently without opening temporary command prompt windows.
- **Friendly Challenge Auto-Redirection**: Real-time notification banners and challenge modals now reliably route players straight to their duel room when accepted.
- **Daily Puzzle Move Retraction**: Incorrect tactical attempts are clearly played on board, marked in red, and smoothly retracted after an 800ms preview.

#### 3. Automated Cloud CI/CD Matrix
- Unified GitHub Actions pipeline compiles all 5 platforms simultaneously in the cloud using native Windows, macOS, and Linux runners.

---

### 💻 Installation Notes

- **Arch Linux**: Run `sudo pacman -U chesspasant-0.1.8-1-x86_64.pkg.tar.zst` or extract `ChessPasant_0.1.8_x86_64.tar.gz` and run `./chesspasant`.
- **Linux Standalone**: Extract `ChessPasant_0.1.8_linux_x64.tar.gz` and execute `./chesspasant`.
- **Android**: Download `ChessPasant_0.1.8.apk` and tap to install (enable "Install unknown apps" if prompted).
- **Windows**: Unzip `ChessPasant_0.1.8_windows_x64.zip` and run `chesspasant.exe`.
- **macOS**: Unzip `ChessPasant_0.1.8_macos.zip` and move `ChessPasant.app` to your `/Applications` directory. (On first launch, right-click and select **Open** to approve Gatekeeper).
- **iOS**: Sideload `ChessPasant_0.1.8_ios_unsigned.ipa` using AltStore, SideStore, or TrollStore.
