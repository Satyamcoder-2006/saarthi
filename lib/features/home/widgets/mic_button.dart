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
        final isActive = provider.pipelineState == PipelineState.listening;

        return GestureDetector(
          onTap: () async {
            // Start listening in provider first
            provider.startListening();

            // Show the fullscreen listening overlay
            await showGeneralDialog(
              context: context,
              barrierDismissible: false,
              barrierColor: Colors.transparent,
              pageBuilder: (ctx, _, __) => ChangeNotifierProvider.value(
                value: provider,
                child: const ListeningOverlay(),
              ),
            );
          },
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 4,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.mic,
              color: Colors.white,
              size: 64,
            ),
          ),
        );
      },
    );
  }
}
