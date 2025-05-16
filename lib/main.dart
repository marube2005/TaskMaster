import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';  
import 'app.dart';
import 'firebase_options.dart'; // Import your Firebase options
// Your app entry point

Future <void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
   // Initialize timezone
  tz.initializeTimeZones();
  // Set local timezone (use UTC as fallback for web)
  tz.setLocalLocation(tz.getLocation('UTC')); // Replace with user's timezone if available

  // Initialize notifications
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    ),
  );
  await notificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
  runApp(MyApp());
}

