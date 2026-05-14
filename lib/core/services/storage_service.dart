import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/contact.dart';
import '../models/reminder.dart';
import '../models/action_log.dart';

class StorageService {
  late SharedPreferences _prefs;
  
  late Box<Contact> contactsBox;
  late Box<Reminder> remindersBox;
  late Box<ActionLog> actionLogBox;
  late Box<dynamic> settingsBox;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Hive is already initialized in main.dart
    contactsBox = await Hive.openBox<Contact>('contacts_box');
    remindersBox = await Hive.openBox<Reminder>('reminders_box');
    actionLogBox = await Hive.openBox<ActionLog>('action_log_box');
    settingsBox = await Hive.openBox<dynamic>('settings_box');
  }

  // SharedPreferences Helpers
  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) => _prefs.setString(key, value);
  
  bool getBool(String key, {bool defaultValue = false}) => _prefs.getBool(key) ?? defaultValue;
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);
  
  double getDouble(String key, {double defaultValue = 0.0}) => _prefs.getDouble(key) ?? defaultValue;
  Future<bool> setDouble(String key, double value) => _prefs.setDouble(key, value);

  // Settings helpers
  dynamic getSetting(String key, {dynamic defaultValue}) => settingsBox.get(key, defaultValue: defaultValue);
  Future<void> putSetting(String key, dynamic value) => settingsBox.put(key, value);
}
