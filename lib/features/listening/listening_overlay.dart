import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import 'listening_provider.dart';
import '../confirmation/confirmation_sheet.dart';

class ListeningOverlay extends StatefulWidget {
  const ListeningOverlay({super.key});

  @override
  State<ListeningOverlay> createState() => _ListeningOverlayState();
}

class _ListeningOverlayState extends State<ListeningOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late List<Animation<double>> _pulseAnimations;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // 3 rings, staggered
    _pulseAnimations = List.generate(3, (i) {
      return Tween<double>(begin: 0.85, end: 1.3).animate(
        CurvedAnimation(
          parent: _pulseController,
          curve: Interval(i * 0.2, 0.8 + i * 0.1, curve: Curves.easeOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ListeningProvider>(
      builder: (context, provider, _) {
        // When confirming, show confirmation sheet instead of listening UI
        if (provider.pipelineState == PipelineState.confirming &&
            provider.pendingIntent != null) {
          // Show bottom sheet after frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const ConfirmationSheet(),
                ),
              ).then((_) {
                // If sheet dismissed without action, cancel
                if (provider.pipelineState == PipelineState.confirming) {
                  provider.cancelConfirmation();
                }
              });
            }
          });
        }

        return Container(
          color: const Color(0xF01C1C1E), // 94% black
          child: SafeArea(
            child: Column(
              children: [
                // ── Top bar: close button ────────────────────────
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onTap: () {
                        provider.stopListening();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ── Waveform bars ─────────────────────────────────
                _WaveformBars(
                  isListening: provider.pipelineState == PipelineState.listening,
                ),

                const SizedBox(height: 32),

                // ── Live transcript text ───────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    provider.livePartialText.isNotEmpty
                        ? '"${provider.livePartialText}"'
                        : provider.pipelineState == PipelineState.transcribing
                            ? 'Processing...'
                            : provider.pipelineState == PipelineState.error
                                ? (provider.errorMessage ?? 'Error')
                                : '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontFamily: 'NotoSans',
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Status label ─────────────────────────────────
                _StatusLabel(state: provider.pipelineState),

                const Spacer(flex: 2),

                // ── Pulsing mic button ────────────────────────────
                _PulsingMicButton(
                  animations: _pulseAnimations,
                  isListening: provider.pipelineState == PipelineState.listening,
                ),

                const Spacer(),

                // ── Cancel hint ───────────────────────────────────
                Text(
                  'Tap × to cancel',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Waveform bars ────────────────────────────────────────────────
class _WaveformBars extends StatefulWidget {
  final bool isListening;
  const _WaveformBars({required this.isListening});

  @override
  State<_WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<_WaveformBars>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(5, (i) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 80),
        lowerBound: 0.2,
        upperBound: 1.0,
      );
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (_, __) {
            final height = widget.isListening
                ? 24.0 + _controllers[i].value * 48
                : 16.0;
            return Container(
              width: 6,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          },
        );
      }),
    );
  }
}

// ─── Status label ─────────────────────────────────────────────────
class _StatusLabel extends StatelessWidget {
  final PipelineState state;
  const _StatusLabel({required this.state});

  @override
  Widget build(BuildContext context) {
    String label;
    switch (state) {
      case PipelineState.listening:
        label = 'Listening...';
        break;
      case PipelineState.transcribing:
        label = 'Processing...';
        break;
      case PipelineState.executing:
        label = 'Doing it...';
        break;
      case PipelineState.error:
        label = 'Try again';
        break;
      default:
        label = '';
    }
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 16,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─── Pulsing mic button ───────────────────────────────────────────
class _PulsingMicButton extends StatelessWidget {
  final List<Animation<double>> animations;
  final bool isListening;

  const _PulsingMicButton({
    required this.animations,
    required this.isListening,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse rings
          if (isListening) ...[
            for (int i = 2; i >= 0; i--)
              AnimatedBuilder(
                animation: animations[i],
                builder: (_, __) => Transform.scale(
                  scale: animations[i].value,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(
                        0.08 * (3 - i).toDouble(),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          // Core mic circle
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.mic,
              color: Colors.white,
              size: 56,
            ),
          ),
        ],
      ),
    );
  }
}
