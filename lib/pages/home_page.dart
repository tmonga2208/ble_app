import 'dart:async';
import 'package:ble_app/components/google_user.dart';
import 'package:ble_app/pages/connect_page.dart';
import 'package:ble_app/pages/emergeny_page.dart';
import 'package:ble_app/pages/map_page.dart';
import 'package:ble_app/pages/notfy_police.dart';
import 'package:ble_app/pages/profile-page.dart';
import 'package:ble_app/pages/settings_page.dart';
import 'package:ble_app/components/email_helper.dart';
import 'package:ble_app/services/emergency_service.dart';
import 'package:ble_app/services/ble_background_service.dart';
import 'package:ble_app/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class HomePage extends StatefulWidget {
  final DiscoveredDevice device;
  const HomePage({super.key, required this.device});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ble = FlutterReactiveBle();
  StreamSubscription<ConnectionStateUpdate>? _connectionStream;
  StreamSubscription<List<int>>? _notificationStream;

  bool _connected = false;
  bool _isListening = false;
  bool _isConnecting = false;
  bool _notifyPolice = false; // Add this with your other state variables

  String _status = 'Connecting...';
  String _message = '';
  String _location = '';
  double? _currentLatitude;
  double? _currentLongitude;
  
  // Apple Watch-style persistent connection tracking
  int _reconnectAttempts = 0;
  bool _isReconnecting = false;
  Timer? _reconnectTimer;
  Timer? _connectionHealthTimer;
  DateTime? _lastSuccessfulConnection;

  final Uuid serviceUuid = Uuid.parse("12345678-1234-1234-1234-1234567890ab");
  final Uuid characteristicUuid = Uuid.parse(
    "abcdefab-1234-5678-90ab-cdef12345678",
  );

  @override
  void initState() {
    super.initState();
    _loadEmergencyData();
    _enableWakelock();
    _startBackgroundService();
    _connectToDevice();
    _startConnectionHealthMonitoring();
  }
  
  // Apple Watch-style connection health monitoring
  void _startConnectionHealthMonitoring() {
    // Check connection health every 30 seconds
    _connectionHealthTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // If we think we're connected but haven't had a successful connection recently,
      // or if we're not connected, try to reconnect
      if (!_connected && !_isConnecting && !_isReconnecting) {
        _scheduleReconnect();
      }
    });
  }

  Future<void> _loadEmergencyData() async {
    await EmergencyService.instance.load();
  }

  Future<void> _startBackgroundService() async {
    // Start background service with device info
    // This will persist the device info and start the background service
    await BleBackgroundService.startService(
      deviceId: widget.device.id,
      deviceName: widget.device.name,
      serviceUuid: serviceUuid.toString(),
      characteristicUuid: characteristicUuid.toString(),
    );

    // Give the service a moment to start
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _enableWakelock() async {
    // Keep device awake to maintain BLE connection
    await WakelockPlus.enable();
  }

  Future<void> _disableWakelock() async {
    await WakelockPlus.disable();
  }

  void _connectToDevice() {
    if (_isConnecting && !_isReconnecting) return; // Prevent re-entry unless reconnecting
    _isConnecting = true;

    _connectionStream = _ble
        .connectToDevice(
          id: widget.device.id,
          connectionTimeout: const Duration(seconds: 10),
        )
        .listen(
          (update) {
            switch (update.connectionState) {
              case DeviceConnectionState.connecting:
                setState(
                  () => _status = "Connecting to ${widget.device.name}...",
                );
                break;

              case DeviceConnectionState.connected:
                if (!_connected) {
                  // Reset reconnection state on successful connection
                  _reconnectAttempts = 0;
                  _isReconnecting = false;
                  _reconnectTimer?.cancel();
                  _lastSuccessfulConnection = DateTime.now();
                  
                  setState(() {
                    _connected = true;
                    _status = "✅ Connected to ${widget.device.name}";
                  });
                  _startListening();
                  // Ensure background service is running
                  _startBackgroundService();
                }
                _isConnecting = false;
                _lastSuccessfulConnection = DateTime.now(); // Update on each connection state update
                break;

              case DeviceConnectionState.disconnected:
                _isConnecting = false;
                if (_connected) {
                  setState(() {
                    _connected = false;
                    _status = "❌ Disconnected from ${widget.device.name} - Reconnecting...";
                  });
                  _isListening = false;
                  _notificationStream?.cancel();
                  
                  // Apple Watch-style automatic reconnection in foreground
                  _scheduleReconnect();
                }
                break;

              default:
                break;
            }
          },
          onError: (error) {
            _isConnecting = false;
            setState(() => _status = "Connection failed: $error - Retrying...");
            
            // Apple Watch-style automatic reconnection on error
            _scheduleReconnect();
          },
        );
  }
  
  // Apple Watch-style persistent reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_isReconnecting || !mounted) {
      return;
    }
    
    _isReconnecting = true;
    _reconnectAttempts++;
    
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, max 30s
    // This ensures quick reconnection but prevents battery drain
    final baseDelay = 1; // Start with 1 second
    final maxDelay = 30; // Cap at 30 seconds
    final delaySeconds = (baseDelay * (1 << (_reconnectAttempts - 1))).clamp(baseDelay, maxDelay);
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (mounted && !_connected) {
        _isReconnecting = false;
        _connectToDevice();
      }
    });
  }

  void _startListening() {
    if (_isListening) return; // Prevent multiple subscriptions
    _isListening = true;

    final characteristic = QualifiedCharacteristic(
      serviceId: serviceUuid,
      characteristicId: characteristicUuid,
      deviceId: widget.device.id,
    );

    _notificationStream = _ble
        .subscribeToCharacteristic(characteristic)
        .listen(
          (data) async {
            final msg = String.fromCharCodes(data);
            setState(() {
              _message = msg;
              _status = "Received: $msg";
            });
            await _getLocation();
            // Send emergency message when status is set to "Received: $msg"
            await _emergencyMessage();
          },
          onError: (e) {
            setState(() => _status = "Error receiving data: $e");
          },
        );
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _location = 'Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _location = 'Location permission denied.');
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _location = '📍 ${pos.latitude}, ${pos.longitude}';
        _currentLatitude = pos.latitude;
        _currentLongitude = pos.longitude;
      });
    } catch (e) {
      setState(() => _location = 'Error getting location: $e');
    }
  }

  @override
  void dispose() {
    _connectionStream?.cancel();
    _notificationStream?.cancel();
    _reconnectTimer?.cancel();
    _connectionHealthTimer?.cancel();
    _disableWakelock();
    // Note: Don't stop background service on dispose - keep it running
    // The service will continue monitoring even when app is closed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  border: Border.all(
                    color: const Color(0xFF3A3A3C),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      "My Devices",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProfilePage(user: globalGoogleUser),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 300, // Set your desired width
                height: 60, // Set your desired height
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF3A3A3C),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${widget.device.name}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    _buildFunctionCircle(
                      icon: Icons.add,
                      color: Colors.white,
                      onTap: () {
                        //navigate to connect page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ConnectPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 450,
                      height: 300,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/peppy.png',
                          fit: BoxFit.contain, // scale properly
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF3A3A3C),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 300,
                            height: 60,
                            padding: const EdgeInsets.all(8),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // Connection Status
                                Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 12,
                                      color: _connected
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _connected ? "Connected" : "Disconnected",
                                      style: TextStyle(
                                        color: _connected
                                            ? Colors.green
                                            : Colors.red,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                // Battery Info
                                Row(
                                  children: [
                                    Icon(
                                      Icons.earbuds_battery,
                                      size: 24,
                                      color: Colors
                                          .green, // Change based on battery level if needed
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "85%", // Replace with your battery variable
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFunctionBlock(
                    icon: Icons.warning,
                    label: 'SOS Alert',
                    color: Colors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EmergencyPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 40),
                  _buildFunctionBlock(
                    icon: Icons.location_on,
                    label: 'Location',
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HeatMapPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFunctionBlock(
                    icon: Icons.local_police,
                    label: 'Notify Nearby Police',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotifyPolicePage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 40),
                  _buildFunctionBlock(
                    icon: Icons.settings,
                    label: 'Settings',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _emergencyMessage() async {
    try {
      // Reload emergency data to get latest contacts and message
      await EmergencyService.instance.load();

      final contacts = EmergencyService.instance.contacts;
      String message = EmergencyService.instance.message;

      if (contacts.isEmpty) {
        print("No emergency contacts configured");
        return;
      }

      // Append location with Google Maps link if available
      // Format coordinates without emoji to avoid encoding issues
      if (_currentLatitude != null && _currentLongitude != null) {
        final lat = _currentLatitude!.toStringAsFixed(6);
        final lng = _currentLongitude!.toStringAsFixed(6);
        final googleMapsLink = 'https://www.google.com/maps?q=$lat,$lng';
        message =
            '$message\n\nLocation: $lat, $lng\n\nView on Google Maps:\n$googleMapsLink';
      } else if (_location.isNotEmpty && _location.contains('📍')) {
        // Fallback: try to extract coordinates from location string
        final match = RegExp(r'(\d+\.\d+),\s*(\d+\.\d+)').firstMatch(_location);
        if (match != null) {
          final lat = match.group(1)!;
          final lng = match.group(2)!;
          final googleMapsLink = 'https://www.google.com/maps?q=$lat,$lng';
          message =
              '$message\n\nLocation: $lat, $lng\n\nView on Google Maps:\n$googleMapsLink';
        } else {
          // Remove emoji from location string if present
          final cleanLocation = _location.replaceAll('📍', '').trim();
          message = '$message\n\nLocation: $cleanLocation';
        }
      }

      // Show emergency notification
      final locationText = _currentLatitude != null && _currentLongitude != null
          ? '${_currentLatitude!.toStringAsFixed(6)}, ${_currentLongitude!.toStringAsFixed(6)}'
          : null;
      await NotificationService().showEmergencyNotification(
        location: locationText,
        contactCount: contacts.length,
      );

      // Send emergency email in background
      await sendEmergencyEmail(
        recipients: contacts,
        subject: "Emergency Alert",
        message: message,
      );

      setState(() {
        _status = "Emergency email sent to ${contacts.length} contact(s)";
      });
    } catch (e) {
      setState(() {
        _status = "Error sending emergency message: $e";
      });
      print("Error sending emergency message: $e");
    }
  }
}

Widget _buildFunctionBlock({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 140,
      height: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A3A3C), width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Widget _buildFunctionCircle({
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF3A3A3C), width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ],
      ),
    ),
  );
}
