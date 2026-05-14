import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../home_provider.dart';

class ConnectionStatusPill extends StatelessWidget {
  const ConnectionStatusPill({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isConnected = context.select<HomeProvider, bool>((p) => p.isConnected);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected ? AppColors.primaryLight : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Connected' : 'Offline',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isConnected ? AppColors.primary : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
