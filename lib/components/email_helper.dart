import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SMTP configuration keys
const String _kSmtpHost = 'smtp_email_host';
const String _kSmtpPort = 'smtp_email_port';
const String _kSmtpUsername = 'smtp_email_username';
const String _kSmtpPassword = 'smtp_email_password';
const String _kSmtpFromEmail = 'smtp_from_email';
const String _kSmtpFromName = 'smtp_from_name';

/// Sends emergency email to multiple recipients in the background
Future<void> sendEmergencyEmail({
  required List<String> recipients,
  required String subject,
  required String message,
}) async {
  if (recipients.isEmpty) {
    print("No email recipients provided");
    return;
  }

  try {
    // Load SMTP configuration from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final smtpHost = prefs.getString(_kSmtpHost) ?? 'smtp.gmail.com';
    final smtpPort = prefs.getInt(_kSmtpPort) ?? 587;
    final smtpUsername = prefs.getString(_kSmtpUsername) ?? '';
    final smtpPassword = prefs.getString(_kSmtpPassword) ?? '';
    final fromEmail = prefs.getString(_kSmtpFromEmail) ?? smtpUsername;
    final fromName = prefs.getString(_kSmtpFromName) ?? 'Emergency Alert';

    if (smtpUsername.isEmpty || smtpPassword.isEmpty) {
      print("SMTP credentials not configured. Please set up email settings.");
      throw Exception("Email credentials not configured");
    }

    // Create SMTP server configuration
    SmtpServer smtpServer;
    if (smtpHost.contains('gmail.com')) {
      smtpServer = gmail(smtpUsername, smtpPassword);
    } else {
      smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        username: smtpUsername,
        password: smtpPassword,
        ssl: smtpPort == 465,
        allowInsecure: false,
      );
    }

    // Create email message
    final emailMessage = Message()
      ..from = Address(fromEmail, fromName)
      ..recipients = recipients
      ..subject = subject
      ..text = message
      ..html = '<p>${message.replaceAll('\n', '<br>')}</p>';

    // Send email in background
    try {
      final sendReport = await send(emailMessage, smtpServer);
      print('Email sent successfully: ${sendReport.toString()}');
    } catch (e) {
      print('Error sending email: $e');
      rethrow;
    }
  } catch (e) {
    print("Error in sendEmergencyEmail: $e");
    rethrow;
  }
}

/// Save SMTP configuration
Future<void> saveSmtpConfig({
  required String host,
  required int port,
  required String username,
  required String password,
  required String fromEmail,
  String? fromName,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kSmtpHost, host);
  await prefs.setInt(_kSmtpPort, port);
  await prefs.setString(_kSmtpUsername, username);
  await prefs.setString(_kSmtpPassword, password);
  await prefs.setString(_kSmtpFromEmail, fromEmail);
  if (fromName != null) {
    await prefs.setString(_kSmtpFromName, fromName);
  }
}

/// Get SMTP configuration
Future<Map<String, dynamic>> getSmtpConfig() async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'host': prefs.getString(_kSmtpHost) ?? 'smtp.gmail.com',
    'port': prefs.getInt(_kSmtpPort) ?? 587,
    'username': prefs.getString(_kSmtpUsername) ?? '',
    'password': prefs.getString(_kSmtpPassword) ?? '',
    'fromEmail': prefs.getString(_kSmtpFromEmail) ?? '',
    'fromName': prefs.getString(_kSmtpFromName) ?? 'Emergency Alert',
  };
}

/// Check if SMTP is configured (has username and password)
Future<bool> isSmtpConfigured() async {
  final config = await getSmtpConfig();
  final username = config['username'] as String;
  final password = config['password'] as String;
  return username.isNotEmpty && password.isNotEmpty;
}

