import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundEffects {
  static final SoundEffects _instance = SoundEffects._internal();
  factory SoundEffects() => _instance;
  SoundEffects._internal();

  final AudioPlayer _player = AudioPlayer();
  double _volume = 0.85;
  bool _enabled = true;

  double get volume => _volume;
  bool get isEnabled => _enabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble('chess_volume') ?? 0.85;
    _enabled = prefs.getBool('chess_sound_enabled') ?? true;
    await _player.setVolume(_volume);
    await _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> setVolume(double val) async {
    _volume = val.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('chess_volume', _volume);
  }

  Future<void> setEnabled(bool val) async {
    _enabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chess_sound_enabled', _enabled);
  }

  Future<void> play(String name) async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$name.mp3'), volume: _volume);
    } catch (_) {}
  }

  void playNormalMove() => play('move');
  void playCapture() => play('capture');
  void playCastle() => play('castle');
  void playCheck() => play('check');
  void playPromotion() => play('promote');
  void playEnPassant() => play('en-passant');
  void playGameStart() => play('game-start');
  void playGameEnd() => play('game-end');
  void playIllegal() => play('move');

  void playMoveSound({
    required String san,
    bool isCapture = false,
    bool isCheck = false,
  }) {
    if (san.contains('#')) {
      playGameEnd();
    } else if (san.contains('=')) {
      playPromotion();
    } else if (isCheck || san.contains('+')) {
      playCheck();
    } else if (san.startsWith('O-O')) {
      playCastle();
    } else if (isCapture || san.contains('x')) {
      playCapture();
    } else {
      playNormalMove();
    }
  }
}
