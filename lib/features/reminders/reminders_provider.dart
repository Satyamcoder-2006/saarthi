import 'package:flutter/material.dart';
import '../../core/models/reminder.dart';
import '../../core/services/storage_service.dart';
import 'package:uuid/uuid.dart';

class RemindersProvider extends ChangeNotifier {
  final StorageService storageService;
  List<Reminder> reminders = [];

  RemindersProvider({required this.storageService});

  Future<void> loadReminders() async {
    reminders = storageService.remindersBox.values.toList();
    notifyListeners();
  }

  Future<void> addReminder(String title, DateTime time, String pattern) async {
    final reminder = Reminder(
      id: const Uuid().v4(),
      title: title,
      time: time,
      repeatPattern: pattern,
    );
    reminders.add(reminder);
    await storageService.remindersBox.add(reminder);
    _scheduleNotification(reminder);
    notifyListeners();
  }

  Future<void> toggleReminder(Reminder reminder) async {
    reminder.isActive = !reminder.isActive;
    await reminder.save();
    if (reminder.isActive) {
      _scheduleNotification(reminder);
    } else {
      _cancelNotification(reminder.id);
    }
    notifyListeners();
  }

  Future<void> deleteReminder(Reminder reminder) async {
    _cancelNotification(reminder.id);
    await reminder.delete();
    reminders.remove(reminder);
    notifyListeners();
  }

  void _scheduleNotification(Reminder reminder) {
    // Phase 1: Not fully implementing local notifications here, just structural
  }

  void _cancelNotification(String id) {
    // Phase 1: Cancel via flutter_local_notifications plugin
  }
}
