import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/intent_response.dart';
import '../models/contact.dart';
import '../models/action_log.dart';

class ApiService {
  late Dio _dio;
  bool _initialized = false;

  // Call this on app start and whenever IP changes in settings
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('backend_ip') ?? '192.168.1.100';
    final port = prefs.getString('backend_port') ?? '8000';
    final baseUrl = 'http://$ip:$port';

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Log all requests/responses in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[API] $obj'),
      ));
    }

    _initialized = true;
    debugPrint('[ApiService] initialized with baseUrl=$baseUrl');
  }

  // ─────────────────────────────────────────────────────────────────
  // HEALTH CHECK
  // ─────────────────────────────────────────────────────────────────
  Future<bool> checkHealth() async {
    if (!_initialized) await initialize();
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] health check failed: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PARSE INTENT — main method called after voice transcript is ready
  // Sends: { "text": "call ravi", "user_id": "device-uuid" }
  // Returns: IntentResponse with intent, contact, message, etc.
  // ─────────────────────────────────────────────────────────────────
  Future<IntentResponse?> parseIntent(String transcript, String userId) async {
    if (!_initialized) await initialize();

    try {
      debugPrint('[ApiService] POST /intent with text="$transcript"');

      final response = await _dio.post('/intent', data: {
        'text': transcript,
        'user_id': userId,
      });

      if (response.statusCode == 200) {
        final json = response.data as Map<String, dynamic>;
        final intent = IntentResponse.fromJson(json);
        debugPrint('[ApiService] intent parsed: ${intent.intent}');
        return intent;
      } else {
        debugPrint('[ApiService] bad status: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      debugPrint('[ApiService] DioException: ${e.type} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[ApiService] unexpected error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // LOG ACTION — tell backend what was executed
  // ─────────────────────────────────────────────────────────────────
  Future<void> logAction({
    required String userId,
    required String intent,
    required String rawText,
    required bool success,
  }) async {
    if (!_initialized) await initialize();
    try {
      await _dio.post('/log', data: {
        'user_id': userId,
        'intent': intent,
        'raw_text': rawText,
        'success': success,
      });
    } catch (e) {
      debugPrint('[ApiService] logAction failed (non-critical): $e');
      // Non-critical — don't crash the app if logging fails
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // MOCKS FOR OTHER PROVIDERS
  // ─────────────────────────────────────────────────────────────────
  bool get isInitialized => _initialized;

  Future<List<ActionLog>> getHistory() async {
    return [];
  }

  Future<List<Contact>> getContacts() async {
    return [];
  }

  Future<void> addContact(Contact contact) async {}

  Future<void> deleteContact(String id) async {}
}
