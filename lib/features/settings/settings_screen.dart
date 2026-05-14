import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Settings', style: AppTextStyles.screenTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Appearance'),
          _buildCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('High Contrast', style: AppTextStyles.bodyLargeBold),
                  subtitle: Text('Make text easier to read', style: AppTextStyles.bodyMedium),
                  value: provider.highContrast,
                  activeColor: AppColors.primary,
                  onChanged: (val) => context.read<SettingsProvider>().setHighContrast(val),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text('Text Size', style: AppTextStyles.bodyLargeBold),
                  trailing: DropdownButton<double>(
                    value: provider.textScale,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 1.0, child: Text('Normal')),
                      DropdownMenuItem(value: 1.2, child: Text('Large')),
                      DropdownMenuItem(value: 1.4, child: Text('Extra Large')),
                    ],
                    onChanged: (val) {
                      if (val != null) context.read<SettingsProvider>().setTextScale(val);
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader('Voice & Language'),
          _buildCard(
            child: Column(
              children: [
                ListTile(
                  title: Text('Language', style: AppTextStyles.bodyLargeBold),
                  trailing: DropdownButton<String>(
                    value: provider.language,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'en-IN', child: Text('English (India)')),
                      DropdownMenuItem(value: 'hi-IN', child: Text('Hindi')),
                      DropdownMenuItem(value: 'ta-IN', child: Text('Tamil')),
                      DropdownMenuItem(value: 'te-IN', child: Text('Telugu')),
                    ],
                    onChanged: (val) {
                      if (val != null) context.read<SettingsProvider>().setLanguage(val);
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Voice Speed', style: AppTextStyles.bodyLargeBold),
                      Slider(
                        value: provider.voiceSpeed,
                        min: 0.2,
                        max: 1.0,
                        divisions: 8,
                        activeColor: AppColors.primary,
                        onChanged: (val) => context.read<SettingsProvider>().setVoiceSpeed(val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('System'),
          _buildCard(
            child: Column(
              children: [
                ListTile(
                  title: Text('Backend Setup', style: AppTextStyles.bodyLargeBold),
                  subtitle: Text('Change connected laptop IP', style: AppTextStyles.bodyMedium),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push('/setup'),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text('App Version', style: AppTextStyles.bodyLargeBold),
                  trailing: Text('1.0.0', style: AppTextStyles.bodyMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(title, style: AppTextStyles.headingMedium),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }
}
