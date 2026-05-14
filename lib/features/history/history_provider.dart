import 'package:flutter/material.dart';
import '../../core/models/action_log.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';

class HistoryProvider extends ChangeNotifier {
  final ApiService apiService;
  final StorageService storageService;

  List<ActionLog> logs = [];

  HistoryProvider({required this.apiService, required this.storageService});

  Future<void> loadHistory() async {
    // 1. Local
    logs = storageService.actionLogBox.values.toList();
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();

    // 2. Remote
    if (apiService.isInitialized) {
      try {
        final serverLogs = await apiService.getHistory();
        if (serverLogs.isNotEmpty) {
          logs = serverLogs;
          logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          await storageService.actionLogBox.clear();
          await storageService.actionLogBox.addAll(serverLogs);
          notifyListeners();
        }
      } catch (e) {
        print("Error fetching history: $e");
      }
    }
  }
}
