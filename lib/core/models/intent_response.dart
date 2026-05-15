class IntentResponse {
  final String intent;
  final String? contact;
  final String? phone;
  final String? message;
  final String? destination;
  final String? appName;
  final String? query;
  final String? reminderMessage;
  final String? reminderTime;
  final double confidence;
  final String? errorMessage;

  // All supported intents:
  // call_contact    → call someone by phone
  // send_whatsapp   → open WhatsApp with pre-filled message
  // send_sms        → send SMS
  // open_app        → open an app by name
  // play_music      → open YouTube Music with a query
  // navigate_to     → open Google Maps navigation
  // set_reminder    → create a local reminder
  // read_notifications → read out recent notifications
  // emergency_call  → call emergency contact immediately
  // unknown         → could not understand

  const IntentResponse({
    required this.intent,
    this.contact,
    this.phone,
    this.message,
    this.destination,
    this.appName,
    this.query,
    this.reminderMessage,
    this.reminderTime,
    this.confidence = 1.0,
    this.errorMessage,
  });

  factory IntentResponse.fromJson(Map<String, dynamic> json) {
    return IntentResponse(
      intent: json['intent'] as String? ?? 'unknown',
      contact: json['contact'] as String?,
      phone: json['phone'] as String?,
      message: json['message'] as String?,
      destination: json['destination'] as String?,
      appName: json['app_name'] as String?,
      query: json['query'] as String?,
      reminderMessage: json['reminder_message'] as String?,
      reminderTime: json['reminder_time'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      errorMessage: json['error'] as String?,
    );
  }

  // For confirmation screen: human-readable summary
  String get actionTitle {
    switch (intent) {
      case 'call_contact': return 'Call ${contact ?? "someone"}';
      case 'send_whatsapp': return 'Send WhatsApp';
      case 'send_sms': return 'Send SMS';
      case 'open_app': return 'Open ${appName ?? "app"}';
      case 'play_music': return 'Play Music';
      case 'navigate_to': return 'Navigate';
      case 'set_reminder': return 'Set Reminder';
      case 'emergency_call': return 'Emergency Call';
      default: return 'Unknown action';
    }
  }

  String get actionDetail {
    switch (intent) {
      case 'call_contact': return 'To: ${contact ?? phone ?? "unknown"}';
      case 'send_whatsapp': return 'To: ${contact ?? "unknown"}\n"${message ?? ""}"';
      case 'send_sms': return 'To: ${contact ?? "unknown"}\n"${message ?? ""}"';
      case 'open_app': return appName ?? '';
      case 'play_music': return query ?? '';
      case 'navigate_to': return destination ?? '';
      case 'set_reminder': return '${reminderMessage ?? ""} at ${reminderTime ?? "unknown time"}';
      case 'emergency_call': return 'Calling your emergency contact now';
      default: return errorMessage ?? 'Could not understand the command';
    }
  }

  IntentResponse copyWith({
    String? intent,
    String? contact,
    String? phone,
    String? message,
    String? destination,
    String? appName,
    String? query,
    String? reminderMessage,
    String? reminderTime,
    double? confidence,
    String? errorMessage,
  }) {
    return IntentResponse(
      intent: intent ?? this.intent,
      contact: contact ?? this.contact,
      phone: phone ?? this.phone,
      message: message ?? this.message,
      destination: destination ?? this.destination,
      appName: appName ?? this.appName,
      query: query ?? this.query,
      reminderMessage: reminderMessage ?? this.reminderMessage,
      reminderTime: reminderTime ?? this.reminderTime,
      confidence: confidence ?? this.confidence,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isValid => intent != 'unknown' && confidence >= 0.6;
}
