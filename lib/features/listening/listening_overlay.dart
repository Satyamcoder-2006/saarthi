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

class _ListeningOverlayState extends State<ListeningOverlay>
    with SingleTickerProviderStateMixin {
  String _partialText = '';
  String _rawTranscript = '';
  StreamSubscription? _partialSub;
  StreamSubscription? _finalSub;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for mic icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final voiceService = context.read<VoiceService>();

    _partialSub = voiceService.partialResults.listen((text) {
      if (mounted) {
        setState(() {
          _partialText = text;
          _rawTranscript = text; // track latest partial as candidate
        });
      }
    });

    _finalSub = voiceService.finalResults.listen((text) async {
      if (!mounted) return;

      final homeProvider = context.read<HomeProvider>();
      final apiService = context.read<ApiService>();

      homeProvider.stopListening();

      // Fix: Check if we can pop before popping to avoid "popped last page" crash
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      final transcript = text.trim().isNotEmpty ? text.trim() : _rawTranscript.trim();
      if (transcript.isEmpty) return;

      try {
        final intent = await apiService.parseIntent(transcript, apiService.userId);
        if (!mounted) return;

        if (intent.confidence < 0.65) {
          homeProvider.ttsService.speak(
            "Sorry, I didn't understand that. Please try saying it differently.",
          );
        } else {
          showConfirmation(context, intent, rawText: transcript);
        }
      } catch (e) {
        homeProvider.ttsService.speak("I couldn't reach the server. Please check your connection.");
      }
    });
  }

  @override
  void dispose() {
    _partialSub?.cancel();
    _finalSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      body: Stack(
        children: [
          // Close button
          Positioned(
            top: 52,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
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
                // Animated mic
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [
                        AppColors.primary.withValues(alpha: 0.9),
                        AppColors.primary.withValues(alpha: 0.4),
                      ]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mic_rounded, color: Colors.white, size: 64),
                  ),
                ),

                const SizedBox(height: 48),

                // Transcript text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _partialText.isEmpty ? 'Listening...' : _partialText,
                    style: TextStyle(
                      fontSize: _partialText.isEmpty ? 22 : 20,
                      color: _partialText.isEmpty
                          ? Colors.white54
                          : Colors.white,
                      fontStyle: _partialText.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 32),

                // Hint
                Text(
                  'Say something like "Call Ravi" or "Go to hospital"',
                  style: TextStyle(fontSize: 13, color: Colors.white38),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
