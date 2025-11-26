import 'package:ble_app/components/peppy_animate.dart';
import 'package:ble_app/components/email_helper.dart';
import 'package:flutter/material.dart';
import '../services/ble_manager.dart';
import 'home_page.dart';
import 'smtp_config_page.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final ble = BleConnectService();
  String status = 'Scanning for nearby devices...';
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _checkSmtpConfiguration();
    ble.requestLocationPermission();

    // ✅ Start scanning immediately
    ble.startScan();

    // ✅ Listen for BLE status updates
    ble.statusController.stream.listen((value) {
      if (!mounted) return;
      setState(() => status = value);

      // ✅ Navigate only once when connected
      if (!_navigated &&
          value.contains('Connected') &&
          ble.connectedDevice != null) {
        _navigated = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomePage(device: ble.connectedDevice!),
              ),
            );
          }
        });
      }
    });
  }

  Future<void> _checkSmtpConfiguration() async {
    // Check if SMTP is configured, if not show configuration page
    final isConfigured = await isSmtpConfigured();
    if (!isConfigured && mounted) {
      // Wait a bit for the page to build, then show SMTP config
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SmtpConfigPage(isRequired: true),
            ),
          );
          // If user cancelled or didn't save, we still continue
          // They can configure it later from settings
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Connect to Peppy")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(status, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 10),

          const PeppyLogoAnimation(),

          Expanded(
            child: StreamBuilder<List<dynamic>>(
              stream: ble.devicesController.stream,
              initialData: ble.devices,
              builder: (context, snapshot) {
                final devices = snapshot.data ?? [];

                if (devices.isEmpty) {
                  return const Center(
                    child: Text(
                      'Searching for devices...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      title: Text(
                        device.name.isNotEmpty ? device.name : 'Unknown Device',
                      ),
                      subtitle: Text(device.id),
                      trailing: Text('${device.rssi} dBm'),
                      onTap: () => ble.connectToDevice(device),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // ✅ Optional control button
          ElevatedButton.icon(
            onPressed: ble.isScanning ? ble.stopScan : ble.startScan,
            icon: Icon(ble.isScanning ? Icons.stop : Icons.search),
            label: Text(ble.isScanning ? 'Stop Scan' : 'Start Scan'),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
