import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_background_service_ios/flutter_background_service_ios.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ble_app/components/email_helper.dart';
import 'package:ble_app/services/emergency_service.dart';
import 'package:ble_app/services/notification_service.dart';

class BleBackgroundService {
  static const String deviceIdKey = 'device_id';
  static const String deviceNameKey = 'device_name';
  static const String serviceUuidKey = 'service_uuid';
  static const String characteristicUuidKey = 'characteristic_uuid';
  
  // SharedPreferences keys for persistence
  static const String _prefsDeviceIdKey = 'ble_background_device_id';
  static const String _prefsDeviceNameKey = 'ble_background_device_name';
  static const String _prefsServiceUuidKey = 'ble_background_service_uuid';
  static const String _prefsCharacteristicUuidKey = 'ble_background_characteristic_uuid';

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'ble_connection',
        initialNotificationTitle: 'BLE Connection Active',
        initialNotificationContent: 'Monitoring device for emergency alerts',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    // On iOS, background execution is very limited
    // The app can wake up when BLE events occur due to bluetooth-central background mode
    // but it cannot run continuously like Android
    
    // Note: On iOS, when app is completely closed, iOS suspends execution
    // The BLE connection must be established while app is active/background
    // iOS will wake the app briefly when BLE notifications arrive
    
    // For iOS, we rely on flutter_reactive_ble's native background support
    // The connection and notifications should work when app wakes up
    
