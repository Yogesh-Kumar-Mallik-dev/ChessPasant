## ChessPasant (v0.2.0)

Welcome to the milestone cross-platform release of **ChessPasant v0.2.0** — featuring complete parity with the web platform, full Studio Noir aesthetics, real player profiles and authentication, genuine global leaderboards, interactive analysis studio with live Stockfish evaluation & EvalBar, and comprehensive online matchmaking time controls.

---

### 📦 Official Single-File Installers & Packages

| Platform | Installer / Package | Type | Target / Installation |
| :--- | :--- | :--- | :--- |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/windows11.svg" width="16" height="16" valign="middle" /> **Windows** | `ChessPasant_0.2.0_x64_Setup.exe` | **Single-File Setup Installer** | Standard Windows Setup Wizard (Desktop & Start Menu shortcuts) |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/windows11.svg" width="16" height="16" valign="middle" /> **Windows (Portable)** | `ChessPasant_0.2.0_windows_x64.zip` | Portable Archive | Extract and run `chesspasant.exe` (No installation needed) |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/apple.svg" width="16" height="16" valign="middle" /> **macOS** | `ChessPasant_0.2.0.dmg` | **Single-File Disk Image** | Drag-and-Drop into `/Applications` |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/apple.svg" width="16" height="16" valign="middle" /> **macOS (Portable)** | `ChessPasant_0.2.0_macos.zip` | Compressed Bundle | Unzip and run `ChessPasant.app` |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/ubuntu.svg" width="16" height="16" valign="middle" /> **Debian / Ubuntu** | `chesspasant_0.2.0_amd64.deb` | **Single-File Debian Package** | Double-click or `sudo dpkg -i` |
| <img src="https://raw.githubusercontent.com/Yogesh-Kumar-Mallik-dev/ChessPasant/main/apps/web/static/icons/archlinux.svg" width="16" height="16" valign="middle" /> **Arch Linux** | `chesspasant-0.2.0-1-x86_64.pkg.tar.zst` | Pacman Package | Pacman (`sudo pacman -U`) |
| <img src="https://raw.githubusercontent.com/Yogesh-Kumar-Mallik-dev/ChessPasant/main/apps/web/static/icons/tux.svg" width="16" height="16" valign="middle" /> **Linux (Universal)** | `ChessPasant_0.2.0_linux_x64.tar.gz` | Standalone Tarball | Portable Linux Bundle |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/android.svg" width="16" height="16" valign="middle" /> **Android (Universal)** | `ChessPasant_0.2.0.apk` | **Single-File APK** | Sideload / Install on Android 5.0+ |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/googleplay.svg" width="16" height="16" valign="middle" /> **Android (Google Play)** | `ChessPasant_0.2.0.aab` | Universal Bundle | Play Console Publishing |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/apple.svg" width="16" height="16" valign="middle" /> **iOS** | `ChessPasant_0.2.0_ios_unsigned.ipa` | Sideload IPA | Sideload via AltStore, SideStore, TrollStore |

---

### 🚀 Highlights in this Release (v0.2.0)

#### 1. Full Online Play Types & Matchmaking Matrix
- **All Standard Time Controls Re-added**: 1 min Bullet (`zap`), 2 | 1 Bullet (`zap`), 3 min Blitz (`flame`, Popular), 3 | 2 Blitz (`flame`), 5 min Blitz (`flame`), 10 min Rapid (`timer`), 15 | 10 Rapid (`timer`), and 30 min Classical (`hourglass`).
- **Custom Time Controls**: Added configurable initial minutes slider (1 to 60 min), increment slider (0 to 30 sec), rated vs casual toggle, and color preference picker (Random, White, Black).
- **Live Matchmaking Queue**: Real-time matchmaking queue with elapsed timer, dynamic rating tolerance (`±50`, `±100`, `±250`, `Any`), and automatic transition into the live game board upon match discovery.

#### 2. User Authentication & Profile
- **Dock Integration**: Replaced generic rankings icon on the signature dock with **Profile** (`user` icon).
- **Studio Noir Sign In & Sign Up**: In-app account creation, login with credentials, secure JWT token storage, and session restoration.
- **Profile Performance Overview**: Displays player ratings across all categories (Bullet, Blitz, Rapid, Classical, Tactics) retrieved live from the backend.
- **Real Global Standings**: Removed placeholder rankings and replaced with real backend leaderboard pools (Bullet, Blitz, Rapid, Classical, Puzzles) accessible directly from the player profile.

#### 3. True Analysis Studio (Web App Parity)
- **Vertical EvalBar**: Added dynamic vertical advantage bar beside the board visualizing centipawn evaluation (+1.5, -2.1, M2, etc.) with a smooth sigmoid distribution.
- **Live Stockfish Engine Evaluation**: Real-time depth calculation (Depth 12+), best move line recommendation, principal variation (PV), and engine on/off switch.
- **Move Navigation**: Complete move traversal controls (`|<` start, `<` prev, `>` next, `>|` latest).
- **Interactive Move Notation Tree**: Full numbered turn list (`1. e4 e5 2. Nf3...`) where tapping any move jumps the board instantly to that position.
- **FEN Loading**: Ability to paste custom FEN strings to analyze any position.

---

### 💻 Installation Instructions

- **Windows**: Download `ChessPasant_0.2.0_x64_Setup.exe` and follow the setup wizard.
- **macOS**: Open `ChessPasant_0.2.0.dmg` and drag `ChessPasant` into `Applications`.
- **Debian / Ubuntu**: Double-click `chesspasant_0.2.0_amd64.deb` to install via software center or `sudo dpkg -i`.
- **Arch Linux**: Run `sudo pacman -U chesspasant-0.2.0-1-x86_64.pkg.tar.zst`.
- **Linux Standalone**: Extract `ChessPasant_0.2.0_linux_x64.tar.gz` and run `./chesspasant`.
- **Android**: Download `ChessPasant_0.2.0.apk` and tap to install.
- **iOS**: Sideload `ChessPasant_0.2.0_ios_unsigned.ipa` using AltStore, SideStore, or TrollStore.
