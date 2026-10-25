use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

#[cfg(target_os = "windows")]
use std::os::windows::process::CommandExt;

fn create_engine_command<P: AsRef<std::ffi::OsStr>>(program: P) -> Command {
    #[allow(unused_mut)]
    let mut cmd = Command::new(program);
    #[cfg(target_os = "windows")]
    {
        // 0x08000000 = CREATE_NO_WINDOW - Prevents flashing cmd console on Windows
        cmd.creation_flags(0x08000000);
    }
    cmd
}

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct NativeEngineInfo {
    pub available: bool,
    pub path: Option<String>,
    pub name: String,
}

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct NativeEvalResult {
    pub fen: String,
    #[serde(rename = "scoreCp")]
    pub score_cp: i32,
    #[serde(rename = "isMate")]
    pub is_mate: bool,
    #[serde(rename = "mateIn", skip_serializing_if = "Option::is_none")]
    pub mate_in: Option<i32>,
    #[serde(rename = "bestMove")]
    pub best_move: String,
    pub pv: Vec<String>,
    pub depth: u32,
    #[serde(rename = "winChance")]
    pub win_chance: f64,
}

/// Locates a viable Stockfish executable on the system or bundled with the desktop app.
pub fn find_stockfish() -> Option<PathBuf> {
    // 1. Check explicit environment override
    if let Ok(custom_path) = std::env::var("STOCKFISH_PATH") {
        let p = PathBuf::from(custom_path);
        if p.exists() {
            return Some(p);
        }
    }

    // 2. Check application directory (e.g. bundled sidecar or portable folder)
    if let Ok(exe_path) = std::env::current_exe() {
        if let Some(parent) = exe_path.parent() {
            let bundled_candidates = [
                parent.join("stockfish"),
                parent.join("stockfish.exe"),
                parent.join("bin").join("stockfish"),
                parent.join("bin").join("stockfish.exe"),
                parent.join("resources").join("stockfish"),
                parent.join("resources").join("bin").join("stockfish"),
                parent.join("resources").join("bin").join("stockfish.exe"),
                parent.join("..").join("lib").join("chesspasant").join("stockfish"),
                parent.join("..").join("share").join("chesspasant").join("stockfish"),
            ];
            for candidate in bundled_candidates {
                if candidate.exists() {
                    return Some(candidate);
                }
            }
        }
    }

    // 3. Check standard system locations per OS
    let system_candidates = [
        // Linux / Unix standard and package paths
        "/usr/lib/chesspasant/stockfish",
        "/usr/share/chesspasant/stockfish",
        "/usr/games/stockfish",
        "/usr/bin/stockfish",
        "/usr/local/bin/stockfish",
        "/opt/homebrew/bin/stockfish",
        // Windows
        "C:\\Program Files\\Stockfish\\stockfish.exe",
        "C:\\Stockfish\\stockfish.exe",
    ];

    for c in system_candidates {
        let p = Path::new(c);
        if p.exists() {
            return Some(p.to_path_buf());
        }
    }

    // 4. Try PATH lookup
    if let Ok(output) = create_engine_command("stockfish").arg("uci").output() {
        if output.status.success() {
            return Some(PathBuf::from("stockfish"));
        }
    }

    None
}

#[tauri::command]
pub fn native_engine_info() -> NativeEngineInfo {
    match find_stockfish() {
        Some(path) => NativeEngineInfo {
            available: true,
            path: Some(path.to_string_lossy().to_string()),
            name: "Native Stockfish Engine".to_string(),
        },
        None => NativeEngineInfo {
            available: false,
            path: None,
            name: "Native Engine Not Found".to_string(),
        },
    }
}

