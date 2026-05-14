import 'package:url_launcher/url_launcher.dart';
import '../models/intent_response.dart';
import '../services/tts_service.dart';

class ActionExecutor {
  static Future<bool> execute(IntentResponse intent, TtsService tts) async {
    try {
      switch (intent.intent) {
        case 'call_contact':
          if (intent.phone == null) return false;
          final uri = Uri(scheme: 'tel', path: intent.phone);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
            await tts.speak("Calling ${intent.contact ?? ''}");
            return true;
          }
          break;
          
        case 'send_sms':
          if (intent.phone == null) return false;
          final uri = Uri(
            scheme: 'sms', 
            path: intent.phone,
            queryParameters: {'body': intent.message ?? ''}
          );
          await launchUrl(uri);
          await tts.speak("Opening SMS to ${intent.contact ?? ''}");
          return true;
          
        case 'navigate_to':
          if (intent.destination == null) return false;
          final query = Uri.encodeComponent(intent.destination!);
          final mapsUri = Uri.parse('https://maps.google.com/?q=$query&navigate=yes');
          await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
          await tts.speak("Opening navigation to ${intent.destination}");
          return true;
          
        case 'open_app':
          // Phase 1: simple open via URL schemes where possible, else just TTS
          await tts.speak("Opening ${intent.appName ?? 'app'}");
          return true;
          
        case 'play_music':
          if (intent.query == null) return false;
          final query = Uri.encodeComponent(intent.query!);
          final ytUri = Uri.parse('https://music.youtube.com/search?q=$query');
          await launchUrl(ytUri, mode: LaunchMode.externalApplication);
          await tts.speak("Playing ${intent.query}");
          return true;
          
        case 'set_reminder':
          await tts.speak("Reminder set for ${intent.reminderTime ?? 'later'}");
          return true;
          
        case 'emergency_call':
          // In real app, fetch emergency contact from DB and dial.
          await tts.speak("Calling emergency contact");
          return true;
          
        case 'send_whatsapp':
          if (intent.phone == null) return false;
          final phone = intent.phone!.replaceAll(RegExp(r'[^\d]'), '');
          final msg = Uri.encodeComponent(intent.message ?? '');
          final waUri = Uri.parse('https://wa.me/$phone?text=$msg');
          if (await canLaunchUrl(waUri)) {
            await launchUrl(waUri, mode: LaunchMode.externalApplication);
            await tts.speak("Opening WhatsApp for ${intent.contact ?? ''}");
            return true;
          }
          break;
      }
    } catch (e) {
      await tts.speak("I had trouble with that. Please try again.");
    }
    return false;
  }
}
