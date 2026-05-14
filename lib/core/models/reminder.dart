import 'package:hive/hive.dart';

part 'reminder.g.dart';

@HiveType(typeId: 1)
class Reminder extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final DateTime time;

  @HiveField(3)
  final String repeatPattern; // 'once', 'daily', 'weekly'

  @HiveField(4)
  bool isActive;

  Reminder({
    required this.id,
    required this.title,
    required this.time,
    this.repeatPattern = 'once',
    this.isActive = true,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] ?? '',
      title: json['message'] ?? json['title'] ?? '',
      time: DateTime.tryParse(json['trigger_at'] ?? json['time'] ?? '') ?? DateTime.now(),
      repeatPattern: json['repeat'] ?? json['repeatPattern'] ?? 'once',
      isActive: json['is_active'] ?? json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': title,
      'time': time.toIso8601String(),
      'trigger_at': time.toIso8601String(),
      'repeatPattern': repeatPattern,
      'repeat': repeatPattern,
      'isActive': isActive,
    };
  }
}
