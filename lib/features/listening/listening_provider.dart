import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/intent_response.dart';
import '../../core/services/api_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/fuzzy_matcher.dart';
import '../action/action_executor.dart';

enum PipelineState {
  idle,           // Nothing happening
  listening,      // Mic is open, Vosk running
  transcribing,   // Got transcript, sending to backend
  confirming,     // Showing confirmation sheet to user
  executing,      // Running the action
  done,           // Action complete
  error,          // Something went wrong
}

class ListeningProvider extends ChangeNotifier {
  final VoiceService _voiceService;
  final ApiService _apiService;
  final TtsService _ttsService;
  final StorageService _storageService;

  ListeningProvider({
    required VoiceService voiceService,
    required ApiService apiService,
    required TtsService ttsService,
    required StorageService storageService,
  })  : _voiceService = voiceService,
        _apiService = apiService,
        _ttsService = ttsService,
        _storageService = storageService {
    // Wire up voice service → pipeline
    _voiceService.onFinalTranscript.listen(_onTranscriptReady);
  }

  // ── State ────────────────────────────────────────────────────────
  PipelineState _pipelineState = PipelineState.idle;
  PipelineState get pipelineState => _pipelineState;

  String _livePartialText = '';
  String get livePartialText => _livePartialText;

  String _lastTranscript = '';
  String get lastTranscript => _lastTranscript;

  IntentResponse? _pendingIntent;
  IntentResponse? get pendingIntent => _pendingIntent;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  StreamSubscription? _partialSub;

  // ─────────────────────────────────────────────────────────────────
  // STEP 1: User taps mic → start listening
  // ─────────────────────────────────────────────────────────────────
  Future<void> startListening() async {
    if (_pipelineState != PipelineState.idle &&
        _pipelineState != PipelineState.done &&
        _pipelineState != PipelineState.error) return;

    _livePartialText = '';
    _pendingIntent = null;
    _errorMessage = null;
    _setPipelineState(PipelineState.listening);

    // Show live partial text in the UI
    _partialSub = _voiceService.onPartialText.listen((text) {
      _livePartialText = text;
      notifyListeners();
    });

    // Initialize voice service if not already done
    if (_voiceService.state == VoiceState.idle ||
        _voiceService.state == VoiceState.error) {
      await _voiceService.initialize();
    }

    if (_voiceService.state != VoiceState.ready) {
      _setError('Voice recognition not available. Please restart the app.');
      return;
    }

    await _voiceService.startListening();
  }

  // ─────────────────────────────────────────────────────────────────
  // STEP 2: Vosk auto-stops → transcript is ready → send to backend
  // This is called automatically when VoiceService emits onFinalTranscript
  // ─────────────────────────────────────────────────────────────────
  Future<void> _onTranscriptReady(String transcript) async {
    _partialSub?.cancel();
    _lastTranscript = transcript;
    _livePartialText = transcript;
    notifyListeners();

    debugPrint('[Pipeline] transcript ready: "$transcript"');

    if (transcript.trim().isEmpty) {
      _setError("I didn't hear anything. Please try again.");
      await _ttsService.speak("I didn't hear anything. Please try again.");
      return;
    }

    _setPipelineState(PipelineState.transcribing);

    // ── Send to backend ───────────────────────────────────────────
    final userId = await _getDeviceId();
    final intent = await _apiService.parseIntent(transcript, userId);

    if (intent == null) {
      _setError("Couldn't connect to assistant. Check your WiFi.");
      await _ttsService.speak("I couldn't connect. Please check your WiFi and try again.");
      _voiceService.markProcessingDone();
      return;
    }

    // ── Local Safety Net ──────────────────────────────────────────
    // If backend found a contact name but no phone, or didn't find the name
    // but the transcript contains a known contact name.
    IntentResponse processedIntent = intent;
    if ((intent.intent == 'call_contact' || intent.intent == 'send_whatsapp') &&
        (intent.phone == null || intent.phone!.isEmpty)) {
      
      final localContacts = _storageService.contactsBox.values.toList();
      final contactName = intent.contact ?? '';
      
      if (contactName.isNotEmpty) {
        final matches = FuzzyMatcher.searchContacts(contactName, localContacts);
        if (matches.isNotEmpty) {
          processedIntent = intent.copyWith(
            phone: matches.first.phone,
            contact: matches.first.name,
          );
          debugPrint('[Pipeline] Local safety net matched: ${processedIntent.contact} (${processedIntent.phone})');
        }
      }
    }

    if (!processedIntent.isValid) {
      _setError("I didn't understand that. Please try again.");
      await _ttsService.speak("Sorry, I didn't understand that. Could you say it again?");
      _voiceService.markProcessingDone();
      _setPipelineState(PipelineState.idle);
      return;
    }

    debugPrint('[Pipeline] intent received: ${processedIntent.intent}, confidence=${processedIntent.confidence}');

    // ── Speak confirmation ────────────────────────────────────────
    _pendingIntent = processedIntent;
    _setPipelineState(PipelineState.confirming);
    await _ttsService.speakConfirmation(processedIntent.actionTitle, processedIntent.actionDetail);

    // NOTE: At this point, the UI (ListeningOverlay) sees pipelineState == confirming
    // and shows the ConfirmationSheet automatically. See listening_overlay.dart.
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // STEP 3: User taps "Yes" on confirmation sheet → execute action
  // ─────────────────────────────────────────────────────────────────
  Future<void> confirmAndExecute() async {
    if (_pendingIntent == null) return;
    _setPipelineState(PipelineState.executing);

    final intent = _pendingIntent!;
    final userId = await _getDeviceId();

    bool success = false;
    String? spokenResult;

    try {
      final result = await ActionExecutor.execute(intent);
      success = result.success;
      spokenResult = result.spokenFeedback;
    } catch (e) {
      debugPrint('[Pipeline] execute error: $e');
      success = false;
      spokenResult = 'Something went wrong. Please try again.';
    }

    // Log to backend (non-blocking)
    _apiService.logAction(
      userId: userId,
      intent: intent.intent,
      rawText: _lastTranscript,
      success: success,
    );

    // Speak the result
    if (spokenResult != null) {
      await _ttsService.speak(spokenResult);
    }

    _voiceService.markProcessingDone();
    _setPipelineState(PipelineState.done);
  }

  // ─────────────────────────────────────────────────────────────────
  // STEP 3 (alternative): User taps "Cancel"
  // ─────────────────────────────────────────────────────────────────
  Future<void> cancelConfirmation() async {
    _pendingIntent = null;
    _voiceService.markProcessingDone();
    await _ttsService.speak("Cancelled.");
    _setPipelineState(PipelineState.idle);
  }

  // ─────────────────────────────────────────────────────────────────
  // Manual stop (user taps X on listening overlay)
  // ─────────────────────────────────────────────────────────────────
  Future<void> stopListening() async {
    _partialSub?.cancel();
    await _voiceService.stopListening();
    _livePartialText = '';
    _setPipelineState(PipelineState.idle);
  }

  // ─────────────────────────────────────────────────────────────────
  // Reset to idle
  // ─────────────────────────────────────────────────────────────────
  void reset() {
    _pendingIntent = null;
    _errorMessage = null;
    _livePartialText = '';
    _lastTranscript = '';
    _voiceService.markProcessingDone();
    _setPipelineState(PipelineState.idle);
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────
  void _setPipelineState(PipelineState s) {
    _pipelineState = s;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _setPipelineState(PipelineState.error);
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      id = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_id', id);
    }
    return id;
  }

  @override
  void dispose() {
    _partialSub?.cancel();
    super.dispose();
  }
}
