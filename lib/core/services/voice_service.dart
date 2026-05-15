import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';

enum VoiceState { idle, initializing, ready, listening, processing, error }

class VoiceService extends ChangeNotifier {
  // ── Vosk internals ──────────────────────────────────────────────
  VoskFlutterPlugin? _vosk;
  Model? _model;
  SpeechService? _speechService;

  // ── State ────────────────────────────────────────────────────────
  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;

  String _partialText = '';
  String get partialText => _partialText;

  String _finalText = '';
  String get finalText => _finalText;

  double _downloadProgress = 0;
  double get downloadProgress => _downloadProgress;

  // ── Streams ──────────────────────────────────────────────────────
  // Emit the final committed transcript when ready to send to backend
  final _finalResultController = StreamController<String>.broadcast();
  Stream<String> get onFinalTranscript => _finalResultController.stream;

  // Emit partial text for live UI update
  final _partialController = StreamController<String>.broadcast();
  Stream<String> get onPartialText => _partialController.stream;

  // ── Silence detection ────────────────────────────────────────────
  // Vosk's onResult() fires when it detects a natural speech pause.
  // We use that as our "user finished speaking" trigger.
  // Additionally we keep a safety timer: if 3 seconds pass with no
  // new partial result, we force-stop.
  Timer? _silenceTimer;
  static const _silenceTimeout = Duration(seconds: 3);
  DateTime? _lastPartialTime;

  // ── Subscriptions ────────────────────────────────────────────────
  StreamSubscription? _partialSub;
  StreamSubscription? _resultSub;

  // ─────────────────────────────────────────────────────────────────
  // INIT: Download model on first launch, then init Vosk
  // ─────────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_state != VoiceState.idle && _state != VoiceState.error) return;
    _setState(VoiceState.initializing);

    try {
      // 1. Check mic permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _setState(VoiceState.error);
        return;
      }

      // 2. Load model
      _vosk = VoskFlutterPlugin.instance();
      
      // Cleanup any previous instance if it exists (prevents INITIALIZE_FAIL)
      if (_speechService != null) {
        try {
          await _speechService!.stop();
        } catch (_) {}
        _speechService = null;
      }

      final modelPath = await _getOrDownloadModel();
      if (modelPath == null) {
        _setState(VoiceState.error);
        return;
      }

      // 3. Create model and recognizer
      _model = await _vosk!.createModel(modelPath);
      final recognizer = await _vosk!.createRecognizer(
        model: _model!,
        sampleRate: 16000,
      );

      // 4. Init speech service (manages mic input automatically on Android)
      final speechService = await _vosk!.initSpeechService(recognizer);
      if (speechService == null) {
        debugPrint('[VoiceService] failed to initialize SpeechService');
        _setState(VoiceState.error);
        return;
      }
      _speechService = speechService;