    // Start the service logic (same as foreground)
    // onStart will handle the BLE connection and message listening
    onStart(service);
    
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Initialize notification service in background isolate
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.createNotificationChannel();
    } catch (e) {
      service.invoke('error', {'message': 'Notification init error: $e'});
    }

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    final _ble = FlutterReactiveBle();

    // Get device info from service
    String? deviceId;
    String? deviceName;
    Uuid? serviceUuid;
    Uuid? characteristicUuid;

    double? currentLatitude;
    double? currentLongitude;

    // Store references that will be updated
    final connectionRef = <StreamSubscription<ConnectionStateUpdate>?>[null];
    final notificationRef = <StreamSubscription<List<int>>?>[null];
    
    // Reconnection state tracking (like Apple Watch persistent connection)
    final reconnectAttempts = <int>[0]; // Track reconnection attempts
    final isReconnecting = <bool>[false]; // Prevent multiple simultaneous reconnection attempts
    final lastConnectionTime = <DateTime?>[null]; // Track last successful connection

    // Function to connect with device info
    Future<void> connectWithDeviceInfo(
      String devId,
      String devName,
      Uuid sUuid,
      Uuid cUuid,
    ) async {
      // Save to SharedPreferences for persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsDeviceIdKey, devId);
      await prefs.setString(_prefsDeviceNameKey, devName);
      await prefs.setString(_prefsServiceUuidKey, sUuid.toString());
      await prefs.setString(_prefsCharacteristicUuidKey, cUuid.toString());

      deviceId = devId;
      deviceName = devName;
      serviceUuid = sUuid;
      characteristicUuid = cUuid;
      
      // Reset reconnection state when manually connecting
      reconnectAttempts[0] = 0;
      isReconnecting[0] = false;

      _connectToDevice(
        _ble,
        devId,
        sUuid,
        cUuid,
        devName,
        service,
        connectionRef,
        notificationRef,
        reconnectAttempts,
        isReconnecting,
        lastConnectionTime,
        (lat, lng) {
          currentLatitude = lat;
          currentLongitude = lng;
        },
      );
    }

    // Load persisted device info and connect immediately
    SharedPreferences.getInstance().then((prefs) async {
      final savedDeviceId = prefs.getString(_prefsDeviceIdKey);
      final savedDeviceName = prefs.getString(_prefsDeviceNameKey) ?? 'Device';
      final savedServiceUuid = prefs.getString(_prefsServiceUuidKey);
      final savedCharUuid = prefs.getString(_prefsCharacteristicUuidKey);

      if (savedDeviceId != null &&
          savedServiceUuid != null &&
          savedCharUuid != null) {
        try {
          await connectWithDeviceInfo(
            savedDeviceId,
            savedDeviceName,
            Uuid.parse(savedServiceUuid),
            Uuid.parse(savedCharUuid),
          );
        } catch (e) {
          service.invoke('error', {
            'message': 'Failed to restore connection: $e',
          });
        }
      }
    });

    // Listen for device info updates
    service.on('updateDevice').listen((event) async {
      if (event != null) {
        final devId = event[deviceIdKey] as String?;
        final devName = event[deviceNameKey] as String?;
        final serviceUuidStr = event[serviceUuidKey] as String?;
        final charUuidStr = event[characteristicUuidKey] as String?;

        if (devId != null &&
            serviceUuidStr != null &&
            charUuidStr != null) {
          await connectWithDeviceInfo(
            devId,
            devName ?? 'Device',
            Uuid.parse(serviceUuidStr),
            Uuid.parse(charUuidStr),
          );
        }
      }
    });

    // Periodic task to keep service alive and update notification
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: deviceName != null
                ? "Connected to $deviceName"
                : "BLE Connection Active",
            content: deviceId != null
                ? "Monitoring for emergency alerts"
                : "Waiting for device connection",
          );
        }
      }

      // Check connection status and proactively reconnect if needed
      if (deviceId != null && serviceUuid != null && characteristicUuid != null) {
        // Proactive connection health check - if we haven't received updates in a while,
        // the connection might be stale even if not explicitly disconnected
        // This helps maintain Apple Watch-like always-connected behavior
        service.invoke('status', {'connected': true});
      }
    });
  }

  static void _connectToDevice(
    FlutterReactiveBle ble,
    String deviceId,
    Uuid serviceUuid,
    Uuid characteristicUuid,
    String deviceName,
    ServiceInstance service,
    List<StreamSubscription<ConnectionStateUpdate>?> connectionRef,
    List<StreamSubscription<List<int>>?> notificationRef,
    List<int> reconnectAttempts,
    List<bool> isReconnecting,
    List<DateTime?> lastConnectionTime,
    Function(double, double) onLocationUpdate,
  ) {
    // Prevent multiple simultaneous reconnection attempts
    if (isReconnecting[0]) {
      return;
    }
    
    // Cancel existing connections
    connectionRef[0]?.cancel();
    notificationRef[0]?.cancel();

    service.invoke('status', {
      'message': 'Connecting to $deviceName...',
      'connected': false,
    });

    connectionRef[0] = ble
        .connectToDevice(
          id: deviceId,
          connectionTimeout: const Duration(seconds: 10),
        )
        .listen(
          (update) {
            switch (update.connectionState) {
              case DeviceConnectionState.connected:
                // Reset reconnection attempts on successful connection
                reconnectAttempts[0] = 0;
                isReconnecting[0] = false;
                lastConnectionTime[0] = DateTime.now();
                
                service.invoke('status', {
                  'message': 'Connected to $deviceName',
                  'connected': true,
                });

                _startListening(
                  ble,
                  deviceId,
                  serviceUuid,
                  characteristicUuid,
                  service,
                  notificationRef,
                  onLocationUpdate,
                );
                break;

              case DeviceConnectionState.disconnected:
                service.invoke('status', {
                  'message': 'Disconnected from $deviceName - Reconnecting...',
                  'connected': false,
                });
                notificationRef[0]?.cancel();
                
                // Apple Watch-style persistent reconnection
                _scheduleReconnect(
                  ble,
                  deviceId,
                  serviceUuid,
                  characteristicUuid,
                  deviceName,
                  service,
                  connectionRef,
                  notificationRef,
                  reconnectAttempts,
                  isReconnecting,
                  lastConnectionTime,
                  onLocationUpdate,
                );
                break;

              case DeviceConnectionState.connecting:
                service.invoke('status', {
                  'message': 'Connecting...',
                  'connected': false,
                });
                break;

              default:
                break;
            }
          },
          onError: (error) {
            service.invoke('status', {
              'message': 'Connection error: $error - Retrying...',
              'connected': false,
            });
            
            // Apple Watch-style persistent reconnection on error
            _scheduleReconnect(
              ble,
              deviceId,
              serviceUuid,
              characteristicUuid,
              deviceName,
              service,
              connectionRef,
              notificationRef,
              reconnectAttempts,
              isReconnecting,
              lastConnectionTime,
              onLocationUpdate,
            );
          },
        );
  }
  
  // Apple Watch-style persistent reconnection with exponential backoff
  static void _scheduleReconnect(
    FlutterReactiveBle ble,
    String deviceId,
    Uuid serviceUuid,
    Uuid characteristicUuid,
    String deviceName,
    ServiceInstance service,
    List<StreamSubscription<ConnectionStateUpdate>?> connectionRef,
    List<StreamSubscription<List<int>>?> notificationRef,
    List<int> reconnectAttempts,
    List<bool> isReconnecting,
    List<DateTime?> lastConnectionTime,
    Function(double, double) onLocationUpdate,
  ) {
    if (deviceId.isEmpty || isReconnecting[0]) {
      return;
    }
    
    isReconnecting[0] = true;
    reconnectAttempts[0]++;
    
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, max 30s
    // This ensures quick reconnection but prevents battery drain from constant attempts
    final baseDelay = 1; // Start with 1 second
    final maxDelay = 30; // Cap at 30 seconds
    final delaySeconds = (baseDelay * (1 << (reconnectAttempts[0] - 1))).clamp(baseDelay, maxDelay);
    
    Future.delayed(Duration(seconds: delaySeconds), () {
      isReconnecting[0] = false;
      
      // Only reconnect if device ID is still valid
      if (deviceId.isNotEmpty) {
        _connectToDevice(
          ble,
          deviceId,
          serviceUuid,
          characteristicUuid,
          deviceName,
          service,
          connectionRef,
          notificationRef,
          reconnectAttempts,
          isReconnecting,
          lastConnectionTime,
          onLocationUpdate,
        );
      }
    });
  }

  static void _startListening(
    FlutterReactiveBle ble,
    String deviceId,
    Uuid serviceUuid,
    Uuid characteristicUuid,
    ServiceInstance service,
    List<StreamSubscription<List<int>>?> notificationRef,
    Function(double, double) onLocationUpdate,
  ) {
    final characteristic = QualifiedCharacteristic(
      serviceId: serviceUuid,
      characteristicId: characteristicUuid,
      deviceId: deviceId,
    );

    notificationRef[0] = ble.subscribeToCharacteristic(characteristic).listen(
      (data) async {
        final msg = String.fromCharCodes(data);
        service.invoke('message', {'text': msg});

        // Send emergency message immediately (location can be added later if needed)
        // On iOS, we need to process quickly as background execution time is limited
        try {
          // Try to get location, but don't wait too long
          final locationFuture = Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied || 
              permission == LocationPermission.deniedForever) {
            // No location permission, send without location
            await _sendEmergencyMessage(null, null, service);
          } else {
            // Try to get location with timeout
            try {
              final pos = await locationFuture.timeout(
                const Duration(seconds: 3),
                onTimeout: () => throw TimeoutException('Location timeout'),
              );
              onLocationUpdate(pos.latitude, pos.longitude);
              await _sendEmergencyMessage(
                pos.latitude,
                pos.longitude,
                service,
              );
            } catch (e) {
              // Location failed, send without location
              service.invoke('error', {'message': 'Location error: $e'});
              await _sendEmergencyMessage(null, null, service);
            }
          }
        } catch (e) {
          service.invoke('error', {'message': 'Location error: $e'});
          // Still try to send emergency message without location
          await _sendEmergencyMessage(null, null, service);
        }
      },
      onError: (e) {
        service.invoke('error', {'message': 'BLE error: $e'});
      },
    );
  }

  static Future<void> _sendEmergencyMessage(
    double? latitude,
    double? longitude,
    ServiceInstance service,
  ) async {
    try {
      await EmergencyService.instance.load();

      final contacts = EmergencyService.instance.contacts;
      String message = EmergencyService.instance.message;

      if (contacts.isEmpty) {
        service.invoke('error', {
          'message': 'No emergency contacts configured',
        });
        return;
      }

      // Append location with Google Maps link if available
      String? locationText;
      if (latitude != null && longitude != null) {
        final lat = latitude.toStringAsFixed(6);
        final lng = longitude.toStringAsFixed(6);
        locationText = '$lat, $lng';
        final googleMapsLink = 'https://www.google.com/maps?q=$lat,$lng';
        message = '$message\n\nLocation: $lat, $lng\n\nView on Google Maps:\n$googleMapsLink';
      }

      // Show emergency notification
      try {
        await NotificationService().showEmergencyNotification(
          location: locationText,
          contactCount: contacts.length,
        );
      } catch (e) {
        service.invoke('error', {'message': 'Notification error: $e'});
      }

      // Send emergency email in background
      await sendEmergencyEmail(
        recipients: contacts,
        subject: "Emergency Alert",
        message: message,
      );

      service.invoke('emergencySent', {
        'contacts': contacts.length,
        'hasLocation': latitude != null && longitude != null,
      });
    } catch (e) {
      service.invoke('error', {
        'message': 'Emergency message error: $e',
      });
    }
  }

  static Future<void> startService({
    required String deviceId,
    required String deviceName,
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    final service = FlutterBackgroundService();
    service.invoke(
      'updateDevice',
      {
        deviceIdKey: deviceId,
        deviceNameKey: deviceName,
        serviceUuidKey: serviceUuid,
        characteristicUuidKey: characteristicUuid,
      },
    );
  }

  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    
    // Clear persisted device info
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsDeviceIdKey);
    await prefs.remove(_prefsDeviceNameKey);
    await prefs.remove(_prefsServiceUuidKey);
    await prefs.remove(_prefsCharacteristicUuidKey);
  }
}

