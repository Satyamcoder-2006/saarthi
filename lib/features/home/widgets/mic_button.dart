import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../listening/listening_provider.dart';
import '../../listening/listening_overlay.dart';

class MicButton extends StatelessWidget {
  const MicButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ListeningProvider>(
      builder: (context, provider, _) {
        return GestureDetector(
          onTap: () async {
            // Stage 1: kick off the pipeline
            await provider.startListening();

            // Show the fullscreen listening overlay
            // This stays open until pipeline reaches done/error/idle
            if (context.mounted) {
              await Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  barrierDismissible: false,
                  pageBuilder: (ctx, _, __) => ChangeNotifierProvider.value(
                    value: provider,
                    child: const ListeningOverlay(),
                  ),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 250),
                ),
              );
            }

            // After overlay closes: reset pipeline to idle
            provider.reset();
          },
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 24,
                  spreadRadius: 6,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.mic,
              color: Colors.white,
              size: 66,
            ),
          ),
        );
      },
    );
  }
}
