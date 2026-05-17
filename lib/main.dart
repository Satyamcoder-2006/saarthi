import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

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

  // Local storage
  await Hive.initFlutter();

  // Services — created here, shared via Provider
  final storageService = StorageService();
  await storageService.initialize();

  final tts = TtsService();
  await tts.initialize();

  final api = ApiService();
  await api.initialize(); // reads IP from SharedPreferences

  // VoiceService: don't call initialize() here.
  // It will be called on first tap of the mic button.
  // This avoids showing a permission dialog on launch.
  final voice = VoiceService();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider<VoiceService>.value(value: voice),
        Provider<ApiService>.value(value: api),
        Provider<TtsService>.value(value: tts),
        // ListeningProvider wires everything together
        ChangeNotifierProvider<ListeningProvider>(
          create: (_) => ListeningProvider(
            voiceService: voice,
            apiService: api,
            ttsService: tts,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(
            storageService: storageService,
            ttsService: tts,
          ),
        ),
        ChangeNotifierProvider<HomeProvider>(
          create: (_) => HomeProvider(
            apiService: api,
            voiceService: voice,
            ttsService: tts,
          ),
        ),
        ChangeNotifierProvider<ContactsProvider>(
          create: (_) => ContactsProvider(
            apiService: api,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider<RemindersProvider>(
          create: (_) => RemindersProvider(
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider<HistoryProvider>(
          create: (_) => HistoryProvider(
            apiService: api,
            storageService: storageService,
          ),
        ),
      ],
      child: const SaarthiApp(),
    ),
  );
}
