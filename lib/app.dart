import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'features/settings/settings_provider.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/onboarding/setup_screen.dart';
import 'features/home/home_screen.dart';
import 'features/contacts/contacts_screen.dart';
import 'features/contacts/add_contact_screen.dart';
import 'features/reminders/reminders_screen.dart';
import 'features/history/history_screen.dart';
import 'features/settings/settings_screen.dart';
import 'shared/widgets/saarthi_bottom_nav.dart';

class SaarthiApp extends StatelessWidget {
  const SaarthiApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/setup',
          builder: (_, __) => const SetupScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            return MainShell(child: child);
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const HomeScreen(),
            ),
            GoRoute(
              path: '/contacts',
              builder: (_, __) => const ContactsScreen(),
            ),
            GoRoute(
              path: '/contacts/add',
              builder: (_, __) => const AddContactScreen(),
            ),
            GoRoute(
              path: '/reminders',
              builder: (_, __) => const RemindersScreen(),
            ),
            GoRoute(
              path: '/history',
              builder: (_, __) => const HistoryScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Saarthi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: settingsProvider.highContrast ? Colors.white : AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final scale = settingsProvider.textScale;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      routerConfig: router,
    );
  }
}

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const SaarthiBottomNav(),
    );
  }
}
