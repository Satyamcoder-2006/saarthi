import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/models/contact.dart';
import 'core/models/reminder.dart';
import 'core/models/action_log.dart';
import 'core/services/api_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/tts_service.dart';
import 'core/services/voice_service.dart';
import 'features/contacts/contacts_provider.dart';
import 'features/history/history_provider.dart';
import 'features/home/home_provider.dart';
import 'features/reminders/reminders_provider.dart';
import 'features/settings/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  Hive.registerAdapter(ContactAdapter());
  Hive.registerAdapter(ReminderAdapter());
  Hive.registerAdapter(ActionLogAdapter());

  final storageService = StorageService();
  await storageService.initialize();

  final ttsService = TtsService();
  await ttsService.initialize();

  final voiceService = VoiceService();
  // voiceService.initialize() is called when needed or on splash

  final apiService = ApiService();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<TtsService>.value(value: ttsService),
        Provider<VoiceService>.value(value: voiceService),
        Provider<ApiService>.value(value: apiService),
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
          )..loadContacts(),
        ),
        ChangeNotifierProvider(
          create: (_) => RemindersProvider(
            storageService: storageService,
          )..loadReminders(),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryProvider(
            apiService: apiService,
            storageService: storageService,
          )..loadHistory(),
        ),
      ],
      child: const SaarthiApp(),
    ),
  );
}