      _setState(VoiceState.ready);
    } catch (e) {
      debugPrint('[VoiceService] init error: $e');
      _setState(VoiceState.error);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // START LISTENING
  // ─────────────────────────────────────────────────────────────────
  Future<void> startListening() async {
    if (_speechService == null || _state != VoiceState.ready) {
      debugPrint('[VoiceService] not ready, state=$_state');
      return;
    }

    // Reset state
    _partialText = '';
    _finalText = '';
    _lastPartialTime = DateTime.now();
    notifyListeners();

    // ── Subscribe to partial results ─────────────────────────────
    // onPartial() fires frequently as words are recognized.
    // We use it to update the live transcript on screen.
    _partialSub = _speechService!.onPartial().listen((json) {
      try {
        final data = jsonDecode(json);
        final partial = (data['partial'] as String? ?? '').trim();

        // Vosk uses 'nun' as a filler for empty — ignore it
        if (partial.isEmpty || partial == 'nun') return;

        _partialText = partial;
        _lastPartialTime = DateTime.now();
        _partialController.add(partial);
        notifyListeners();

        // Reset silence timer on each new word
        _resetSilenceTimer();
      } catch (_) {}
    });

    // ── Subscribe to result (fires on natural speech pause) ───────
    // This is Vosk's built-in silence detection.
    // When Vosk detects a pause in speech, onResult() fires with the
    // best transcription so far. This is our PRIMARY trigger to stop.
    _resultSub = _speechService!.onResult().listen((json) {
      try {
        final data = jsonDecode(json);
        // Result JSON has key 'text' on Android
        final text = (data['text'] as String? ?? '').trim();

        if (text.isNotEmpty) {
          debugPrint('[VoiceService] onResult fired: "$text"');
          _finalText = text;
          // Stop listening and emit the final result
          _commitFinalResult(text);
        }
      } catch (_) {}
    });

    // ── Start the Vosk service (opens mic + begins feeding audio) ──
    await _speechService!.start();
    _setState(VoiceState.listening);

    // Start silence safety timer
    _resetSilenceTimer();
  }

  // ─────────────────────────────────────────────────────────────────
  // SILENCE TIMER — safety fallback if onResult() doesn't fire
  // ─────────────────────────────────────────────────────────────────
  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceTimeout, () {
      if (_state == VoiceState.listening) {
        final text = _partialText.trim();
        debugPrint('[VoiceService] silence timer fired, partial="$text"');
        if (text.isNotEmpty) {
          _commitFinalResult(text);
        } else {
          // Nothing was said — just stop quietly
          stopListening();
        }
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────
  // COMMIT FINAL RESULT — stop mic, emit transcript
  // ─────────────────────────────────────────────────────────────────
  void _commitFinalResult(String text) {
    if (_state != VoiceState.listening) return;
    _setState(VoiceState.processing);
    _silenceTimer?.cancel();

    // Stop the Vosk service (releases mic)
    _speechService?.stop();
    _cancelSubscriptions();

    // Emit the final transcript to anyone listening
    _finalResultController.add(text);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // STOP LISTENING (manual cancel by user)
  // ─────────────────────────────────────────────────────────────────
  Future<void> stopListening() async {
    _silenceTimer?.cancel();
    _cancelSubscriptions();
    await _speechService?.stop();
    _partialText = '';
    _setState(VoiceState.ready);
  }

  // Reset state to ready after processing is done
  void markProcessingDone() {
    if (_state == VoiceState.processing) {
      _setState(VoiceState.ready);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // MODEL LOADER
  // ─────────────────────────────────────────────────────────────────
  Future<String?> _getOrDownloadModel() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/vosk-model-small-en-in-0.4');

    if (modelDir.existsSync()) {
      // Robust check: Ensure essential files exist (Vosk models must have 'am' and 'conf' folders)
      final amDir = Directory('${modelDir.path}/am');
      if (amDir.existsSync()) {
        debugPrint('[VoiceService] model exists and appears valid');
        await _optimizeModelConfig(modelDir.path);
        return modelDir.path;
      } else {
        debugPrint('[VoiceService] model directory exists but is incomplete. Deleting...');
        modelDir.deleteSync(recursive: true);
      }
    }

    // Download the model
    debugPrint('[VoiceService] downloading model...');
    try {
      final zipPath = await ModelLoader().loadFromNetwork(
        'https://alphacephei.com/vosk/models/vosk-model-small-en-in-0.4.zip',
      );
      // ModelLoader extracts and returns the path to the model directory
      final path = zipPath;
      if (path != null) {
        await _optimizeModelConfig(path);
      }
      return path;
    } catch (e) {
      debugPrint('[VoiceService] download failed: $e');
      return null;
    }
  }

  Future<void> _optimizeModelConfig(String modelPath) async {
    try {
      final confFile = File('$modelPath/conf/model.conf');
      if (confFile.existsSync()) {
        String content = await confFile.readAsString();
        
        // Check if we've already optimized it
        if (content.contains('--endpoint.rule2.min-trailing-silence=2.0')) return;

        // Append custom endpointing rules to make it wait longer (more "loose")
        final optimizations = """
# Optimized for elderly users (longer pauses allowed)
--endpoint.rule2.min-trailing-silence=2.0
--endpoint.rule3.min-trailing-silence=3.0
--endpoint.rule4.min-trailing-silence=4.0
""";
        await confFile.writeAsString('$content\n$optimizations');
        debugPrint('[VoiceService] Optimized model.conf for longer pauses');
      }
    } catch (e) {
      debugPrint('[VoiceService] Failed to optimize config: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────
  void _setState(VoiceState s) {
    _state = s;
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _partialSub?.cancel();
    _partialSub = null;
    _resultSub?.cancel();
    _resultSub = null;
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _cancelSubscriptions();
    _finalResultController.close();
    _partialController.close();
    _speechService?.stop();
    super.dispose();
  }
}
