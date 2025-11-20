// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
// import 'package:geolocator/geolocator.dart';

// void main() {
//   runApp(const MaterialApp(home: BleScanner()));
// }

// class BleScanner extends StatefulWidget {
//   const BleScanner({super.key});

//   @override
//   State<BleScanner> createState() => _BleScannerState();
// }

// class _BleScannerState extends State<BleScanner> {
//   final _ble = FlutterReactiveBle();
//   late StreamSubscription<DiscoveredDevice> _scanStream;
//   StreamSubscription<ConnectionStateUpdate>? _connectionStream;
//   StreamSubscription<List<int>>? _notificationStream;

//   final List<DiscoveredDevice> _devices = [];
//   bool _isScanning = false;
//   bool _isConnected = false;
//   String _statusText = 'Press SCAN to start';
//   String _buttonMessage = '';
//   String _locationText = '';
//   int _pressCount = 0;
//   DiscoveredDevice? _connectedDevice;

//   // 🧩 UUIDs must match your ESP32 code
//   final Uuid serviceUuid = Uuid.parse("12345678-1234-1234-1234-1234567890ab");
//   final Uuid characteristicUuid =
//       Uuid.parse("abcdefab-1234-5678-90ab-cdef12345678");

//   @override
//   void dispose() {
//     _scanStream.cancel();
//     _connectionStream?.cancel();
//     _notificationStream?.cancel();
//     super.dispose();
//   }

//   Future<void> _requestLocationPermission() async {
//     bool serviceEnabled;
//     LocationPermission permission;

//     // Check if location service is enabled
//     serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       await Geolocator.openLocationSettings();
//       return;
//     }

//     // Check for permissions
//     permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         _statusText = 'Location permission denied';
//         setState(() {});
//         return;
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       _statusText = 'Location permissions are permanently denied';
//       setState(() {});
//       return;
//     }
//   }

//   void _startScan() {
//     _devices.clear();
//     setState(() {
//       _isScanning = true;
//       _statusText = '🔍 Scanning for BLE devices...';
//     });

//     _scanStream = _ble.scanForDevices(withServices: []).listen((device) {
//       if (_devices.indexWhere((d) => d.id == device.id) == -1) {
//         setState(() => _devices.add(device));
//       }
//     }, onError: (error) {
//       setState(() {
//         _statusText = '🚨 Scan error: $error';
//         _isScanning = false;
//       });
//     });
//   }

//   void _stopScan() {
//     _scanStream.cancel();
//     setState(() {
//       _isScanning = false;
//       _statusText = 'Scan stopped.';
//     });
//   }

//   Future<void> _getLocation() async {
//     try {
//       await _requestLocationPermission();
//       final position = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.high);

//       setState(() {
//         _locationText =
//             'My Location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
//       });
//     } catch (e) {
//       setState(() {
//         _locationText = '⚠️ Failed to get location: $e';
//       });
//     }
//   }

//   void _connectToDevice(DiscoveredDevice device) async {
//     _stopScan();
//     setState(() {
//       _statusText =
//           '🔗 Connecting to ${device.name.isNotEmpty ? device.name : device.id}...';
//     });

//     _connectionStream = _ble.connectToDevice(id: device.id).listen((update) async {
//       if (update.connectionState == DeviceConnectionState.connected) {
//         setState(() {
//           _isConnected = true;
//           _connectedDevice = device;
//           _pressCount = 0; // reset counter
//           _statusText =
//               '✅ Connected to ${device.name.isNotEmpty ? device.name : device.id}';
//         });

//         final characteristic = QualifiedCharacteristic(
//           serviceId: serviceUuid,
//           characteristicId: characteristicUuid,
//           deviceId: device.id,
//         );

//         _notificationStream =
//             _ble.subscribeToCharacteristic(characteristic).listen((data) async {
//           final message = String.fromCharCodes(data);

//           // Each time we receive button press → increment + get location
//           _pressCount++;
//           await _getLocation();

//           setState(() {
//             _buttonMessage = message;
//             _statusText = '🟢 Button Press #$_pressCount Received!';
//           });

//           debugPrint('📩 Button pressed, message: $message');
//         }, onError: (error) {
//           setState(() {
//             _statusText = '⚠️ Notification error: $error';
//           });
//         });
//       } else if (update.connectionState == DeviceConnectionState.disconnected) {
//         setState(() {
//           _isConnected = false;
//           _pressCount = 0;
//           _buttonMessage = '';
//           _locationText = '';
//           _statusText = '🔴 Disconnected';
//         });
//         _notificationStream?.cancel();
//       }
//     }, onError: (error) {
//       setState(() {
//         _statusText = '❌ Connection failed: $error';
//       });
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("BLE Button Receiver")),
//       body: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Text(_statusText, style: const TextStyle(fontSize: 18)),
//           const SizedBox(height: 20),

//           if (_isConnected) ...[
//             Text(
//               '🔢 Button pressed: $_pressCount times',
//               style:
//                   const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 10),
//           ],

//           if (_buttonMessage.isNotEmpty)
//             Text(
//               '🖲️ Last message: $_buttonMessage',
//               style:
//                   const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
//             ),

//           if (_locationText.isNotEmpty) ...[
//             const SizedBox(height: 10),
//             Text(
//               _locationText,
//               style: const TextStyle(fontSize: 18, color: Colors.blueAccent),
//             ),
//           ],

//           const SizedBox(height: 20),
//           Expanded(
//             child: ListView.builder(
//               itemCount: _devices.length,
//               itemBuilder: (context, index) {
//                 final device = _devices[index];
//                 return ListTile(
//                   title:
//                       Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
//                   subtitle: Text(device.id),
//                   trailing: Text('${device.rssi} dBm'),
//                   onTap: () => _connectToDevice(device),
//                 );
//               },
//             ),
//           ),
//           const SizedBox(height: 10),
//           ElevatedButton.icon(
//             onPressed: _isScanning ? _stopScan : _startScan,
//             icon: Icon(_isScanning ? Icons.stop : Icons.search),
//             label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
//           ),
//           const SizedBox(height: 20),
//         ],
//       ),
//     );
//   }
// }

import 'package:ble_app/pages/google_example.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ble_app/services/ble_background_service.dart';
import 'package:ble_app/services/notification_service.dart';
import 'package:ble_app/services/auth_service.dart';
import 'pages/onboard_page.dart';
import 'pages/connect_page.dart';

void main() async {
  // Ensure Flutter is initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait (optional - remove if you want landscape support)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize BLE background service
  try {
    await BleBackgroundService.initializeService();
    debugPrint('✅ BLE Background Service initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize BLE service: $e');
    // Continue anyway - the app will still work, just without background service
    // User can try to reconnect later
  }

  // Initialize notification service
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.createNotificationChannel();
    debugPrint('✅ Notification Service initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize notification service: $e');
    // Continue anyway - notifications may not work but app will function
  }

  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Peppy App',

      // 🌞 Light theme
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // 🌙 Dark theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // 👇 This lets the app switch automatically based on system settings
      themeMode: ThemeMode.system,

      // Starting page - check authentication state
      home: const AuthCheckPage(),
    );
  }
}

/// Page that checks authentication state and navigates accordingly
class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key});

  @override
  State<AuthCheckPage> createState() => _AuthCheckPageState();
}

class _AuthCheckPageState extends State<AuthCheckPage> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final isAuthenticated = await AuthService.isAuthenticated();
    
    if (mounted) {
      setState(() {
        _isChecking = false;
      });

      // If already logged in or guest, go to connect page
      // Otherwise show onboard page
      if (isAuthenticated) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ConnectPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
