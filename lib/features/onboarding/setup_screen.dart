import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/api_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: AppConstants.defaultPort);
  
  bool _isLoading = false;
  bool _isConnected = false;
  String _errorMsg = '';

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
      _isConnected = false;
    });

    final ip = _ipController.text.trim();
    final port = _portController.text.trim();

    if (ip.isEmpty) {
      setState(() {
        _errorMsg = 'Please enter an IP address';
        _isLoading = false;
      });
      return;
    }

    final baseUrl = 'http://$ip:$port';
    final api = context.read<ApiService>();
    
    // Temporarily initialize to test
    api.initialize(baseUrl);
    
    final isHealthy = await api.checkHealth();
    
    setState(() {
      _isLoading = false;
      if (isHealthy) {
        _isConnected = true;
      } else {
        _errorMsg = 'Could not connect to backend';
      }
    });
  }

  Future<void> _saveAndContinue() async {
    final storage = context.read<StorageService>();
    await storage.setString(AppConstants.prefsBackendIp, _ipController.text.trim());
    await storage.setString(AppConstants.prefsBackendPort, _portController.text.trim());
    await storage.setBool(AppConstants.prefsBackendConfigured, true);
    
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup', style: AppTextStyles.screenTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: Text(
                'Make sure your phone and laptop are on the same WiFi network.',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.brown[800]),
              ),
            ),
            const SizedBox(height: 32),
            Text('Laptop IP Address', style: AppTextStyles.bodyLargeBold),
            const SizedBox(height: 8),
            TextField(
              controller: _ipController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: 'e.g. 192.168.1.5',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              ),
            ),
            const SizedBox(height: 24),
            Text('Port', style: AppTextStyles.bodyLargeBold),
            const SizedBox(height: 8),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Test Connection', style: AppTextStyles.buttonLabel),
            ),
            if (_isConnected) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Connected! Assistant is ready.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Save & Continue', style: AppTextStyles.buttonLabel),
              ),
            ],
            if (_errorMsg.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_errorMsg, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
