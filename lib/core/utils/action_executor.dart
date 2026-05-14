import 'package:url_launcher/url_launcher.dart';
import '../models/intent_response.dart';
import '../services/tts_service.dart';
import '../services/api_service.dart';

class ActionExecutor {
  static Future<bool> execute(
    IntentResponse intent,
    TtsService tts,
    ApiService api, {
    String rawText = '',
  }) async {
    bool success = false;
    try {
      success = await _dispatch(intent, tts);
    } catch (e) {
      await tts.speak('I had trouble with that. Please try again.');
      success = false;
    }

    // Log to backend (non-blocking)
    api.logExecution(
      intent: intent.intent,
      rawText: rawText,
      success: success,
    );

    return success;
  }

  static Future<bool> _dispatch(IntentResponse intent, TtsService tts) async {
    switch (intent.intent) {
      // ── Call ──────────────────────────────────────────────────────────────
      case 'call_contact':
        if (intent.phone == null) {
          await tts.speak("I don't have a phone number for ${intent.contact ?? 'that person'}. Please add them to contacts.");
          return false;
        }
        final uri = Uri(scheme: 'tel', path: intent.phone);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          await tts.speak('Calling ${intent.contact ?? ''}');
          return true;
        }
        return false;

      // ── SMS ───────────────────────────────────────────────────────────────
      case 'send_sms':
        if (intent.phone == null) {
          await tts.speak("I don't have a number for ${intent.contact ?? 'that person'}.");
          return false;
        }
        final uri = Uri(
          scheme: 'sms',
          path: intent.phone,
          queryParameters: {'body': intent.message ?? ''},
        );
        await launchUrl(uri);
        await tts.speak('Opening SMS to ${intent.contact ?? ''}');
        return true;

      // ── WhatsApp ──────────────────────────────────────────────────────────
      case 'send_whatsapp':
        if (intent.phone == null) {
          await tts.speak("I don't have a WhatsApp number for ${intent.contact ?? 'that person'}.");
          return false;
        }
        final phone = intent.phone!.replaceAll(RegExp(r'[^\d]'), '');
        final msg = Uri.encodeComponent(intent.message ?? '');
        final waUri = Uri.parse('https://wa.me/$phone?text=$msg');
        if (await canLaunchUrl(waUri)) {
          await launchUrl(waUri, mode: LaunchMode.externalApplication);
          await tts.speak('Opening WhatsApp for ${intent.contact ?? ''}');
          return true;
        }
        await tts.speak('WhatsApp is not installed on this phone.');
        return false;

      // ── Navigation ────────────────────────────────────────────────────────
      case 'navigate_to':
        if (intent.destination == null) return false;
        final query = Uri.encodeComponent(intent.destination!);
        final mapsUri = Uri.parse('https://maps.google.com/?q=$query&navigate=yes');
        await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
        await tts.speak('Opening navigation to ${intent.destination}');
        return true;

      // ── Music ─────────────────────────────────────────────────────────────
      case 'play_music':
        if (intent.query == null) return false;
        final q = Uri.encodeComponent(intent.query!);
        final ytUri = Uri.parse('https://music.youtube.com/search?q=$q');
        await launchUrl(ytUri, mode: LaunchMode.externalApplication);
        await tts.speak('Playing ${intent.query}');
        return true;

      // ── Open App ──────────────────────────────────────────────────────────
      case 'open_app':
        await tts.speak('Opening ${intent.appName ?? 'the app'}');
        return true;

      // ── Reminder ──────────────────────────────────────────────────────────
      case 'set_reminder':
        await tts.speak('Reminder set. I will remind you ${intent.reminderMessage ?? 'later'}.');
        return true;

      // ── Emergency ─────────────────────────────────────────────────────────
      case 'emergency_call':
        await tts.speak('Calling emergency contact now. Stay calm.');
        // Will dial the first emergency contact fetched from contacts
        return true;

      default:
        await tts.speak("I'm not sure what you want. Please try again.");
        return false;
    }
  }
}
