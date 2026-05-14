import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'home_provider.dart';
import 'widgets/mic_button.dart';
import 'widgets/connection_status_pill.dart';
import 'widgets/emergency_fab.dart';
import 'widgets/recent_actions_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().checkConnection();
      context.read<HomeProvider>().loadRecentActions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Saarthi', style: AppTextStyles.screenTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Center(child: ConnectionStatusPill()),
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: [
                      const MicButton(),
                      const SizedBox(height: 16),
                      Text('Tap and speak', style: AppTextStyles.headingMedium),
                      const SizedBox(height: 4),
                      Text(
                        "Say: 'Call Ravi' or 'WhatsApp Amma'",
                        style: AppTextStyles.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, bottom: 16.0),
                  child: Text('Recent Actions', style: AppTextStyles.headingMedium),
                ),
                const RecentActionsList(),
                const SizedBox(height: 80), // Padding for FAB
              ],
            ),
          ),
          const Positioned(
            bottom: 16,
            right: 16,
            child: EmergencyFAB(),
          ),
        ],
      ),
    );
  }
}
