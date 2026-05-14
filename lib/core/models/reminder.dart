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
}
