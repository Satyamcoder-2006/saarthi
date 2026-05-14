import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class EmergencyFAB extends StatelessWidget {
  const EmergencyFAB({Key? key}) : super(key: key);

  void _triggerEmergency(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Emergency Call', style: AppTextStyles.headingMedium.copyWith(color: AppColors.error)),
        content: Text('Call emergency contact and send location?', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTextStyles.bodyMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              // In a real app, we'd get the actual emergency number from StorageService
              launchUrl(Uri.parse('tel:100'));
            },
            child: const Text('Call Now', style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: AppColors.error,
      onPressed: () => _triggerEmergency(context),
      icon: const Icon(Icons.emergency, color: Colors.white, size: 28),
      label: const Text(
        'Emergency', 
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
      ),
    );
  }
}
