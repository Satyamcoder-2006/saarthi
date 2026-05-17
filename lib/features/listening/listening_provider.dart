import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/intent_response.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/utils/fuzzy_matcher.dart';
import '../action/action_executor.dart';

enum PipelineState {
  idle,         // Nothing happening, home screen visible
  listening,    // Mic open, Google STT running, overlay shown
  transcribing, // Got final text, HTTP request sent to backend
  confirming,   // Intent received, showing ConfirmationSheet
  executing,    // User tapped Yes, action running
  done,         // Action complete, back to home
  error,        // Something went wrong
}

class ListeningProvider extends ChangeNotifier {
  final VoiceService _voice;
  final ApiService _api;
  final TtsService _tts;
  final StorageService _storage;

  ListeningProvider({
    required VoiceService voiceService,
    required ApiService apiService,
    required TtsService ttsService,
    required StorageService storageService,
  })  : _voice = voiceService,
        _api = apiService,
        _tts = ttsService,
        _storage = storageService {
    // Wire VoiceService → pipeline
    // When Google STT fires a final result, this provider handles it.
    _voice.onFinalTranscript.listen(_onFinalTranscript);
  }

  // ── Public state (UI reads these) ────────────────────────────────
  PipelineState _state = PipelineState.idle;
  PipelineState get pipelineState => _state;

  // Live partial text (updates every ~300ms while user speaks)
  String _liveText = '';
  String get liveText => _liveText;

  // The last committed transcript (shown in overlay after speaking)
  String _lastTranscript = '';
  String get lastTranscript => _lastTranscript;

  // The intent returned by the backend (or parsed locally)
  IntentResponse? _pendingIntent;
  IntentResponse? get pendingIntent => _pendingIntent;

  // Error message for overlay UI
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Subscription to live partial text stream
  StreamSubscription<String>? _partialSub;

  // ─────────────────────────────────────────────────────────────────
  // STAGE 1: User taps mic → start listening
  // ─────────────────────────────────────────────────────────────────
  Future<void> startListening() async {
    // Don't start if already in the middle of something
    if (_state == PipelineState.listening ||
        _state == PipelineState.transcribing ||
        _state == PipelineState.executing) return;

    // Reset everything
    _liveText = '';
    _lastTranscript = '';
    _pendingIntent = null;
    _errorMessage = null;
    _setState(PipelineState.listening);

    // Subscribe to live partial text for overlay UI
    _partialSub?.cancel();
    _partialSub = _voice.onPartialText.listen((text) {
      _liveText = text;
      notifyListeners();
    });

    // Initialize Google STT if needed (first call only)
    if (_voice.state == VoiceState.idle || _voice.state == VoiceState.error) {
      final ok = await _voice.initialize();
      if (!ok) {
        _setError(
          _voice.errorMessage ??
              'Could not start voice recognition. Please try again.',
        );
        await _tts.speak(
          'Could not start the microphone. Please check your permissions.',
        );
        return;
      }
    }

    // Open the mic — Google STT starts listening
    await _voice.startListening();
  }

