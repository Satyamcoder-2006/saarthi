import 'package:dio/dio.dart';
import '../models/intent_response.dart';
import '../models/contact.dart';
import '../models/action_log.dart';
import '../models/reminder.dart';

class ApiService {
  late Dio _dio;
  bool _isInitialized = false;
  String _userId = 'local_device';

  void initialize(String baseUrl, {String userId = 'local_device'}) {
    _userId = userId;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _isInitialized = true;
  }

  bool get isInitialized => _isInitialized;
  String get userId => _userId;

  // ── Health ──────────────────────────────────────────────────────────────────
  Future<bool> checkHealth() async {
    if (!_isInitialized) return false;
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── POST /intent ─────────────────────────────────────────────────────────────
  Future<IntentResponse> parseIntent(String transcript, String userId) async {
    if (!_isInitialized) throw Exception('API not initialized');
    final response = await _dio.post('/intent', data: {
      'text': transcript,
      'user_id': userId,
    });
    return IntentResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // ── POST /execute ─────────────────────────────────────────────────────────────
  Future<void> logExecution({
    required String intent,
    required String rawText,
    bool success = true,
  }) async {
    if (!_isInitialized) return;
    try {
      await _dio.post('/execute', data: {
        'user_id': _userId,
        'intent': intent,
        'raw_text': rawText,
        'success': success,
      });
    } catch (_) {
      // Non-critical — don't throw
    }
  }

  // ── GET /contacts ─────────────────────────────────────────────────────────────
  Future<List<Contact>> getContacts() async {
    if (!_isInitialized) return [];
    try {
      final response = await _dio.get('/contacts', queryParameters: {'user_id': _userId});
      if (response.data is List) {
        return (response.data as List)
            .map((json) => Contact.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── POST /contacts ────────────────────────────────────────────────────────────
  Future<Contact> addContact(Contact contact) async {
    if (!_isInitialized) throw Exception('API not initialized');
    final response = await _dio.post(
      '/contacts',
      queryParameters: {'user_id': _userId},
      data: contact.toJson(),
    );
    return Contact.fromJson(response.data as Map<String, dynamic>);
  }

  // ── DELETE /contacts/:id ──────────────────────────────────────────────────────
  Future<void> deleteContact(String contactId) async {
    if (!_isInitialized) return;
    try {
      await _dio.delete(
        '/contacts/$contactId',
        queryParameters: {'user_id': _userId},
      );
    } catch (_) {}
  }

  // ── POST /reminder ─────────────────────────────────────────────────────────────
  Future<void> createReminder(Reminder reminder) async {
    if (!_isInitialized) return;
    try {
      await _dio.post('/reminder', data: {
        'user_id': _userId,
        'message': reminder.title,
        'trigger_at': reminder.time.toIso8601String(),
        'repeat': reminder.repeatPattern,
      });
    } catch (_) {}
  }

  // ── GET /reminders ─────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getReminders() async {
    if (!_isInitialized) return [];
    try {
      final response = await _dio.get('/reminders', queryParameters: {'user_id': _userId});
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data as List);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── GET /history ──────────────────────────────────────────────────────────────
  Future<List<ActionLog>> getHistory({int limit = 20}) async {
    if (!_isInitialized) return [];
    try {
      final response = await _dio.get('/history',
          queryParameters: {'user_id': _userId, 'limit': limit});
      if (response.data is List) {
        return (response.data as List)
            .map((json) => ActionLog.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
