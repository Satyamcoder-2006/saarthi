import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Request all permissions the app needs upfront.
  static Future<void> requestAllPermissions() async {
    await [
      Permission.microphone,
      Permission.phone,
      Permission.contacts,
      Permission.location,
    ].request();
  }

  static Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }
}