#[tauri::command]
pub fn native_engine_evaluate(fen: String, depth: u32) -> Result<NativeEvalResult, String> {
    let binary = find_stockfish().ok_or_else(|| "Stockfish binary not found on desktop".to_string())?;

    let depth = depth.clamp(1, 30);

    let mut child = create_engine_command(&binary)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("failed to spawn stockfish: {}", e))?;

    let mut stdin = child.stdin.take().ok_or("failed to open stdin")?;
    let stdout = child.stdout.take().ok_or("failed to open stdout")?;
    let reader = BufReader::new(stdout);

    // Write UCI commands
    let commands = format!(
        "uci\nisready\nposition fen {}\ngo depth {}\n",
        fen, depth
    );
    stdin
        .write_all(commands.as_bytes())
        .map_err(|e| format!("failed to write to engine: {}", e))?;
    let _ = stdin.flush();

    let mut score_cp = 0;
    let mut is_mate = false;
    let mut mate_in = None;
    let mut best_move = String::new();
    let mut pv = Vec::new();
    let mut actual_depth = depth;

    let start = Instant::now();
    let timeout = Duration::from_secs(12);

    for line_res in reader.lines() {
        if start.elapsed() > timeout {
            let _ = child.kill();
            break;
        }

        let line = match line_res {
            Ok(l) => l,
            Err(_) => break,
        };

        if line.starts_with("info ") && line.contains(" score ") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            for i in 0..parts.len() {
                if parts[i] == "depth" && i + 1 < parts.len() {
                    if let Ok(d) = parts[i + 1].parse::<u32>() {
                        actual_depth = d;
                    }
                }
                if parts[i] == "score" && i + 2 < parts.len() {
                    if parts[i + 1] == "cp" {
                        if let Ok(cp) = parts[i + 2].parse::<i32>() {
                            score_cp = cp;
                            is_mate = false;
                            mate_in = None;
                        }
                    } else if parts[i + 1] == "mate" {
                        if let Ok(m) = parts[i + 2].parse::<i32>() {
                            is_mate = true;
                            mate_in = Some(m);
                            score_cp = if m > 0 { 10000 } else { -10000 };
                        }
                    }
                }
                if parts[i] == "pv" {
                    pv = parts[i + 1..].iter().map(|s| s.to_string()).collect();
                }
            }
        }

        if line.starts_with("bestmove ") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                best_move = parts[1].to_string();
            }
            break;
        }
    }

    let _ = child.kill();

    // Stockfish UCI protocol evaluates relative to the side to move.
    // Convert to White-centric perspective (positive = White leads, negative = Black leads).
    let is_black = fen.split_whitespace().nth(1) == Some("b");
    if is_black {
        score_cp = -score_cp;
        if is_mate {
            mate_in = mate_in.map(|m| -m);
        }
    }

    // Standard Lichess win chance formula
    let win_chance = if is_mate {
        if mate_in.unwrap_or(0) > 0 {
            100.0
        } else {
            0.0
        }
    } else {
        let cp_f = score_cp as f64;
        let p = 50.0 + 50.0 * (2.0 / (1.0 + (-0.00368208 * cp_f).exp()) - 1.0);
        p.clamp(0.0, 100.0)
    };

    Ok(NativeEvalResult {
        fen,
        score_cp,
        is_mate,
        mate_in,
        best_move,
        pv,
        depth: actual_depth,
        win_chance,
    })
}

#[tauri::command]
pub fn native_engine_bot_move(fen: String, level: u32) -> Result<String, String> {
    let binary = find_stockfish().ok_or_else(|| "Stockfish binary not found on desktop".to_string())?;

    let skill_level = ((level.clamp(1, 10) - 1) * 2).clamp(0, 20);
    let depth = (level.clamp(1, 10) + 2).clamp(3, 15);

    let mut child = create_engine_command(&binary)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("failed to spawn stockfish: {}", e))?;

    let mut stdin = child.stdin.take().ok_or("failed to open stdin")?;
    let stdout = child.stdout.take().ok_or("failed to open stdout")?;
    let reader = BufReader::new(stdout);

    let commands = format!(
        "uci\nsetoption name Skill Level value {}\nisready\nposition fen {}\ngo depth {}\n",
        skill_level, fen, depth
    );
    stdin
        .write_all(commands.as_bytes())
        .map_err(|e| format!("failed to write to engine: {}", e))?;
    let _ = stdin.flush();

    let mut best_move = String::new();
    let start = Instant::now();
    let timeout = Duration::from_secs(6);

    for line_res in reader.lines() {
        if start.elapsed() > timeout {
            let _ = child.kill();
            break;
        }

        let line = match line_res {
            Ok(l) => l,
            Err(_) => break,
        };

        if line.starts_with("bestmove ") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                best_move = parts[1].to_string();
            }
            break;
        }
    }

    let _ = child.kill();

    if best_move.is_empty() {
        return Err("engine did not return a move".to_string());
    }

    Ok(best_move)
}
