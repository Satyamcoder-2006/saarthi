import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/services/storage_service.dart';
import 'core/services/voice_service.dart';
import 'core/services/api_service.dart';
import 'core/services/tts_service.dart';
import 'features/listening/listening_provider.dart';
import 'features/settings/settings_provider.dart';
import 'features/home/home_provider.dart';
import 'features/contacts/contacts_provider.dart';
import 'features/reminders/reminders_provider.dart';
import 'features/history/history_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Create services
  final storageService = StorageService();
  await storageService.initialize();

  final ttsService = TtsService();
  await ttsService.initialize();

  final apiService = ApiService();
  await apiService.initialize();

  final voiceService = VoiceService();
  // Initialize voice service early so model is ready
  // This downloads model if first launch
  voiceService.initialize(); // non-blocking, state tracked internally

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: storageService),
        ChangeNotifierProvider.value(value: voiceService),
        Provider.value(value: apiService),
        Provider.value(value: ttsService),
        ChangeNotifierProvider(
          create: (_) => ListeningProvider(
            voiceService: voiceService,
            apiService: apiService,
            ttsService: ttsService,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(
            storageService: storageService,
            ttsService: ttsService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => HomeProvider(
            apiService: apiService,
            voiceService: voiceService,
            ttsService: ttsService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ContactsProvider(
            apiService: apiService,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RemindersProvider(
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryProvider(
            apiService: apiService,
            storageService: storageService,
          ),
        ),
      ],
      child: const SaarthiApp(),
    ),
  );
}
