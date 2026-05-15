import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/utils/permission_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Request all permissions on very first launch
    await PermissionHelper.requestAllPermissions();

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final storage = context.read<StorageService>();
    final api = context.read<ApiService>();

    // Initialize Voice Service model in background
    context.read<VoiceService>().initialize();

    final isConfigured = storage.getBool(AppConstants.prefsBackendConfigured);

    if (isConfigured) {
      final ip = storage.getString(AppConstants.prefsBackendIp) ?? '';
      final port = storage.getString(AppConstants.prefsBackendPort) ?? AppConstants.defaultPort;
      await api.initialize();
      context.go('/home');
    } else {
      context.go('/setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.white,
                size: 64,
              ),
            ),
            const SizedBox(height: 32),
            Text('Saarthi', style: AppTextStyles.displayLg),
            const SizedBox(height: 8),
            Text('Your voice. Your helper.', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 4),
            Text('आपकी आवाज़, आपका साथी', style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
