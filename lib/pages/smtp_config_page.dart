import 'package:flutter/material.dart';
import 'package:ble_app/components/email_helper.dart';

class SmtpConfigPage extends StatefulWidget {
  final bool isRequired;
  const SmtpConfigPage({super.key, this.isRequired = false});

  @override
  State<SmtpConfigPage> createState() => _SmtpConfigPageState();
}

class _SmtpConfigPageState extends State<SmtpConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController(text: 'smtp.gmail.com');
  final _portController = TextEditingController(text: '587');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fromEmailController = TextEditingController();
  final _fromNameController = TextEditingController(text: 'Emergency Alert');
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fromEmailController.dispose();
    _fromNameController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingConfig() async {
    final config = await getSmtpConfig();
    if (config['username'].isNotEmpty) {
      setState(() {
        _hostController.text = config['host'] ?? 'smtp.gmail.com';
        _portController.text = (config['port'] ?? 587).toString();
        _usernameController.text = config['username'] ?? '';
        _fromEmailController.text = config['fromEmail'] ?? '';
        _fromNameController.text = config['fromName'] ?? 'Emergency Alert';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final port = int.tryParse(_portController.text.trim());
      if (port == null) {
        throw Exception('Invalid port number');
      }

      await saveSmtpConfig(
        host: _hostController.text.trim(),
        port: port,
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        fromEmail: _fromEmailController.text.trim().isNotEmpty
            ? _fromEmailController.text.trim()
            : _usernameController.text.trim(),
        fromName: _fromNameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email configuration saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Navigate back or to next page
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving configuration: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !widget.isRequired,
      onPopInvoked: widget.isRequired
          ? (didPop) async {
              if (didPop) return;
              // Show a dialog explaining that configuration is required
              await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Configuration Required'),
                  content: const Text(
                    'Email configuration is required to send emergency alerts. Please complete the setup to continue.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Continue Setup'),
                    ),
                  ],
                ),
              );
            }
          : null,
      child: Scaffold(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      appBar: widget.isRequired
          ? AppBar(
              title: const Text('Email Configuration Required'),
              backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              automaticallyImplyLeading: false,
            )
          : AppBar(
              title: const Text('Email Configuration'),
              backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Required notice
                if (widget.isRequired) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.orange.shade900.withValues(alpha: 0.3) : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.orange.shade700 : Colors.orange.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Email configuration is required to send emergency alerts. Please complete this setup.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Header
                Text(
                  'Configure Emergency Email',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set up your email account to send emergency alerts. For Gmail, use an App Password instead of your regular password.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 32),

                // SMTP Host
                TextFormField(
                  controller: _hostController,
                  decoration: InputDecoration(
                    labelText: 'SMTP Host',
                    hintText: 'smtp.gmail.com',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter SMTP host';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // SMTP Port
                TextFormField(
                  controller: _portController,
                  decoration: InputDecoration(
                    labelText: 'SMTP Port',
                    hintText: '587 (TLS) or 465 (SSL)',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter SMTP port';
                    }
                    final port = int.tryParse(value.trim());
                    if (port == null || port < 1 || port > 65535) {
                      return 'Please enter a valid port number (1-65535)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Username/Email
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'your-email@gmail.com',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email address';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password / App Password',
                    hintText: 'Enter your password or Gmail App Password',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // From Email (optional)
                TextFormField(
                  controller: _fromEmailController,
                  decoration: InputDecoration(
                    labelText: 'From Email (optional)',
                    hintText: 'Leave empty to use email address above',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // From Name
                TextFormField(
                  controller: _fromNameController,
                  decoration: InputDecoration(
                    labelText: 'From Name',
                    hintText: 'Emergency Alert',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                const SizedBox(height: 32),

                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Gmail App Password',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.blue.shade300 : Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'For Gmail, you need to create an App Password:\n1. Go to Google Account settings\n2. Security → 2-Step Verification → App passwords\n3. Generate a password for "Mail"\n4. Use that password here',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveConfig,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Configuration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