  // ─────────────────────────────────────────────────────────────────
  // STAGES 3 & 4: Google STT fires final result → send to backend & apply local safety net
  // ─────────────────────────────────────────────────────────────────
  Future<void> _onFinalTranscript(String transcript) async {
    // Cancel partial text subscription (no more live updates needed)
    _partialSub?.cancel();

    _lastTranscript = transcript;
    _liveText = transcript; // freeze the final text on screen
    notifyListeners();

    debugPrint('[Pipeline] STAGE 3 — transcript: "$transcript"');

    if (transcript.trim().isEmpty) {
      _setError("I didn't hear anything. Please try again.");
      await _tts.speak("I didn't hear anything. Please try again.");
      return;
    }

    _setState(PipelineState.transcribing);

    final userId = await _getDeviceId();

    // ── STAGE 4: Send to backend ───────────────────────────────────
    IntentResponse? intent;
    try {
      intent = await _api.parseIntent(transcript, userId);
    } catch (e) {
      debugPrint('[Pipeline] API call threw: $e');
    }

    // Initialize our intent processor
    IntentResponse processedIntent;
    if (intent != null) {
      processedIntent = intent;
    } else {
      // Create a default placeholder if the API failed, allowing offline fallback to run
      processedIntent = const IntentResponse(intent: 'unknown', confidence: 0.0);
    }

    // ── LOCAL SAFETY NET ──
    // If the backend parsed a contact command successfully but didn't return a phone number
    final localContacts = _storage.contactsBox.values.toList();
    if (intent != null &&
        (intent.intent == 'call_contact' || intent.intent == 'send_whatsapp') &&
        (intent.phone == null || intent.phone!.isEmpty)) {
      
      final contactName = intent.contact ?? '';
      if (contactName.isNotEmpty) {
        final matches = FuzzyMatcher.searchContacts(contactName, localContacts);
        if (matches.isNotEmpty) {
          processedIntent = intent.copyWith(
            phone: matches.first.phone,
            contact: matches.first.name, // preserves original name with emojis
          );
          debugPrint('[Pipeline] Local safety net matched: ${processedIntent.contact} (${processedIntent.phone})');
        }
      }
    }

    // ── LOCAL HEURISTIC PARSER / OFFLINE FALLBACK ──
    // If the API failed or didn't understand the command, perform a local rule-based match
    if (!processedIntent.isValid) {
      final lowerText = transcript.toLowerCase();
      String? matchedName;
      String? matchedPhone;
      String? intentType;
      String? actionTitle;
      String? actionDetail;
      String? messageText;

      // 1. Call Intent
      if (lowerText.startsWith('call ') || lowerText.contains(' call ')) {
        intentType = 'call_contact';
        final parts = lowerText.split('call ');
        if (parts.length > 1) {
          final candidate = parts.last.trim();
          final matches = FuzzyMatcher.searchContacts(candidate, localContacts);
          if (matches.isNotEmpty) {
            matchedName = matches.first.name;
            matchedPhone = matches.first.phone;
            actionTitle = 'Call Contact';
            actionDetail = 'Call $matchedName';
          }
        }
      }
      // 2. WhatsApp/Message Intent
      else if (lowerText.startsWith('whatsapp ') || lowerText.contains('whatsapp ') ||
               lowerText.startsWith('message ') || lowerText.contains('message ')) {
        intentType = 'send_whatsapp';
        
        String candidate = '';
        if (lowerText.contains('whatsapp ')) {
          candidate = lowerText.split('whatsapp ').last.trim();
        } else if (lowerText.contains('message ')) {
          candidate = lowerText.split('message ').last.trim();
        }

        // Split out the optional message component
        if (candidate.contains(' saying ')) {
          candidate = candidate.split(' saying ').first.trim();
        } else if (candidate.contains(' that ')) {
          candidate = candidate.split(' that ').first.trim();
        }

        if (candidate.isNotEmpty) {
          final matches = FuzzyMatcher.searchContacts(candidate, localContacts);
          if (matches.isNotEmpty) {
            matchedName = matches.first.name;
            matchedPhone = matches.first.phone;

            if (lowerText.contains(' saying ')) {
              messageText = transcript.substring(lowerText.indexOf(' saying ') + 8).trim();
            } else if (lowerText.contains(' that ')) {
              messageText = transcript.substring(lowerText.indexOf(' that ') + 6).trim();
            }

            actionTitle = 'Send WhatsApp';
            actionDetail = 'Message $matchedName: "$messageText"';
          }
        }
      }

      // If local parsing successfully matched a synced contact
      if (intentType != null && matchedName != null && matchedPhone != null) {
        processedIntent = IntentResponse(
          intent: intentType,
          confidence: 0.95,
          contact: matchedName,
          phone: matchedPhone,
          message: messageText,
        );
        debugPrint('[Pipeline] Local parsing fallback matched: $matchedName ($matchedPhone)');
      }
    }

    // If still invalid, check if it was a connection timeout/failure
    if (!processedIntent.isValid && intent == null) {
      _setError("Couldn't reach the assistant. Check your WiFi.");
      await _tts.speak(
        "I couldn't connect to the assistant. "
        "Please check that your laptop is on and connected to the same WiFi.",
      );
      _voice.markProcessingDone();
      return;
    }

    // Handle low-confidence / unknown intents
    if (!processedIntent.isValid) {
      _setError("I didn't understand that.");
      await _tts.speak(
        "Sorry, I didn't understand that. "
        "Could you say it a different way?",
      );
      _voice.markProcessingDone();
      _setState(PipelineState.idle);
      return;
    }

    debugPrint('[Pipeline] STAGE 4 — intent: ${processedIntent.intent}, confidence=${processedIntent.confidence}');

    // ── STAGE 5 (pre): show confirmation ─────────────────────────
    _pendingIntent = processedIntent;
    _setState(PipelineState.confirming);

    // Speak the confirmation so user knows what will happen
    await _tts.speak(
      '${processedIntent.actionTitle}. ${processedIntent.actionDetail}. Say yes or tap confirm.',
    );

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // STAGE 5: User taps "Yes, do it" → execute action
  // ─────────────────────────────────────────────────────────────────
  Future<void> confirmAndExecute() async {
    if (_pendingIntent == null) return;

    _setState(PipelineState.executing);
    final intent = _pendingIntent!;
    final userId = await _getDeviceId();

    ActionResult result;
    try {
      result = await ActionExecutor.execute(intent);
    } catch (e) {
      result = ActionResult(
        success: false,
        spokenFeedback: 'Something went wrong. Please try again.',
      );
      debugPrint('[Pipeline] execute threw: $e');
    }

    // Log to backend (fire and forget)
    _api.logAction(
      userId: userId,
      intent: intent.intent,
      rawText: _lastTranscript,
      success: result.success,
    );

    // Speak outcome to user
    await _tts.speak(result.spokenFeedback);

    _voice.markProcessingDone();
    _setState(PipelineState.done);
  }

  // ─────────────────────────────────────────────────────────────────
  // User taps Cancel on confirmation sheet
  // ─────────────────────────────────────────────────────────────────
  Future<void> cancelConfirmation() async {
    _pendingIntent = null;
    _voice.markProcessingDone();
    await _tts.speak('Cancelled.');
    _setState(PipelineState.idle);
  }

  // ─────────────────────────────────────────────────────────────────
  // User taps X to dismiss the listening overlay manually
  // ─────────────────────────────────────────────────────────────────
  Future<void> stopListening() async {
    _partialSub?.cancel();
    await _voice.stopListening();
    _liveText = '';
    _setState(PipelineState.idle);
  }

  // Reset to idle (e.g. after done state, ready for next command)
  void reset() {
    _partialSub?.cancel();
    _pendingIntent = null;
    _errorMessage = null;
    _liveText = '';
    _lastTranscript = '';
    _voice.markProcessingDone();
    _setState(PipelineState.idle);
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────
  void _setState(PipelineState s) {
    _state = s;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _setState(PipelineState.error);
    _voice.markProcessingDone();
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      id = 'device_${DateTime.now().millisecondsSinceEpoch}';
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
