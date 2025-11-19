import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:telephony/telephony.dart';

final Telephony telephony = Telephony.instance;

Future<void> sendEmergencySMS({
  required List<String> contacts,
  required String message,
}) async {
  if (contacts.isEmpty) return;

  if (Platform.isAndroid) {
    // 🔹 Android → auto send SMS (message sent as-is, no encoding issues)
    final bool? permissionsGranted = await telephony.requestSmsPermissions;
    if (permissionsGranted ?? false) {
      for (final phone in contacts) {
        await telephony.sendSmsByDefaultApp(to: phone, message: message);
      }
    } else {
      print("SMS permission not granted");
    }
  } else if (Platform.isIOS) {
    // 🔹 iOS → open Messages app
    // iOS Messages app URL scheme: spaces in query params become +
    // We need to properly encode the message to avoid + characters
    // Using Uri.encodeComponent which converts spaces to %20 (not +)
    final firstContact = contacts.first;
    final encodedMessage = Uri.encodeComponent(message);
    final uriString = 'sms:$firstContact?body=$encodedMessage';
    final uri = Uri.parse(uriString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // If multiple contacts, user will need to add them manually in Messages app
      if (contacts.length > 1) {
        print(
          "Note: iOS only supports sending to one contact at a time via URL scheme",
        );
      }
    } else {
      print("Could not open Messages app");
    }
  }
}
