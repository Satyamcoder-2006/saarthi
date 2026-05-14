import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/intent_response.dart';
import '../../core/utils/action_executor.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/api_service.dart';

void showConfirmation(BuildContext context, IntentResponse intent, {String rawText = ''}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ConfirmationSheet(intent: intent, rawText: rawText),
  );
}

class ConfirmationSheet extends StatelessWidget {
  final IntentResponse intent;
  final String rawText;

  const ConfirmationSheet({
    Key? key,
    required this.intent,
    this.rawText = '',
  }) : super(key: key);

  IconData _getIcon() {
    switch (intent.intent) {
      case 'call_contact':    return Icons.phone_rounded;
      case 'send_whatsapp':   return Icons.chat_bubble_rounded;
      case 'send_sms':        return Icons.message_rounded;
      case 'navigate_to':     return Icons.navigation_rounded;
      case 'open_app':        return Icons.apps_rounded;
      case 'set_reminder':    return Icons.notifications_rounded;
      case 'play_music':      return Icons.music_note_rounded;
      case 'emergency_call':  return Icons.emergency_rounded;
      default:                return Icons.help_outline_rounded;
    }
  }

  Color _getColor() {
    switch (intent.intent) {
      case 'send_whatsapp':  return AppColors.whatsappGreen;
      case 'navigate_to':    return AppColors.accent;
      case 'open_app':       return Colors.purple;
      case 'play_music':     return Colors.deepOrange;
      case 'emergency_call': return AppColors.emergencyRed;
      default:               return AppColors.primary;
    }
  }

  String _getTitle() {
    switch (intent.intent) {
      case 'call_contact':   return 'Call ${intent.contact ?? 'contact'}?';
      case 'send_whatsapp':  return 'WhatsApp ${intent.contact ?? 'contact'}?';
      case 'send_sms':       return 'Message ${intent.contact ?? 'contact'}?';
      case 'navigate_to':    return 'Navigate to ${intent.destination}?';
      case 'open_app':       return 'Open ${intent.appName}?';
      case 'set_reminder':   return 'Set Reminder?';
      case 'play_music':     return 'Play "${intent.query}"?';
      case 'emergency_call': return '🚨 Emergency Call?';
      default:               return 'Confirm Action?';
    }
  }

  String _getSubtitle() {
    if (intent.phone != null) return 'Number: ${intent.phone}';
    if (intent.message != null) return '"${intent.message}"';
    if (intent.reminderMessage != null) return intent.reminderMessage!;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final subtitle = _getSubtitle();

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Icon circle
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_getIcon(), color: color, size: 40),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            _getTitle(),
            style: AppTextStyles.headingBold,
            textAlign: TextAlign.center,
          ),

          // Subtitle
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 36),

          // YES button
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () {
                final tts = context.read<TtsService>();
                final api = context.read<ApiService>();
                ActionExecutor.execute(intent, tts, api, rawText: rawText);
                Navigator.of(context).pop();
              },
              child: Text('Yes, do it', style: AppTextStyles.buttonLabel),
            ),
          ),
          const SizedBox(height: 14),

          // CANCEL button
          SizedBox(
            width: double.infinity,
            height: 64,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppTextStyles.buttonLabel.copyWith(color: Colors.grey[700]),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
