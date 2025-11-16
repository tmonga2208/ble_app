import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BleConnectService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final statusController = StreamController<String>.broadcast();
  final devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  final List<DiscoveredDevice> _devices = [];
  bool isScanning = false;
  DiscoveredDevice? connectedDevice;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;

  // Expose a read-only list of devices
  List<DiscoveredDevice> get devices => _devices;

  /// ✅ Ask for location permission (needed for BLE scan)
  Future<void> requestLocationPermission() async {
    await Permission.locationWhenInUse.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  /// ✅ Start scanning and broadcast results in real time
  void startScan() {
    if (isScanning) return;
    isScanning = true;
    _devices.clear();
    statusController.add('Scanning for devices...');

    _scanSubscription = _ble
        .scanForDevices(withServices: [])
        .listen(
          (device) {
            final alreadyFound = _devices.any((d) => d.id == device.id);
            if (!alreadyFound) {
              _devices.add(device);
              devicesController.add(
                List.from(_devices),
              ); // 🔥 broadcast updated list
            }
          },
          onError: (error) {
            statusController.add('Scan error: $error');
            isScanning = false;
          },
        );
  }

  /// ✅ Stop scanning
  void stopScan() {
    if (!isScanning) return;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    isScanning = false;
    statusController.add('Scan stopped');
  }

  /// ✅ Connect to selected device
  Future<void> connectToDevice(DiscoveredDevice device) async {
    stopScan();
    statusController.add('Connecting to ${device.name}...');

    _connectionSubscription = _ble
        .connectToDevice(
          id: device.id,
          connectionTimeout: const Duration(seconds: 5),
        )
        .listen(
          (update) {
            switch (update.connectionState) {
              case DeviceConnectionState.connected:
                connectedDevice = device;
                statusController.add('Connected to ${device.name}');
                break;
              case DeviceConnectionState.disconnected:
                statusController.add('Disconnected');
                connectedDevice = null;
                break;
              default:
                break;
            }
          },
          onError: (error) {
            statusController.add('Connection error: $error');
          },
        );
  }

  /// ✅ Clean up everything
  void dispose() {
    stopScan();
    _connectionSubscription?.cancel();
    statusController.close();
    devicesController.close();
  }
}
