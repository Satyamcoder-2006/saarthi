import 'package:hive/hive.dart';

part 'action_log.g.dart';

@HiveType(typeId: 2)
class ActionLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String intentType;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final bool isSuccess;

  @HiveField(4)
  final DateTime timestamp;

  ActionLog({
    required this.id,
    required this.intentType,
    required this.description,
    required this.isSuccess,
    required this.timestamp,
  });

  factory ActionLog.fromJson(Map<String, dynamic> json) {
    return ActionLog(
      id: json['id'] ?? '',
      intentType: json['intentType'] ?? 'unknown',
      description: json['description'] ?? '',
      isSuccess: json['isSuccess'] ?? false,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }
}
