import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('tts_language') ?? 'en-IN';
    final speed = prefs.getDouble('tts_speed') ?? 0.42; // Slow for elderly

    await _tts.setLanguage(lang);
    await _tts.setSpeechRate(speed);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('[TTS] error: $msg');
    });

    _initialized = true;
  }

  Future<void> speak(String text) async {
    if (!_initialized) await initialize();
    if (_isSpeaking) await _tts.stop();
    debugPrint('[TTS] speaking: "$text"');
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  // Speak confirmation before showing the sheet
  Future<void> speakConfirmation(String actionTitle, String detail) async {
    await speak('$actionTitle. $detail. Say yes to confirm or no to cancel.');
  }

  Future<void> speakSuccess(String message) async {
    await speak(message);
  }

  Future<void> speakError(String message) async {
    await speak(message);
  }

  Future<void> updateLanguage(String languageCode) async {
    await _tts.setLanguage(languageCode);
  }

  Future<void> updateSpeed(double speed) async {
    await _tts.setSpeechRate(speed);
  }
}
