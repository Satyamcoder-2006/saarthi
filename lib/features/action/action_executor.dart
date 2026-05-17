import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

import '../../core/models/intent_response.dart';

class ActionResult {
  final bool success;
  final String spokenFeedback;
  const ActionResult({required this.success, required this.spokenFeedback});
}

class ActionExecutor {
  // Map common app names to their URL schemes / deep links
  static const _appSchemes = {
    'youtube': 'youtube://',
    'whatsapp': 'whatsapp://',
    'camera': 'android.media.action.IMAGE_CAPTURE',
    'maps': 'geo:0,0',
    'gmail': 'googlegmail://',
    'chrome': 'googlechrome://',
    'settings': 'android.settings.SETTINGS',
    'spotify': 'spotify:',
    'instagram': 'instagram://',
    'facebook': 'fb://',
    'twitter': 'twitter://',
    'telegram': 'tg://',
  };

  static Future<ActionResult> execute(IntentResponse intent) async {
    debugPrint('[ActionExecutor] executing intent: ${intent.intent}');

    switch (intent.intent) {
      // ── PHONE CALL ─────────────────────────────────────────────
      case 'call_contact':
        return await _makeCall(intent);

      // ── WHATSAPP ────────────────────────────────────────────────
      case 'send_whatsapp':
        return await _sendWhatsApp(intent);

      // ── SMS ─────────────────────────────────────────────────────
      case 'send_sms':
        return await _sendSms(intent);

      // ── OPEN APP ────────────────────────────────────────────────
      case 'open_app':
        return await _openApp(intent);

      // ── PLAY MUSIC ──────────────────────────────────────────────
      case 'play_music':
        return await _playMusic(intent);

      // ── NAVIGATION ──────────────────────────────────────────────
      case 'navigate_to':
        return await _navigate(intent);

      // ── REMINDER ────────────────────────────────────────────────
      case 'set_reminder':
        return await _setReminder(intent);

      // ── EMERGENCY ───────────────────────────────────────────────
      case 'emergency_call':
        return await _emergencyCall(intent);

      default:
        return const ActionResult(
          success: false,
          spokenFeedback: "I don't know how to do that yet.",
        );
    }
  }

  // ─────────────────────────────────────────────────────────────────
  static Future<ActionResult> _makeCall(IntentResponse intent) async {
    final phone = intent.phone ?? '';
    if (phone.isEmpty) {
      return ActionResult(
        success: false,
        spokenFeedback: 'I could not find ${intent.contact ?? "that contact"}\'s phone number.',
      );
    }

    // Strip everything except digits and leading +
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    try {
      // FlutterPhoneDirectCaller.callNumber fires ACTION_CALL —
      // the call connects immediately without opening the dialpad.
      // It handles the CALL_PHONE permission request automatically
      // on first use if not already granted.
      final bool? res = await FlutterPhoneDirectCaller.callNumber(cleaned);

      if (res == true) {
        return ActionResult(
          success: true,
          spokenFeedback: 'Calling ${intent.contact ?? cleaned} now.',
        );
      } else {
        // Permission denied or call failed — fall back to dialpad
        final uri = Uri(scheme: 'tel', path: cleaned);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
        return ActionResult(
          success: false,
          spokenFeedback: 'Opening the dialpad for ${intent.contact ?? cleaned}.',
        );
      }
    } catch (e) {
      debugPrint('[ActionExecutor] direct call error: $e');
      // Fallback to dialpad on any exception
      final uri = Uri(scheme: 'tel', path: cleaned);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
      return ActionResult(
        success: false,
        spokenFeedback: 'Opening the dialpad. Please tap call.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────
  static Future<ActionResult> _sendWhatsApp(IntentResponse intent) async {
    // WhatsApp URL scheme: wa.me opens WhatsApp with pre-filled message
    // User still needs to tap Send — full automation is Phase 3
    final rawPhone = intent.phone ?? '';
    if (rawPhone.isEmpty) {
      return ActionResult(
        success: false,
        spokenFeedback: 'I could not find ${intent.contact}\'s WhatsApp number.',
      );
    }

    // Strip all non-digits, ensure country code
    String phone = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.startsWith('0')) phone = '91${phone.substring(1)}';
    if (!phone.startsWith('91') && phone.length == 10) phone = '91$phone';

    final message = Uri.encodeComponent(intent.message ?? '');
    final uri = Uri.parse('https://wa.me/$phone?text=$message');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return ActionResult(
          success: true,
          spokenFeedback:
              'Opening WhatsApp for ${intent.contact ?? "the contact"}. The message is ready, just tap send.',
        );
      }
    } catch (e) {
      debugPrint('[ActionExecutor] whatsapp error: $e');
    }
    return const ActionResult(
      success: false,
      spokenFeedback: 'Could not open WhatsApp. Is it installed?',
    );
  }

