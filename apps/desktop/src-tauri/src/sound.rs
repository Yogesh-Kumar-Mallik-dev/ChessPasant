// ==============================================================================
// ChessPasant Native Audio Playback Engine
// Provides guaranteed, hardware-direct low-latency audio playback for desktop platforms
// Completely independent of WebKitGTK/GStreamer webview restrictions
// ==============================================================================

use std::fs;
use std::process::Command;

const SOUND_MOVE: &[u8] = include_bytes!("../../../web/static/sounds/move.mp3");
const SOUND_CAPTURE: &[u8] = include_bytes!("../../../web/static/sounds/capture.mp3");
const SOUND_CASTLE: &[u8] = include_bytes!("../../../web/static/sounds/castle.mp3");
const SOUND_CHECK: &[u8] = include_bytes!("../../../web/static/sounds/check.mp3");
const SOUND_PROMOTE: &[u8] = include_bytes!("../../../web/static/sounds/promote.mp3");
const SOUND_EN_PASSANT: &[u8] = include_bytes!("../../../web/static/sounds/en-passant.mp3");
const SOUND_GAME_START: &[u8] = include_bytes!("../../../web/static/sounds/game-start.mp3");
const SOUND_GAME_END: &[u8] = include_bytes!("../../../web/static/sounds/game-end.mp3");

#[tauri::command]
pub fn native_play_sound(name: String) {
    std::thread::spawn(move || {
        let (filename, bytes) = match name.as_str() {
            "move" => ("move.mp3", SOUND_MOVE),
            "capture" => ("capture.mp3", SOUND_CAPTURE),
            "castle" => ("castle.mp3", SOUND_CASTLE),
            "check" => ("check.mp3", SOUND_CHECK),
            "promote" => ("promote.mp3", SOUND_PROMOTE),
            "en-passant" => ("en-passant.mp3", SOUND_EN_PASSANT),
            "game-start" => ("game-start.mp3", SOUND_GAME_START),
            "game-end" => ("game-end.mp3", SOUND_GAME_END),
            _ => return,
        };

        let tmp_dir = std::env::temp_dir().join("chesspasant_sounds");
        let _ = fs::create_dir_all(&tmp_dir);
        let file_path = tmp_dir.join(filename);

        // Ensure sound file exists on disk
        if !file_path.exists() || fs::metadata(&file_path).map(|m| m.len()).unwrap_or(0) == 0 {
            let _ = fs::write(&file_path, bytes);
        }

        #[cfg(target_os = "linux")]
        {
            // 1. PipeWire native audio player
            if Command::new("pw-play")
                .arg(&file_path)
                .status()
                .map(|s| s.success())
                .unwrap_or(false)
            {
                return;
            }

            // 2. PulseAudio / PipeWire-pulse player
            if Command::new("paplay")
                .arg(&file_path)
                .status()
                .map(|s| s.success())
                .unwrap_or(false)
            {
                return;
            }

            // 3. mpv fallback
            if Command::new("mpv")
                .args(&[
                    "--no-video",
                    "--volume=100",
                    file_path.to_str().unwrap_or_default(),
                ])
                .status()
                .map(|s| s.success())
                .unwrap_or(false)
            {
                return;
            }

            // 4. aplay fallback
            let _ = Command::new("aplay").arg(&file_path).status();
        }

        #[cfg(target_os = "macos")]
        {
            let _ = Command::new("afplay").arg(&file_path).status();
        }

        #[cfg(target_os = "windows")]
        {
            // Windows WebView2 natively handles audio playback via Web Audio API / HTML5 Audio
            // Spawning powershell/cmd here creates intrusive console window flashes on Windows
        }
    });
}
