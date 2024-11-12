import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the background service
  await FlutterBackgroundService().configure(
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      isForegroundMode: true,
      autoStart: true,
      autoStartOnBoot: true,
      onStart: onStart, // Call onStart when the service starts
    ),
  );

  runApp(MyApp());
}

// Background service callback
void onStart(ServiceInstance service) async {
  // Ensure MQTT client is connected in the background service
  await _connectToMQTTInBackground(service);

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

Future<void> _connectToMQTTInBackground(ServiceInstance service) async {
  mqtt.MqttClient client = mqtt.MqttClient('wss.busatyapp.com', 'flutter_client');

  client.onConnected = () {
    print("Connected to MQTT in background");
    // Optionally subscribe to topics after connection
    client.subscribe('test/topic', mqtt.MqttQos.atMostOnce);
  };

  client.onDisconnected = () {
    print("Disconnected from MQTT in background");
  };

  client.onSubscribed = (topic) {
    print("Subscribed to $topic in background");
  };

  try {
    await client.connect('ashraf', 'ashraf');
    print("Connected and subscribed in background");
  } catch (e) {
    print('MQTT connection failed in background: $e');
  }

  // Listen for MQTT updates
  client.updates!.listen((List<mqtt.MqttReceivedMessage> c) {
    final message = c[0].payload as mqtt.MqttPublishMessage;
    final payload = mqtt.MqttPublishPayload.bytesToStringAsString(message.payload.message);
    // Call this method to show notification
    showNotification('New Message', payload);
  });
}

// Background fetch callback for iOS
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  print("Service is running in the background");
  return true;
}

// Global notification helper
void showNotification(String title, String body) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    notificationDetails,
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MQTTPage(),
    );
  }
}

class MQTTPage extends StatefulWidget {
  @override
  _MQTTPageState createState() => _MQTTPageState();
}

class _MQTTPageState extends State<MQTTPage> {
  mqtt.MqttClient? client;

  @override
  void initState() {
    super.initState();
    _connectToMQTT();
  }

  Future<void> _connectToMQTT() async {
    client = mqtt.MqttClient('wss.busatyapp.com', 'flutter_client');
    client!.onConnected = onConnected;
    client!.onDisconnected = onDisconnected;
    client!.onSubscribed = onSubscribed;

    try {
      await client!.connect('ashraf', 'ashraf');
      _subscribeToTopic('test/topic');
    } catch (e) {
      print('Connection failed: $e');
    }
  }

  Future<void> _subscribeToTopic(String topic) async {
    client!.subscribe(topic, mqtt.MqttQos.atMostOnce);
    client!.updates!.listen((List<mqtt.MqttReceivedMessage> c) {
      final message = c[0].payload as mqtt.MqttPublishMessage;
      final payload = mqtt.MqttPublishPayload.bytesToStringAsString(message.payload.message);
      showNotification('New Message', payload);
    });
  }

  void onConnected() {
    print('Connected to MQTT');
  }

  void onDisconnected() {
    print('Disconnected from MQTT');
  }

  void onSubscribed(String topic) {
    print('Subscribed to $topic');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MQTT Push Notifications')),
      body: Center(child: Text('MQTT Notifications without Firebase')),
    );
  }
}
