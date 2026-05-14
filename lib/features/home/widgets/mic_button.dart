import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../home_provider.dart';
import '../../listening/listening_overlay.dart';

class MicButton extends StatefulWidget {
  const MicButton({Key? key}) : super(key: key);

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = context.select<HomeProvider, bool>((p) => p.isListening);

    if (isListening && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!isListening && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }

    return GestureDetector(
      onTap: () {
        if (!isListening) {
          context.read<HomeProvider>().startListening();
          showGeneralDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black.withOpacity(0.94),
            pageBuilder: (context, anim1, anim2) => const ListeningOverlay(),
          );
        }
      },
      child: isListening 
        ? AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 160 + (_animation.value * 60),
                    height: 160 + (_animation.value * 60),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.listeningPulse.withOpacity(0.1),
                    ),
                  ),
                  Container(
                    width: 160 + (_animation.value * 30),
                    height: 160 + (_animation.value * 30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.listeningPulse.withOpacity(0.2),
                    ),
                  ),
                  Container(
                    width: 160,
                    height: 160,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 64),
                  ),
                ],
              );
            },
          )
        : Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 64),
          ),
    );
  }
}
