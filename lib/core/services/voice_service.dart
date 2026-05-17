import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

// All possible states of the voice service
enum VoiceState {
  idle,          // Not doing anything
  initializing,  // Calling speech.initialize() for the first time
  ready,         // Initialized, waiting for startListening()
  listening,     // Mic is open, words flowing in
  processing,    // Got final transcript, pipeline is working on it
  error,         // Something went wrong
}

class VoiceService extends ChangeNotifier {
  // ── Core STT engine ─────────────────────────────────────────────
  // SpeechToText wraps Android's SpeechRecognizer (Google Assistant engine)
  // Must be initialized once, then listen() called each session.
  final SpeechToText _speech = SpeechToText();

  // ── State ────────────────────────────────────────────────────────
  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;
  bool get isListening => _state == VoiceState.listening;
  bool get isReady => _state == VoiceState.ready;

  // Live partial transcript shown in the overlay UI
  String _partialText = '';
  String get partialText => _partialText;

  // Error message for UI display
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── Streams ──────────────────────────────────────────────────────
  // Downstream consumers (ListeningProvider) subscribe to these.

  // Emits live partial words as user speaks
  final _partialController = StreamController<String>.broadcast();
  Stream<String> get onPartialText => _partialController.stream;

  // Emits the committed final transcript when user stops speaking
  final _finalController = StreamController<String>.broadcast();
  Stream<String> get onFinalTranscript => _finalController.stream;

  // ── Locale ───────────────────────────────────────────────────────
  // Default Indian English. Switch to hi-IN / ta-IN in settings.
  String _localeId = 'en_IN';
  String get localeId => _localeId;

  // ─────────────────────────────────────────────────────────────────
  // INITIALIZE — call once at app startup in main.dart
  // No model download needed — Google engine is pre-installed on device.
  // ─────────────────────────────────────────────────────────────────
  Future<bool> initialize() async {
    if (_state == VoiceState.ready) return true;
    if (_state == VoiceState.initializing) return false;

    _setState(VoiceState.initializing);

    // 1. Check microphone permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _setError('Microphone permission denied. Please allow it in Settings.');
      return false;
    }

    // 2. Initialize the Google STT engine
    //    onStatus: called when the engine status changes (e.g. "listening", "done")
    //    onError:  called on recognition errors
    final available = await _speech.initialize(
      onStatus: _onStatus,
      onError: _onError,
      debugLogging: kDebugMode,
    );

    if (!available) {
      _setError(
        'Speech recognition not available on this device. '
        'Please install Google app or check device settings.',
      );
      return false;
    }

