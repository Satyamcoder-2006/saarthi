class IntentResponse {
  final String intent;
  final String? contact;
  final String? phone;
  final String? message;
  final String? destination;
  final String? appName;
  final String? query;
  final String? reminderTime;
  final double confidence;

  IntentResponse({
    required this.intent,
    this.contact,
    this.phone,
    this.message,
    this.destination,
    this.appName,
    this.query,
    this.reminderTime,
    required this.confidence,
  });

  factory IntentResponse.fromJson(Map<String, dynamic> json) {
    return IntentResponse(
      intent: json['intent'] ?? 'unknown',
      contact: json['contact'],
      phone: json['phone'],
      message: json['message'],
      destination: json['destination'],
      appName: json['appName'],
      query: json['query'],
      reminderTime: json['reminderTime'],
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }
}
