import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/voice_service.dart';
import '../../core/services/api_service.dart';
import '../home/home_provider.dart';
import '../confirmation/confirmation_sheet.dart';

class ListeningOverlay extends StatefulWidget {
  const ListeningOverlay({Key? key}) : super(key: key);

  @override
  State<ListeningOverlay> createState() => _ListeningOverlayState();
}

class _ListeningOverlayState extends State<ListeningOverlay> {
  String _partialText = "";
  StreamSubscription? _partialSub;
  StreamSubscription? _finalSub;

  @override
  void initState() {
    super.initState();
    final voiceService = context.read<VoiceService>();
    
    _partialSub = voiceService.partialResults.listen((text) {
      if (mounted) setState(() => _partialText = text);
    });

    _finalSub = voiceService.finalResults.listen((text) async {
      if (!mounted) return;
      
      final homeProvider = context.read<HomeProvider>();
      final apiService = context.read<ApiService>();
      
      homeProvider.stopListening();
      Navigator.of(context).pop(); // close overlay
      
      if (text.trim().isNotEmpty) {
        try {
          final intent = await apiService.parseIntent(text, 'local_device');
          if (intent.confidence < 0.7) {
            context.read<HomeProvider>().ttsService.speak("Sorry, I didn't understand that. Please try again.");
          } else {
            showConfirmation(context, intent);
          }
        } catch (e) {
          context.read<HomeProvider>().ttsService.speak("I couldn't process that. Please try again.");
        }
      }
    });
  }

  @override
  void dispose() {
    _partialSub?.cancel();
    _finalSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () {
                context.read<HomeProvider>().stopListening();
                Navigator.of(context).pop();
              },
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Real app would have AnimatedWaveform here
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 64),
                ),
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _partialText.isEmpty ? "Listening..." : _partialText,
                    style: const TextStyle(
                      fontFamily: 'Noto Sans',
                      fontSize: 22,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
