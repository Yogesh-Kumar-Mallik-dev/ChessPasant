## ChessPasant (v0.1.8)

Welcome to the official cross-platform release of **ChessPasant v0.1.8** — a modern, distraction-free chess platform, tactical workout studio, and true native cross-platform application engineered with **Flutter 3.47**, **Dart 3.13**, and **Go 1.24**.

---

### 📦 Official Single-File Installers & Packages

| Platform | Installer / Package | Type | Target / Installation |
| :--- | :--- | :--- | :--- |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/windows11.svg" width="16" height="16" valign="middle" /> **Windows** | `ChessPasant_0.1.8_x64_Setup.exe` | **Single-File Setup Installer** | Standard Windows Setup Wizard (Desktop & Start Menu shortcuts) |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/windows11.svg" width="16" height="16" valign="middle" /> **Windows (Portable)** | `ChessPasant_0.1.8_windows_x64.zip` | Portable Archive | Extract and run `chesspasant.exe` (No installation needed) |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/apple.svg" width="16" height="16" valign="middle" /> **macOS** | `ChessPasant_0.1.8.dmg` | **Single-File Disk Image** | Drag-and-Drop into `/Applications` |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/apple.svg" width="16" height="16" valign="middle" /> **macOS (Portable)** | `ChessPasant_0.1.8_macos.zip` | Compressed Bundle | Unzip and run `ChessPasant.app` |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/ubuntu.svg" width="16" height="16" valign="middle" /> **Debian / Ubuntu** | `chesspasant_0.1.8_amd64.deb` | **Single-File Debian Package** | Double-click or `sudo dpkg -i` |
| <img src="https://raw.githubusercontent.com/Yogesh-Kumar-Mallik-dev/ChessPasant/main/apps/web/static/icons/archlinux.svg" width="16" height="16" valign="middle" /> **Arch Linux** | `chesspasant-0.1.8-1-x86_64.pkg.tar.zst` | Pacman Package | Pacman (`sudo pacman -U`) |
| <img src="https://raw.githubusercontent.com/Yogesh-Kumar-Mallik-dev/ChessPasant/main/apps/web/static/icons/tux.svg" width="16" height="16" valign="middle" /> **Linux (Universal)** | `ChessPasant_0.1.8_linux_x64.tar.gz` | Standalone Tarball | Portable Linux Bundle |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/android.svg" width="16" height="16" valign="middle" /> **Android (Universal)** | `ChessPasant_0.1.8.apk` | **Single-File APK** | Sideload / Install on Android 5.0+ |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/googleplay.svg" width="16" height="16" valign="middle" /> **Android (Google Play)** | `ChessPasant_0.1.8.aab` | Universal Bundle | Play Console Publishing |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/apple.svg" width="16" height="16" valign="middle" /> **iOS** | `ChessPasant_0.1.8_ios_unsigned.ipa` | Sideload IPA | Sideload via AltStore, SideStore, TrollStore |

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

- **Windows**: Download `ChessPasant_0.1.8_x64_Setup.exe` and follow the setup wizard. (Or use the portable ZIP).
- **macOS**: Open `ChessPasant_0.1.8.dmg` and drag `ChessPasant` into `Applications`. (On first launch, right-click and select **Open** to approve Gatekeeper).
- **Debian / Ubuntu**: Double-click `chesspasant_0.1.8_amd64.deb` to install via your software center (or run `sudo dpkg -i chesspasant_0.1.8_amd64.deb`).
- **Arch Linux**: Run `sudo pacman -U chesspasant-0.1.8-1-x86_64.pkg.tar.zst`.
- **Linux Standalone**: Extract `ChessPasant_0.1.8_linux_x64.tar.gz` and run `./chesspasant`.
- **Android**: Download `ChessPasant_0.1.8.apk` and tap to install (enable "Install unknown apps" if prompted).
- **iOS**: Sideload `ChessPasant_0.1.8_ios_unsigned.ipa` using AltStore, SideStore, or TrollStore.
