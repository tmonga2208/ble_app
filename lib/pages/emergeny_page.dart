import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ble_app/services/emergency_service.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _messageController = TextEditingController(
    text: "This is an emergency message. Please help me as soon as possible.",
  );

  final List<TextEditingController> _contactControllers = [];
  bool _isEditingMessage = false;

  @override
  void initState() {
    super.initState();
    _loadEmergencyData();
  }

  Future<void> _loadEmergencyData() async {
    await EmergencyService.instance.load();

    // Load saved message
    if (EmergencyService.instance.message.isNotEmpty) {
      _messageController.text = EmergencyService.instance.message;
    }

    // Load saved contacts
    setState(() {
      _contactControllers.clear();
      for (final contact in EmergencyService.instance.contacts) {
        _contactControllers.add(TextEditingController(text: contact));
      }
    });
  }

  Future<void> _saveEmergencyData() async {
    // Save message
    await EmergencyService.instance.saveMessage(_messageController.text);

    // Save contacts
    final contacts = _contactControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    await EmergencyService.instance.saveContacts(contacts);
  }

  Future<void> requestContactsPermission() async {
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
      print("Contacts permission status: $status");
    }
  }

  // ----------------- CONTACT MANAGEMENT -----------------
  void _addContact() {
    if (_contactControllers.length < 5) {
      setState(() {
        _contactControllers.add(TextEditingController());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You can only add up to 5 emergency contacts."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeContact(int index) async {
    setState(() {
      _contactControllers.removeAt(index);
    });
    await _saveEmergencyData();
  }

  Future<void> _addFromContacts() async {
    if (_contactControllers.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 5 contacts allowed.")),
      );
      return;
    }

    PermissionStatus status = await Permission.contacts.status;

    if (status.isGranted) {
      await _pickContact();
    } else if (status.isDenied) {
      PermissionStatus newStatus = await Permission.contacts.request();
      if (newStatus.isGranted) {
        await _pickContact();
      } else if (newStatus.isPermanentlyDenied) {
        await requestContactsPermission();
      } else {
        _showDeniedSnack();
      }
    } else if (status.isPermanentlyDenied) {
      await requestContactsPermission();
    } else {
      _showDeniedSnack();
    }
  }

  void _showDeniedSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Permission denied to access contacts."),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Permission Required"),
        content: const Text(
          "Contacts access has been permanently denied. Please enable it in Settings > Privacy > Contacts.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickContact() async {
    try {
      // Request permission if not granted
      // On iOS, this will show the native permission dialog
      // On Android, this will also show the native permission dialog
      final hasPermission = await FlutterContacts.requestPermission(
        readonly: true, // We only need to read contacts, not modify them
      );
      
      if (!hasPermission) {
        if (Platform.isIOS) {
          // On iOS, show a dialog to guide user to settings
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Contacts Permission Required"),
              content: const Text(
                "To add emergency contacts from your contact list, please enable Contacts access in Settings > Privacy & Security > Contacts.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text("Open Settings"),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Contacts permission is required to pick a contact."),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Open contact picker (works on both iOS and Android)
      // On iOS, this opens the native iOS contact picker
      // On Android, this opens the native Android contact picker
      final Contact? contact = await FlutterContacts.openExternalPick();
      
      if (contact != null) {
        // Get the first email address from the contact
        if (contact.emails.isNotEmpty) {
          String email = contact.emails.first.address.trim();
          
          setState(() {
            _contactControllers.add(TextEditingController(text: email));
          });
          await _saveEmergencyData();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Added ${contact.displayName}'s email address"),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Selected contact has no email address."),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      // If contact is null, user cancelled the picker - no need to show error
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error picking contact: ${e.toString()}"),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    for (var c in _contactControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _saveEmergencyData();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        appBar: AppBar(title: const Text("Emergency Settings")),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- EMERGENCY CONTACTS ----------------
                Text(
                  "Emergency Email Contacts",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Add email addresses that will receive emergency alerts",
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      for (int i = 0; i < _contactControllers.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _contactControllers[i],
                                  keyboardType: TextInputType.emailAddress,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Contact ${i + 1} email address",
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF2C2C2E)
                                        : Colors.grey.shade200,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return null; // Allow empty for optional fields
                                    }
                                    if (!value.contains('@') || !value.contains('.')) {
                                      return 'Please enter a valid email address';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    // Auto-save on change
                                    _saveEmergencyData();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: isDark ? Colors.red[300] : Colors.red,
                                ),
                                onPressed: () => _removeContact(i),
                              ),
                            ],
                          ),
                        ),

                      // Buttons to add contacts
                      Row(
                        children: [
                          if (_contactControllers.length < 5)
                            TextButton.icon(
                              onPressed: _addContact,
                              icon: const Icon(Icons.add),
                              label: const Text("Add Manually"),
                            ),
                          const SizedBox(width: 8),
                          if (_contactControllers.length < 5)
                            TextButton.icon(
                              onPressed: _addFromContacts,
                              icon: const Icon(Icons.contacts),
                              label: const Text("Add from Contacts"),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ---------------- SAVED MESSAGE ----------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved Message',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        if (_isEditingMessage) {
                          // Save message when finishing edit
                          await _saveEmergencyData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Emergency settings saved"),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                        setState(() {
                          _isEditingMessage = !_isEditingMessage;
                        });
                      },
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: _isEditingMessage
                            ? Colors.blueAccent.withValues(alpha: 0.2)
                            : null,
                      ),
                      icon: Icon(
                        _isEditingMessage ? Icons.check : Icons.edit,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                _isEditingMessage
                    ? TextField(
                        controller: _messageController,
                        maxLines: null,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF2C2C2E)
                              : Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      )
                    : Text(
                        _messageController.text,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 16,
                        ),
                      ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
