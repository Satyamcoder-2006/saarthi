import 'dart:async';

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
  // Pulse animation for the mic rings
  late AnimationController _pulseCtrl;
  late List<Animation<double>> _pulseAnims;

  // Waveform bar animations
  late List<AnimationController> _barCtrls;

  bool _sheetShown = false;

  @override
  void initState() {
    super.initState();

    // Pulse rings
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pulseAnims = List.generate(3, (i) => Tween<double>(
      begin: 0.85,
      end: 1.35,
    ).animate(CurvedAnimation(
      parent: _pulseCtrl,
      curve: Interval(i * 0.18, 0.75 + i * 0.1, curve: Curves.easeOut),
    )));

    // Waveform bars
    _barCtrls = List.generate(5, (i) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 350 + i * 70),
        lowerBound: 0.15,
        upperBound: 1.0,
      );
      Future.delayed(Duration(milliseconds: i * 90), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    for (final c in _barCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ListeningProvider>(
      builder: (context, provider, _) {
        final state = provider.pipelineState;

        // When confirming: show bottom sheet (once only)
        if (state == PipelineState.confirming && !_sheetShown) {
          _sheetShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              isDismissible: false,
              builder: (_) => ChangeNotifierProvider.value(
                value: provider,
                child: const ConfirmationSheet(),
              ),
            ).then((_) {
              _sheetShown = false;
              // If dismissed without action, cancel
              if (provider.pipelineState == PipelineState.confirming) {
                provider.cancelConfirmation();
              }
            });
          });
        }

        // After done/error, close the overlay automatically
        if (state == PipelineState.done || state == PipelineState.error) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          });
        }

        final isActivelyListening = state == PipelineState.listening;

        return Scaffold(
          backgroundColor: const Color(0xF01C1C1E),
          body: SafeArea(
            child: Column(
              children: [
                // ── Top row: X button ────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          provider.stopListening();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // ── Animated waveform bars ────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(5, (i) {
                    return AnimatedBuilder(
                      animation: _barCtrls[i],
                      builder: (_, __) {
                        final h = isActivelyListening
                            ? 20.0 + _barCtrls[i].value * 52
                            : 14.0;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 7,
                          height: h,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                              isActivelyListening ? 0.9 : 0.3,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      },
                    );
                  }),
                ),

                const SizedBox(height: 36),

                // ── Live transcript text ──────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    key: ValueKey(provider.liveText),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _displayText(provider),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontFamily: 'NotoSans',
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Status label ──────────────────────────────────
                _StatusDots(state: state),

                const Spacer(flex: 2),

                // ── Pulsing mic button ────────────────────────────
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse rings (only when actively listening)
                      if (isActivelyListening)
                        for (int i = 2; i >= 0; i--)
                          AnimatedBuilder(
                            animation: _pulseAnims[i],
                            builder: (_, __) => Transform.scale(
                              scale: _pulseAnims[i].value,
                              child: Container(
                                width: 155,
                                height: 155,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withOpacity(
                                    0.07 * (3 - i).toDouble(),
                                  ),
                                ),
                              ),
                            ),
                          ),

                      // Core mic circle
                      Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActivelyListening
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.6),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.45),
                              blurRadius: 30,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          state == PipelineState.transcribing
                              ? Icons.hourglass_top
                              : Icons.mic,
                          color: Colors.white,
                          size: 58,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Bottom hint ───────────────────────────────────
                Text(
                  state == PipelineState.listening
                      ? 'Tap × to cancel'
                      : '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        );
      },
    );
  }

  String _displayText(ListeningProvider p) {
    switch (p.pipelineState) {
      case PipelineState.listening:
        return p.liveText.isNotEmpty ? '"${p.liveText}"' : '';
      case PipelineState.transcribing:
        return 'Processing "${p.lastTranscript}"...';
      case PipelineState.confirming:
        return '"${p.lastTranscript}"';
      case PipelineState.error:
        return p.errorMessage ?? 'Something went wrong.';
      default:
        return p.lastTranscript.isNotEmpty ? '"${p.lastTranscript}"' : '';
    }
  }
}

// Animated "Listening..." dots
class _StatusDots extends StatefulWidget {
  final PipelineState state;
  const _StatusDots({required this.state});

  @override
  State<_StatusDots> createState() => _StatusDotsState();
}

class _StatusDotsState extends State<_StatusDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _dotCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount + 1) % 4);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String label;
    switch (widget.state) {
      case PipelineState.listening:
        label = 'Listening${'.' * _dotCount}';
        break;
      case PipelineState.transcribing:
        label = 'Processing${'.' * _dotCount}';
        break;
      case PipelineState.executing:
        label = 'Doing it${'.' * _dotCount}';
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
        color: Colors.white.withOpacity(0.55),
        fontSize: 16,
        letterSpacing: 1.1,
        fontFamily: 'NotoSans',
      ),
    );
  }
}
