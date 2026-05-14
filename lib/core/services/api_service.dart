import 'package:dio/dio.dart';
import '../models/intent_response.dart';
import '../models/contact.dart';
import '../models/action_log.dart';

class ApiService {
  late Dio _dio;
  bool _isInitialized = false;

  void initialize(String baseUrl) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(LogInterceptor(responseBody: true));
    _isInitialized = true;
  }
  
  bool get isInitialized => _isInitialized;

  Future<bool> checkHealth() async {
    if (!_isInitialized) return false;
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<IntentResponse> parseIntent(String transcript, String userId) async {
    if (!_isInitialized) throw Exception("API not initialized");
    try {
      final response = await _dio.post('/intent', data: {
        "text": transcript,
        "user_id": userId,
      });
      return IntentResponse.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Contact>> getContacts() async {
    if (!_isInitialized) return [];
    try {
      final response = await _dio.get('/contacts');
      if (response.data is List) {
        return (response.data as List).map((json) => Contact.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Contact> addContact(Contact contact) async {
    if (!_isInitialized) throw Exception("API not initialized");
    try {
      final response = await _dio.post('/contacts', data: contact.toJson());
      return Contact.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ActionLog>> getHistory() async {
    if (!_isInitialized) return [];
    try {
      final response = await _dio.get('/history');
      if (response.data is List) {
        return (response.data as List).map((json) => ActionLog.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
