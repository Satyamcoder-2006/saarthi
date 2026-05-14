import 'package:hive/hive.dart';

part 'contact.g.dart';

@HiveType(typeId: 0)
class Contact extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String phone;

  @HiveField(3)
  final String? whatsappNumber;

  @HiveField(4)
  final bool isEmergency;

  Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.whatsappNumber,
    this.isEmergency = false,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      whatsappNumber: json['whatsappNumber'],
      isEmergency: json['isEmergency'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'whatsappNumber': whatsappNumber,
      'isEmergency': isEmergency,
    };
  }
}
