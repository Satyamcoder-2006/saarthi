import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  
  Future<void> initialize() async {
    await _tts.setLanguage("en-IN");
    await _tts.setSpeechRate(0.45);  // Slower for elderly
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }
  
  Future<void> setLanguage(String languageCode) async {
    await _tts.setLanguage(languageCode);
  }

  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }
  
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }
  
  Future<void> stop() async {
    await _tts.stop();
  }
}
