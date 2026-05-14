class IntentResponse {
  final String intent;
  final double confidence;
  final String? contact;
  final String? phone;
  final String? message;
  final String? destination;
  final String? appName;
  final String? query;
  final String? reminderTime;
  final String? reminderMessage;
  final bool? cacheHit;

  IntentResponse({
    required this.intent,
    required this.confidence,
    this.contact,
    this.phone,
    this.message,
    this.destination,
    this.appName,
    this.query,
    this.reminderTime,
    this.reminderMessage,
    this.cacheHit,
  });

  factory IntentResponse.fromJson(Map<String, dynamic> json) {
    return IntentResponse(
      intent: json['intent'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      contact: json['contact'],
      phone: json['phone'],
      message: json['message'],
      destination: json['destination'],
      appName: json['appName'] ?? json['app_name'],
      query: json['query'],
      reminderTime: json['reminderTime'] ?? json['reminder_time'],
      reminderMessage: json['reminderMessage'] ?? json['reminder_message'],
      cacheHit: json['cache_hit'],
    );
  }
}
