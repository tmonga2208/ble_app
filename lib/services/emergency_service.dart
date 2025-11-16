import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyService {
  EmergencyService._();
  static final EmergencyService instance = EmergencyService._();

  List<String> contacts = [];
  String message =
      "This is an emergency message. Please help me as soon as possible.";

  static const _kContacts = 'emergency_contacts';
  static const _kMessage = 'emergency_message';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    contacts = (prefs.getStringList(_kContacts) ?? [])
        .where((s) => s.trim().isNotEmpty)
        .toList();
    message = prefs.getString(_kMessage) ?? message;
  }

  Future<void> saveContacts(List<String> numbers) async {
    contacts = numbers.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kContacts, contacts);
  }

  Future<void> saveMessage(String msg) async {
    message = msg;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMessage, message);
  }
}
