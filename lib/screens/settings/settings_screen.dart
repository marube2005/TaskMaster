import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:myapp/services/firestore_service.dart';
//import 'package:timezone/data/latest_all.dart' as tz;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  TimeOfDay? _sleepTime;
  TimeOfDay? _wakeTime;
  List<String> _interests = [];
  final TextEditingController _interestController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadPreferences();
  }

  Future<void> _initializeNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _loadPreferences() async {
    final uid = _auth.currentUser!.uid;
    final preferences = await _firestoreService.getUserPreferences(uid);
    if (preferences != null) {
      setState(() {
        if (preferences['sleepTime'] != null) {
          final time = (preferences['sleepTime'] as Timestamp).toDate();
          _sleepTime = TimeOfDay(hour: time.hour, minute: time.minute);
        }
        if (preferences['wakeTime'] != null) {
          final time = (preferences['wakeTime'] as Timestamp).toDate();
          _wakeTime = TimeOfDay(hour: time.hour, minute: time.minute);
        }
        if (preferences['interests'] != null) {
          _interests = List<String>.from(preferences['interests']);
        }
      });
    }
  }

  Future<void> _addInterest() async {
    if (_interestController.text.trim().isEmpty) return;
    final interest = _interestController.text.trim();
    final uid = _auth.currentUser!.uid;
    try {
      await _firestoreService.addUserInterest(uid, interest);
      setState(() {
        _interests.add(interest);
        _interestController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding interest: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _removeInterest(String interest) async {
    final uid = _auth.currentUser!.uid;
    try {
      await _firestoreService.removeUserInterest(uid, interest);
      setState(() {
        _interests.remove(interest);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing interest: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _setTime(String type) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selectedTime != null) {
      setState(() {
        if (type == 'sleep') {
          _sleepTime = selectedTime;
        } else {
          _wakeTime = selectedTime;
        }
      });
      await _savePreferences();
      await _scheduleNotification(type, selectedTime);
    }
  }

  Future<void> _savePreferences() async {
    final uid = _auth.currentUser!.uid;
    final preferences = {
      if (_sleepTime != null)
        'sleepTime': Timestamp.fromDate(
          DateTime(2025, 1, 1, _sleepTime!.hour, _sleepTime!.minute),
        ),
      if (_wakeTime != null)
        'wakeTime': Timestamp.fromDate(
          DateTime(2025, 1, 1, _wakeTime!.hour, _wakeTime!.minute),
        ),
      'interests': _interests,
    };
    try {
      await _firestoreService.updateUserPreferences(uid, preferences);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving preferences: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _scheduleNotification(String type, TimeOfDay time) async {
    try {
      final now = DateTime.now();
      var scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(Duration(days: 1));
      }

      // Continue with scheduling the notification using scheduledTime..
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          '${type}_channel',
          '${type.capitalize} Reminders',
          channelDescription: 'Notification for $type time reminder',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      await _notificationsPlugin.zonedSchedule(
        type == 'sleep' ? 1 : 2,
        type == 'sleep' ? 'Time to Sleep' : 'Time to Wake Up',
        type == 'sleep' ? 'Get ready for bed!' : 'Start your day!',
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exact,
      //  uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scheduling notification: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                'Sleep Time: ${_sleepTime?.format(context) ?? "Not set"}',
                semanticsLabel: 'Sleep Time',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _setTime('sleep'),
            ),
            ListTile(
              title: Text(
                'Wake Time: ${_wakeTime?.format(context) ?? "Not set"}',
                semanticsLabel: 'Wake Time',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _setTime('wake'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Interests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              semanticsLabel: 'Interests',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _interestController,
                      decoration: const InputDecoration(
                        hintText: 'Add interest (e.g., reading)',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addInterest(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.blue),
                    onPressed: _addInterest,
                    tooltip: 'Add Interest',
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children:
                  _interests.map((interest) {
                    return Semantics(
                      label: 'Interest: $interest',
                      child: Chip(
                        label: Text(interest),
                        onDeleted: () => _removeInterest(interest),
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _auth.signOut(),
              child: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String get capitalize => this[0].toUpperCase() + substring(1);
}