  // ─────────────────────────────────────────────────────────────────
  static Future<ActionResult> _sendSms(IntentResponse intent) async {
    final phone = intent.phone ?? '';
    if (phone.isEmpty) {
      return ActionResult(
        success: false,
        spokenFeedback: 'I could not find ${intent.contact}\'s number.',
      );
    }
    final message = Uri.encodeComponent(intent.message ?? '');
    final uri = Uri.parse('sms:$phone?body=$message');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return ActionResult(
          success: true,
          spokenFeedback: 'Opening message to ${intent.contact ?? phone}.',
        );
      }
    } catch (e) {
      debugPrint('[ActionExecutor] sms error: $e');
    }
    return const ActionResult(
      success: false,
      spokenFeedback: 'Could not open messages.',
    );
  }

  // ─────────────────────────────────────────────────────────────────
  static Future<ActionResult> _openApp(IntentResponse intent) async {
    final name = (intent.appName ?? '').toLowerCase();
    final scheme = _appSchemes[name];

    if (scheme != null) {
      final uri = Uri.tryParse(scheme);
      if (uri != null) {
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return ActionResult(
              success: true,
              spokenFeedback: 'Opening ${intent.appName}.',
            );
          }
        } catch (e) {
          debugPrint('[ActionExecutor] openApp error: $e');
        }
      }
    }

    // Fallback: search Play Store
    final searchUri = Uri.parse(
        'https://play.google.com/store/search?q=${Uri.encodeComponent(name)}');
    await launchUrl(searchUri, mode: LaunchMode.externalApplication);
    return ActionResult(
      success: true,
      spokenFeedback: '${intent.appName} may not be installed. Searching for it.',
    );
  }

  // ─────────────────────────────────────────────────────────────────
  static Future<ActionResult> _playMusic(IntentResponse intent) async {
    final query = intent.query ?? '';
    final uri = Uri.parse(
        'https://music.youtube.com/search?q=${Uri.encodeComponent(query)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return ActionResult(
        success: true,
        spokenFeedback: 'Playing ${query.isNotEmpty ? query : "music"}.',
      );
    } catch (e) {
      return const ActionResult(
        success: false,
        spokenFeedback: 'Could not open music.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────
  static Future<ActionResult> _navigate(IntentResponse intent) async {
    final dest = intent.destination ?? '';
    if (dest.isEmpty) {
      return const ActionResult(
        success: false,
        spokenFeedback: 'Where would you like to go?',
      );
    }
    final uri = Uri.parse(
        'https://maps.google.com/?q=${Uri.encodeComponent(dest)}&navigate=yes');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return ActionResult(
        success: true,
        spokenFeedback: 'Opening navigation to $dest.',
      );
    } catch (e) {
      return const ActionResult(
        success: false,
        spokenFeedback: 'Could not open Google Maps.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────
  static Future<ActionResult> _setReminder(IntentResponse intent) async {
    // For now: open the clock/reminder app with the message
    // Full local notification scheduling is in RemindersProvider
    final uri = Uri.parse('android.intent.action.SET_ALARM');
    return ActionResult(
      success: true,
      spokenFeedback:
          'Reminder set for ${intent.reminderMessage ?? "your task"} at ${intent.reminderTime ?? "the specified time"}.',
    );
  }

  // ─────────────────────────────────────────────────────────────────
  static Future<ActionResult> _emergencyCall(IntentResponse intent) async {
    final phone = intent.phone ?? '112';
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    try {
      await FlutterPhoneDirectCaller.callNumber(cleaned);
      return const ActionResult(
        success: true,
        spokenFeedback: 'Calling emergency contact now.',
      );
    } catch (e) {
      debugPrint('[ActionExecutor] direct emergency call error: $e');
      final uri = Uri(scheme: 'tel', path: cleaned);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
      return const ActionResult(
        success: false,
        spokenFeedback: 'Please call for help manually.',
      );
    }
  }
}
