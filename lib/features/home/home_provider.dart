import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/models/action_log.dart';
import '../../core/models/intent_response.dart';
import 'package:uuid/uuid.dart';

class HomeProvider extends ChangeNotifier {
  final ApiService apiService;
  final VoiceService voiceService;
  final TtsService ttsService;

  bool isConnected = false;
  bool isListening = false;
  List<ActionLog> recentActions = [];
  String _userId = const Uuid().v4();

  HomeProvider({
    required this.apiService,
    required this.voiceService,
    required this.ttsService,
  });

  void setUserId(String id) {
    _userId = id;
  }

  Future<void> checkConnection() async {
    isConnected = await apiService.checkHealth();
    notifyListeners();
  }

  Future<void> loadRecentActions() async {
    if (!isConnected) return;
    try {
      final history = await apiService.getHistory();
      recentActions = history.take(3).toList();
      notifyListeners();
    } catch (e) {
      print("Failed to load history: $e");
    }
  }

  Future<void> startListening() async {
    await voiceService.startListening();
    isListening = true;
    notifyListeners();
  }
  
  void stopListening() {
    voiceService.stopListening();
    isListening = false;
    notifyListeners();
  }
}