    _setState(VoiceState.ready);
    debugPrint('[VoiceService] initialized, Google STT ready');
    return true;
  }

  // ─────────────────────────────────────────────────────────────────
  // START LISTENING
  // Opens the microphone and begins feeding audio to Google STT.
  // Partial results update live. Final result fires when user pauses.
  // ─────────────────────────────────────────────────────────────────
  Future<void> startListening() async {
    if (!_speech.isAvailable) {
      debugPrint('[VoiceService] not available, initializing...');
      final ok = await initialize();
      if (!ok) return;
    }

    if (_speech.isListening) {
      debugPrint('[VoiceService] already listening, ignoring');
      return;
    }

    // Reset partial text
    _partialText = '';
    _errorMessage = null;
    notifyListeners();

    _setState(VoiceState.listening);

    await _speech.listen(
      // ── onResult: fires on EVERY update — both partial and final ──
      // result.finalResult == false → partial word stream (update UI)
      // result.finalResult == true  → user stopped speaking (commit)
      onResult: _onResult,

      // ── Locale: Indian English by default ─────────────────────────
      localeId: _localeId,

      // ── partialResults: true → get live word updates ──────────────
      // This is what makes the text appear in real-time on screen.
      // Google STT fires onResult every ~300ms with the current best guess.
      listenOptions: SpeechListenOptions(
        partialResults: true,

        // listenMode.dictation: optimized for natural speech phrases,
        // not just single words. Best for commands like
        // "Send a WhatsApp to Ravi saying I'll be late".
        listenMode: ListenMode.dictation,

        // cancelOnError: if a non-permanent error occurs, stop gracefully
        cancelOnError: false,

        // autoPunctuation: Google adds commas/periods automatically
        autoPunctuation: false,

        // onDevice: false = use cloud (best accuracy for Indian accents)
        // true = force offline (less accurate but works without internet)
        onDevice: false,
      ),

      // ── pauseFor: how long to wait after user stops speaking ───────
      // Google STT auto-stops after this duration of silence.
      // 2.5s is good for elderly users who speak slowly.
      pauseFor: const Duration(seconds: 3),

      // ── listenFor: absolute max duration of one session ────────────
      listenFor: const Duration(seconds: 30),

      // ── soundLevel: for waveform animation in the UI ──────────────
      onSoundLevelChange: (level) {
        // level is -160 to 0 (dB). Normalize to 0..1 for animation.
        // You can connect this to the waveform widget if needed.
      },
    );

    debugPrint('[VoiceService] listen() called, waiting for speech...');
  }

  // ─────────────────────────────────────────────────────────────────
  // STOP LISTENING (manual cancel by user tapping X)
  // ─────────────────────────────────────────────────────────────────
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    _partialText = '';
    _setState(VoiceState.ready);
  }

  // ─────────────────────────────────────────────────────────────────
  // MARK PROCESSING DONE — called by ListeningProvider after
  // it finishes handling the intent (action executed or cancelled)
  // ─────────────────────────────────────────────────────────────────
  void markProcessingDone() {
    if (_state == VoiceState.processing) {
      _setState(VoiceState.ready);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // UPDATE LOCALE — called from settings when user changes language
  // ─────────────────────────────────────────────────────────────────
  void setLocale(String localeId) {
    _localeId = localeId;
    debugPrint('[VoiceService] locale set to $_localeId');
  }

  // ─────────────────────────────────────────────────────────────────
  // PRIVATE: onResult callback
  //
  // This is the heart of the pipeline.
  // Google STT calls this:
  //   - Frequently with partialResults (live words as you speak)
  //   - Once with finalResult=true when you stop speaking
  // ─────────────────────────────────────────────────────────────────
  void _onResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();

    if (words.isEmpty) return;

    debugPrint(
      '[VoiceService] onResult: "$words" | final=${result.finalResult}',
    );

    if (!result.finalResult) {
      // ── Partial result: update the live text on screen ─────────
      _partialText = words;
      _partialController.add(words);
      notifyListeners();
    } else {
      // ── FINAL RESULT: user stopped speaking ──────────────────
      // This is the trigger to send data to the backend.
      _partialText = words;
      notifyListeners();

      _setState(VoiceState.processing);

      // Emit the final transcript to ListeningProvider
      _finalController.add(words);

      debugPrint('[VoiceService] FINAL TRANSCRIPT emitted: "$words"');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PRIVATE: statusListener callback
  //
  // Google STT fires these status strings:
  //   "listening"      → mic is open and active
  //   "notListening"   → mic closed (user stopped or timeout)
  //   "done"           → session fully complete
  //
  // "done" fires AFTER onResult with finalResult=true.
  // We use it as a safety net to reset state if processing got stuck.
  // ─────────────────────────────────────────────────────────────────
  void _onStatus(String status) {
    debugPrint('[VoiceService] status: $status');

    switch (status) {
      case 'listening':
        // Already set to listening in startListening() — no-op here
        break;

      case 'notListening':
        // Mic closed. If we're still in listening state (no final result
        // came through), it means silence timeout with nothing said.
        if (_state == VoiceState.listening) {
          _setState(VoiceState.ready);
          debugPrint('[VoiceService] timeout — nothing heard');
        }
        break;

      case 'done':
        // Session complete. If we're stuck in listening (edge case),
        // reset to ready. Normal flow: already in processing state here.
        if (_state == VoiceState.listening) {
          _setState(VoiceState.ready);
        }
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PRIVATE: errorListener callback
  //
  // Common errors from Google STT:
  //   error_no_match        → didn't recognize any speech
  //   error_speech_timeout  → silence timeout before any speech
  //   error_network         → no internet (for cloud mode)
  //   error_network_timeout → API timeout
  // ─────────────────────────────────────────────────────────────────
  void _onError(SpeechRecognitionError error) {
    debugPrint('[VoiceService] error: ${error.errorMsg}, permanent=${error.permanent}');

    // Non-permanent errors (like error_no_match) are normal — user just
    // didn't say anything recognizable. Reset to ready silently.
    if (!error.permanent) {
      if (_state == VoiceState.listening) {
        _setState(VoiceState.ready);
      }
      return;
    }

    // Permanent errors need user attention
    String message;
    switch (error.errorMsg) {
      case 'error_network':
      case 'error_network_timeout':
        message = 'No internet. Please connect to WiFi for best accuracy.';
        break;
      case 'error_insufficient_permissions':
        message = 'Microphone permission denied. Please allow it in Settings.';
        break;
      default:
        message = 'Voice recognition error. Please try again.';
    }
    _setError(message);
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────
  void _setState(VoiceState s) {
    _state = s;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _state = VoiceState.error;
    notifyListeners();
    debugPrint('[VoiceService] ERROR: $message');
  }

  @override
  void dispose() {
    _partialController.close();
    _finalController.close();
    _speech.stop();
    super.dispose();
  }
}
