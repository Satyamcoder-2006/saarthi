import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/tts_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService storageService;
  final TtsService ttsService;

  double _textScale = AppConstants.defaultTextScale;
  bool _highContrast = false;
  String _language = 'en-IN';
  double _voiceSpeed = 0.45;

  SettingsProvider({required this.storageService, required this.ttsService}) {
    _loadSettings();
  }

  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  String get language => _language;
  double get voiceSpeed => _voiceSpeed;

  void _loadSettings() {
    _textScale = storageService.getDouble(AppConstants.prefsTextScale, defaultValue: AppConstants.defaultTextScale);
    _highContrast = storageService.getBool(AppConstants.prefsHighContrast, defaultValue: false);
    _language = storageService.getString('language') ?? 'en-IN';
    _voiceSpeed = storageService.getDouble('voice_speed', defaultValue: 0.45);
  }

  Future<void> setTextScale(double scale) async {
    _textScale = scale;
    await storageService.setDouble(AppConstants.prefsTextScale, scale);
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    await storageService.setBool(AppConstants.prefsHighContrast, value);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    await storageService.setString('language', lang);
    await ttsService.updateLanguage(lang);
    notifyListeners();
  }

  Future<void> setVoiceSpeed(double speed) async {
    _voiceSpeed = speed;
    await storageService.setDouble('voice_speed', speed);
    await ttsService.updateSpeed(speed);
    notifyListeners();
  }
}
