## ChessPasant (v0.1.9)

Welcome to the official cross-platform release of **ChessPasant v0.1.9** — an authentic acoustic chess platform, tactical workout studio, and true native cross-platform application engineered with **Flutter 3.47**, **Dart 3.13**, and **Go 1.24**.

---

### 📦 Official Single-File Installers & Packages

| Platform | Installer / Package | Type | Target / Installation |
| :--- | :--- | :--- | :--- |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/windows11.svg" width="16" height="16" valign="middle" /> **Windows** | `ChessPasant_0.1.9_x64_Setup.exe` | **Single-File Setup Installer** | Standard Windows Setup Wizard (Desktop & Start Menu shortcuts) |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/windows11.svg" width="16" height="16" valign="middle" /> **Windows (Portable)** | `ChessPasant_0.1.9_windows_x64.zip` | Portable Archive | Extract and run `chesspasant.exe` (No installation needed) |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/apple.svg" width="16" height="16" valign="middle" /> **macOS** | `ChessPasant_0.1.9.dmg` | **Single-File Disk Image** | Drag-and-Drop into `/Applications` |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/apple.svg" width="16" height="16" valign="middle" /> **macOS (Portable)** | `ChessPasant_0.1.9_macos.zip` | Compressed Bundle | Unzip and run `ChessPasant.app` |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/ubuntu.svg" width="16" height="16" valign="middle" /> **Debian / Ubuntu** | `chesspasant_0.1.9_amd64.deb` | **Single-File Debian Package** | Double-click or `sudo dpkg -i` |
| <img src="https://raw.githubusercontent.com/Yogesh-Kumar-Mallik-dev/ChessPasant/main/apps/web/static/icons/archlinux.svg" width="16" height="16" valign="middle" /> **Arch Linux** | `chesspasant-0.1.9-1-x86_64.pkg.tar.zst` | Pacman Package | Pacman (`sudo pacman -U`) |
| <img src="https://raw.githubusercontent.com/Yogesh-Kumar-Mallik-dev/ChessPasant/main/apps/web/static/icons/tux.svg" width="16" height="16" valign="middle" /> **Linux (Universal)** | `ChessPasant_0.1.9_linux_x64.tar.gz` | Standalone Tarball | Portable Linux Bundle |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/android.svg" width="16" height="16" valign="middle" /> **Android (Universal)** | `ChessPasant_0.1.9.apk` | **Single-File APK** | Sideload / Install on Android 5.0+ |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/googleplay.svg" width="16" height="16" valign="middle" /> **Android (Google Play)** | `ChessPasant_0.1.9.aab` | Universal Bundle | Play Console Publishing |
| <img src="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/apple.svg" width="16" height="16" valign="middle" /> **iOS** | `ChessPasant_0.1.9_ios_unsigned.ipa` | Sideload IPA | Sideload via AltStore, SideStore, TrollStore |

---

### 🚀 Highlights in this Release (v0.1.9)

#### 1. Authentic Studio Noir Monochrome Design Overhaul
- **Complete Visual Parity**: Replaced generic green palette with the official **Monochrome Studio Noir** palette (`#0F0F12` canvas, `#18181D` surface cards, `#1F1F25` surface panels, `#292931` borders, pure `#FAFAFA` text).
- **Monochrome Chess Board**: Rebuilt square rendering to use `#F4F4F6` light and `#30323D` dark squares, highlighted with a clean `#FBBF24` amber aura for selected squares and last move indicators.
- **Signature Floating Navigation Dock**: Implemented the signature floating bottom pill dock with translucent backdrop blur, active tab indicator, haptic feedback, and safe-area padding across 5 core views (**Play**, **Online**, **Puzzles**, **Analysis**, and **Rankings**).
- **Exact Vector SVG Icons**: Full integration of authentic vector icons (`swords`, `zap`, `flame`, `timer`, `hourglass`, `puzzle`, `search`, `trophy`, `users`, `handshake`, `smart_toy`).
- **Quick Pairing Matrix**: 8-preset 1-tap matchmaking grid (Bullet, Blitz, Rapid, Classical) with "HOT" badges and live rating pills.

#### 2. True Native Multiplatform Performance
- **Zero Webviews & Direct GPU Canvas**: Compiles down to native machine code with zero webview overhead, drastically reducing memory footprint and offering 120 FPS buttery-smooth board rendering.
- **Staunton Vector Aesthetic**: Crisp, hand-crafted vector pieces that scale infinitely without pixelation.
- **Acoustic Wooden Audio**: Authentic acoustic sound engine providing realistic tactile wood clicks for moves, captures, castling, and checks.
- **Synchronous 0ms FIDE Engine**: Client-side move validator capable of computing full legal moves, checkmate detection, en passant, and promotions with zero latency and no network lag.

---

### 💻 Installation Instructions

- **Windows**: Download `ChessPasant_0.1.9_x64_Setup.exe` and follow the setup wizard. (Or use the portable ZIP).
- **macOS**: Open `ChessPasant_0.1.9.dmg` and drag `ChessPasant` into `Applications`. (On first launch, right-click and select **Open** to approve Gatekeeper).
- **Debian / Ubuntu**: Double-click `chesspasant_0.1.9_amd64.deb` to install via your software center (or run `sudo dpkg -i chesspasant_0.1.9_amd64.deb`).
- **Arch Linux**: Run `sudo pacman -U chesspasant-0.1.9-1-x86_64.pkg.tar.zst`.
- **Linux Standalone**: Extract `ChessPasant_0.1.9_linux_x64.tar.gz` and run `./chesspasant`.
- **Android**: Download `ChessPasant_0.1.9.apk` and tap to install (enable "Install unknown apps" if prompted).
- **iOS**: Sideload `ChessPasant_0.1.9_ios_unsigned.ipa` using AltStore, SideStore, or TrollStore.
