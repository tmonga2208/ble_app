import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _ble = FlutterReactiveBle();
  bool _notificationsEnabled = false;
  bool _bluetoothEnabled = false;
  String _appVersion = 'Loading...';
  String _buildNumber = '';
  StreamSubscription<BleStatus>? _bleStatusSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
    _checkBluetoothStatus();
    _listenToBluetoothStatus();
  }

  @override
  void dispose() {
    _bleStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
    });
    _checkNotificationPermission();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Unknown';
        _buildNumber = 'Unknown';
      });
    }
  }

  Future<void> _checkNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (mounted) {
        setState(() {
          _notificationsEnabled = status.isGranted;
        });
      }
    } catch (e) {
      // Handle error checking notification permission
      if (mounted) {
        setState(() {
          _notificationsEnabled = false;
        });
      }
    }
  }

  Future<void> _checkBluetoothStatus() async {
    try {
      final currentStatus = _ble.status;
      setState(() {
        _bluetoothEnabled = currentStatus == BleStatus.ready;
      });
    } catch (e) {
      setState(() {
        _bluetoothEnabled = false;
      });
    }
  }

  void _listenToBluetoothStatus() {
    _bleStatusSubscription = _ble.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _bluetoothEnabled = status == BleStatus.ready;
        });
      }
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // Request notification permission
      // On iOS, this will show the native permission dialog
      PermissionStatus status = await Permission.notification.request();

      // Re-check status after request (especially important for iOS)
      await _checkNotificationPermission();

      if (status.isGranted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notifications_enabled', true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications enabled'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text(
                'Notification permission is permanently denied. Please enable it in Settings > Notifications.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Platform.isIOS
                  ? 'Notification permission denied. You can enable it in Settings > Notifications.'
                  : 'Notification permission denied'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              action: Platform.isIOS
                  ? SnackBarAction(
                      label: 'Settings',
                      onPressed: () => openAppSettings(),
                    )
                  : null,
            ),
          );
        }
      }
    } else {
      // Disable notifications (save preference, but note that permission remains)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', false);
      // Still check actual permission status
      await _checkNotificationPermission();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification preference disabled'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleBluetooth(bool value) async {
    if (value) {
      // Request Bluetooth permission
      if (Platform.isAndroid) {
        final scanStatus = await Permission.bluetoothScan.request();
        final connectStatus = await Permission.bluetoothConnect.request();
        
        if (scanStatus.isGranted && connectStatus.isGranted) {
          setState(() {
            _bluetoothEnabled = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bluetooth enabled'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bluetooth permission denied'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        // iOS - Bluetooth is controlled by system settings
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Bluetooth Settings'),
              content: const Text(
                'Please enable Bluetooth in iOS Settings > Bluetooth.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
      }
    } else {
      // Note: Cannot programmatically disable Bluetooth on iOS/Android
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please disable Bluetooth in system settings'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    // Recheck status
    _checkBluetoothStatus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notifications Section
              Text(
                'Notifications',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: Text(
                    'Enable Notifications',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    _notificationsEnabled
                        ? 'Notifications are enabled'
                        : Platform.isIOS
                            ? 'Enable to receive emergency alerts and notifications'
                            : 'Enable to receive emergency alerts',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                  activeColor: Colors.blue,
                ),
              ),
              const SizedBox(height: 32),

              // Bluetooth Section
              Text(
                'Bluetooth',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: Text(
                    'Bluetooth',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    _bluetoothEnabled
                        ? 'Bluetooth is enabled'
                        : 'Enable Bluetooth to connect devices',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  value: _bluetoothEnabled,
                  onChanged: _toggleBluetooth,
                  activeColor: Colors.blue,
                ),
              ),
              const SizedBox(height: 32),

              // App Info Section
              Text(
                'App Information',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Version',
                      _appVersion,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Build Number',
                      _buildNumber,
                      isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 16,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

