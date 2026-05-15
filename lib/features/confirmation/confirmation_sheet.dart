import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../listening/listening_provider.dart';

class ConfirmationSheet extends StatelessWidget {
  const ConfirmationSheet({super.key});

  IconData _iconForIntent(String intent) {
    switch (intent) {
      case 'call_contact': return Icons.phone;
      case 'send_whatsapp': return Icons.chat;
      case 'send_sms': return Icons.message;
      case 'navigate_to': return Icons.navigation;
      case 'open_app': return Icons.apps;
      case 'play_music': return Icons.music_note;
      case 'set_reminder': return Icons.alarm;
      case 'emergency_call': return Icons.emergency;
      default: return Icons.help_outline;
    }
  }

  Color _colorForIntent(String intent) {
    switch (intent) {
      case 'call_contact': return AppColors.primary;
      case 'send_whatsapp': return AppColors.whatsappGreen;
      case 'send_sms': return Colors.blue;
      case 'navigate_to': return Colors.orange;
      case 'play_music': return Colors.purple;
      case 'emergency_call': return AppColors.error;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListeningProvider>();
    final intent = provider.pendingIntent;
    if (intent == null) return const SizedBox.shrink();

    final color = _colorForIntent(intent.intent);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconForIntent(intent.intent), color: color, size: 36),
          ),

          const SizedBox(height: 16),

          // Action title
          Text(
            intent.actionTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C1C1E),
            ),
          ),

          const SizedBox(height: 8),

          // Action detail
          Text(
            intent.actionDetail,
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF6E6E73),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // YES button
          SizedBox(
            width: double.infinity,
            height: 72,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                provider.confirmAndExecute();
              },
              child: const Text(
                'Yes, do it',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // CANCEL button
          SizedBox(
            width: double.infinity,
            height: 72,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.error, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                provider.cancelConfirmation();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Voice hint
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.mic, size: 14, color: Color(0xFFAEAEB2)),
              SizedBox(width: 4),
              Text(
                "Say 'Yes' or 'No' to confirm",
                style: TextStyle(fontSize: 14, color: Color(0xFFAEAEB2)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
