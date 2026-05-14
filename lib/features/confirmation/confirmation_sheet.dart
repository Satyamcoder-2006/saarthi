import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/intent_response.dart';
import '../../core/utils/action_executor.dart';
import '../../core/services/tts_service.dart';

void showConfirmation(BuildContext context, IntentResponse intent) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ConfirmationSheet(intent: intent),
  );
}

class ConfirmationSheet extends StatelessWidget {
  final IntentResponse intent;
  
  const ConfirmationSheet({Key? key, required this.intent}) : super(key: key);

  IconData _getIcon() {
    switch (intent.intent) {
      case 'call_contact': return Icons.phone;
      case 'send_whatsapp': return Icons.chat_bubble;
      case 'send_sms': return Icons.message;
      case 'navigate_to': return Icons.pin_drop;
      case 'open_app': return Icons.grid_view;
      case 'set_reminder': return Icons.notifications;
      case 'emergency_call': return Icons.emergency;
      default: return Icons.help_outline;
    }
  }
  
  Color _getColor() {
    switch (intent.intent) {
      case 'send_whatsapp': return AppColors.whatsappGreen;
      case 'navigate_to': return AppColors.accent;
      case 'open_app': return Colors.purple;
      case 'emergency_call': return AppColors.emergencyRed;
      default: return AppColors.primary;
    }
  }

  String _getTitle() {
    switch (intent.intent) {
      case 'call_contact': return 'Call ${intent.contact}?';
      case 'send_whatsapp': return 'WhatsApp ${intent.contact}?';
      case 'send_sms': return 'Message ${intent.contact}?';
      case 'navigate_to': return 'Navigate to ${intent.destination}?';
      case 'open_app': return 'Open ${intent.appName}?';
      case 'set_reminder': return 'Set Reminder?';
      case 'emergency_call': return 'Emergency Call?';
      default: return 'Confirm Action?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Icon(_getIcon(), color: _getColor(), size: 48),
          const SizedBox(height: 16),
          Text(_getTitle(), style: AppTextStyles.headingBold, textAlign: TextAlign.center),
          if (intent.message != null) ...[
            const SizedBox(height: 12),
            Text('"${intent.message}"', style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 72,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                final tts = context.read<TtsService>();
                ActionExecutor.execute(intent, tts);
                Navigator.of(context).pop();
              },
              child: Text('Yes, do it', style: AppTextStyles.buttonLabel),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 72,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: AppTextStyles.buttonLabel.copyWith(color: AppColors.error)),
            ),
          ),
          const SizedBox(height: 16), // Bottom padding
        ],
      ),
    );
  }
}
