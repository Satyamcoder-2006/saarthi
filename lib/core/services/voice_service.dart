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
  bool _isListening = false;

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
      print("Failed to initialize Vosk: $e");
      return false;
    }
  }

  Future<String?> _getModelPath({Function(double)? onProgress}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${docsDir.path}/vosk-model-small-en-us-0.15');

    if (await modelDir.exists()) {
      return modelDir.path;
    }

    // Download model
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

      // Unzip
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
      print("Failed to download model: $e");
      return null;
    }
  }

  Future<bool> startListening() async {
    if (!_isInitialized || _recognizer == null) return false;
    
    if (await Permission.microphone.request() != PermissionStatus.granted) {
      return false;
    }

    try {
      _speechService = await _vosk.initSpeechService(_recognizer!);
      
      _speechService!.onPartial().listen((event) {
        final Map<String, dynamic> data = jsonDecode(event);
        final String text = data['partial'] ?? "";
        if (text.isNotEmpty) {
          _partialResultsController.add(text);
          _resetSilenceTimer();
        }
      });

      _speechService!.onResult().listen((event) {
        final Map<String, dynamic> data = jsonDecode(event);
        final String text = data['text'] ?? "";
        if (text.isNotEmpty) {
          _finalResultsController.add(text);
        }
      });

      await _speechService!.start();
      _isListening = true;
      _resetSilenceTimer();
      return true;
    } catch (e) {
      print("Start listening failed: $e");
      return false;
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 2), () {
      if (_isListening) {
        stopListening();
      }
    });
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _silenceTimer?.cancel();
    _isListening = false;
    
    try {
      await _speechService?.stop();
      _speechService = null;
    } catch (e) {
      print("Stop listening failed: $e");
    }
  }
}
