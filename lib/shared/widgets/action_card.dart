import 'package:flutter/material.dart';
import '../../core/models/action_log.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ActionCard extends StatelessWidget {
  final ActionLog action;

  const ActionCard({Key? key, required this.action}) : super(key: key);

  IconData _getIcon() {
    switch (action.intentType) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: action.isSuccess ? AppColors.success : AppColors.error,
            width: 6,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(_getIcon(), color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.description,
                  style: AppTextStyles.bodyLargeBold,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(action.timestamp),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
