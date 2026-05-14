import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceService {
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  final StreamController<String> _partialResultsController = StreamController<String>.broadcast();
  final StreamController<String> _finalResultsController = StreamController<String>.broadcast();

  Stream<String> get partialResults => _partialResultsController.stream;
  Stream<String> get finalResults => _finalResultsController.stream;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Timer? _silenceTimer;
  Timer? _safetyTimer;
  bool _isListening = false;
  String _currentTranscript = "";
  
  StreamSubscription? _partialSub;
  StreamSubscription? _resultSub;

  Future<bool> initialize({Function(double)? onProgress}) async {
    if (_isInitialized) return true;

    try {
      final modelPath = await _getModelPath(onProgress: onProgress);
      if (modelPath == null) return false;

      _model = await _vosk.createModel(modelPath);
      _recognizer = await _vosk.createRecognizer(model: _model!, sampleRate: 16000);
      _isInitialized = true;
      return true;
    } catch (e) {
      print("[VoiceService] Failed to initialize Vosk: $e");
      return false;
    }
  }

  Future<String?> _getModelPath({Function(double)? onProgress}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${docsDir.path}/vosk-model-small-en-us-0.15');

    if (await modelDir.exists()) {
      return modelDir.path;
    }

    try {
      final zipPath = '${docsDir.path}/model.zip';
      final dio = Dio();
      await dio.download(
        'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip',
        zipPath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      final bytes = File(zipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File('${docsDir.path}/$filename')
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory('${docsDir.path}/$filename').createSync(recursive: true);
        }
      }

      File(zipPath).deleteSync();
      return modelDir.path;
    } catch (e) {
      print("[VoiceService] Failed to download model: $e");
      return null;
    }
  }

  Future<bool> startListening() async {
    if (!_isInitialized || _recognizer == null) return false;
    
    if (await Permission.microphone.request() != PermissionStatus.granted) {
      print("[VoiceService] Microphone permission denied");
      return false;
    }

    if (_isListening) await stopListening();

    try {
      _speechService = await _vosk.initSpeechService(_recognizer!);
      
      _partialSub = _speechService!.onPartial().listen((event) {
        try {
          final Map<String, dynamic> data = jsonDecode(event);
          final String text = data['partial'] ?? "";
          if (text.isNotEmpty) {
            print("[VoiceService] Partial: $text");
            _currentTranscript = text;
            _partialResultsController.add(text);
            _resetSilenceTimer();
          }
        } catch (e) {
          print("[VoiceService] Partial Error: $e");
        }
      });

      _resultSub = _speechService!.onResult().listen((event) {
        try {
          final Map<String, dynamic> data = jsonDecode(event);
          final String text = data['text'] ?? "";
          print("[VoiceService] Final Result Event: $text");
          if (text.isNotEmpty) {
            _currentTranscript = text;
            _finalResultsController.add(text);
            stopListening();
          }
        } catch (e) {
          print("[VoiceService] Result Error: $e");
        }
      });

      await _speechService!.start();
      _isListening = true;
      _currentTranscript = "";
      
      _resetSilenceTimer();
      
      _safetyTimer?.cancel();
      _safetyTimer = Timer(const Duration(seconds: 8), () {
        if (_isListening) {
          print("[VoiceService] Safety timeout triggered");
          stopListening();
        }
      });

      return true;
    } catch (e) {
      print("[VoiceService] Start listening failed: $e");
      return false;
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: 1500), () {
      if (_isListening) {
        print("[VoiceService] Silence detected (1.5s)");
        stopListening();
      }
    });
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    print("[VoiceService] Stopping speech service...");
    
    _silenceTimer?.cancel();
    _safetyTimer?.cancel();
    _isListening = false;
    
    if (_currentTranscript.isNotEmpty) {
      _finalResultsController.add(_currentTranscript);
    } else {
      _finalResultsController.add("");
    }
    
    try {
      await _partialSub?.cancel();
      await _resultSub?.cancel();
      await _speechService?.stop();
      _speechService = null;
    } catch (e) {
      print("[VoiceService] Stop failed: $e");
    }
  }
}
