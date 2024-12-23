import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../db/drift_db.dart';

class FetchUserDetailsScreen extends StatelessWidget {
  final AppDatabase database;

  const FetchUserDetailsScreen({super.key, required this.database});

  Future<void> _fetchAndStoreUserDetails(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();

      try {
        // Try to get user from Firestore first
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          // Store all user details in SharedPreferences
          await prefs.setString('userId', user.uid);
          await prefs.setBool('onboardingComplete', true); // Add this flag

          // Navigate to home
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          // User needs to complete onboarding
          Navigator.pushReplacementNamed(context, '/onboarding');
        }
      } catch (e) {
        print('Error fetching user details: $e');
        // Handle error appropriately
        Navigator.pushReplacementNamed(context, '/signUp');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/signUp');
    }
  }

  void _scheduleNotifications(List<Map<String, String>> planData) {
    for (int i = 0; i < planData.length; i++) {
      final reminder = planData[i];
      tz.TZDateTime? scheduledTime;

      try {
        scheduledTime = tz.TZDateTime.parse(tz.local, reminder['time']!);
      } catch (e) {
        print('Error parsing time: ${reminder['time']}, error: $e');
        continue;
      }

      // Ensure the scheduled time is in the future
      final now = tz.TZDateTime.now(tz.local);
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
        print('Adjusted scheduled time to: $scheduledTime');
      }

      final notificationTitle = reminder['title'] ?? 'Drink Water Reminder';
      final notificationBody = reminder['body'] ?? 'It\'s time to drink water!';

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          const AndroidNotificationDetails(
        'your_channel_id',
        'your_channel_name',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      FlutterLocalNotificationsPlugin().zonedSchedule(
        i,
        notificationTitle,
        notificationBody,
        scheduledTime,
        platformChannelSpecifics,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndStoreUserDetails(context);
    });
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
