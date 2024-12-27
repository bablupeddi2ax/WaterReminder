import 'dart:convert';

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

  // Future<void> _fetchAndStoreUserDetails(BuildContext context) async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user != null) {
  //     final prefs = await SharedPreferences.getInstance();
  //
  //     try {
  //       final userDoc = await FirebaseFirestore.instance
  //           .collection('users')
  //           .doc(user.uid)
  //           .get();
  //
  //       if (userDoc.exists) {
  //         // Store user details in SharedPreferences
  //         await prefs.setString('name', userDoc.data()?['name']??"");
  //         await prefs.setInt('age', userDoc.data()?['age']??"");
  //         await prefs.setInt('weight', userDoc.data()?['weight']??0);
  //         await prefs.setString('userId', user.uid);
  //         await prefs.setBool('onboardingComplete', true);
  //
  //         // Get the notification plan from Firestore
  //         final planData = List<Map<String, String>>.from(userDoc.data()?['plan'] ?? []);
  //
  //         // Convert to the format needed for notifications
  //         final notificationPlanData = planData.map((reminder) => {
  //           'id': reminder['id'].toString(),
  //           'time': reminder['time'],
  //           'title': reminder['title'],
  //           'body': reminder['body'],
  //         }).toList();
  //
  //         // Store plan in SharedPreferences
  //         await prefs.setStringList(
  //             'plan',
  //             notificationPlanData.map((reminder) => jsonEncode(reminder)).toList()
  //         );
  //
  //         // Cancel any existing notifications before scheduling new ones
  //         await FlutterLocalNotificationsPlugin().cancelAll();
  //
  //         // Schedule the notifications
  //         _scheduleNotifications(notificationPlanData as List<Map<String,String>>);
  //
  //         // Navigate to home
  //         Navigator.pushReplacementNamed(context, '/home');
  //       } else {
  //         Navigator.pushReplacementNamed(context, '/onboarding');
  //       }
  //     } catch (e) {
  //       print('Error fetching user details: $e');
  //       Navigator.pushReplacementNamed(context, '/signUp');
  //     }
  //   } else {
  //     Navigator.pushReplacementNamed(context, '/home');
  //   }
  // }
  Future<void> _fetchAndStoreUserDetails(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {  // Added null check
          final userData = userDoc.data()!;

          // Added type checking and safe conversions
          final name = userData['name'] as String? ?? "";
          final age = (userData['age'] as num?)?.toInt() ?? 0;
          final weight = (userData['weight'] as num?)?.toInt() ?? 0;

          // Store user details in SharedPreferences with proper type handling
          await prefs.setString('name', name);
          await prefs.setInt('age', age);
          await prefs.setInt('weight', weight);
          await prefs.setString('userId', user.uid);
          await prefs.setBool('onboardingComplete', true);

          // Safe type casting for plan data
          final rawPlanData = userData['plan'];
          if (rawPlanData != null && rawPlanData is List) {
            final planData = rawPlanData.map((item) {
              if (item is Map) {
                return {
                  'id': (item['id'] ?? '').toString(),
                  'time': (item['time'] ?? '').toString(),
                  'title': (item['title'] ?? '').toString(),
                  'body': (item['body'] ?? '').toString(),
                };
              }
              return null;
            }).whereType<Map<String, String>>().toList();

            // Store plan in SharedPreferences
            await prefs.setStringList(
                'plan',
                planData.map((reminder) => jsonEncode(reminder)).toList()
            );

            // Cancel any existing notifications before scheduling new ones
            await FlutterLocalNotificationsPlugin().cancelAll();

            // Schedule the notifications
            _scheduleNotifications(planData);
          }

          // Navigate to home
          if (context.mounted) {  // Added context.mounted check
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/onboarding');
          }
        }
      } catch (e) {
        print('Error fetching user details: $e');
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/signUp');
        }
      }
    } else {
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/signUp');  // Changed from /home to /signUp
      }
    }
  }


  // void _scheduleNotifications(List<Map<String, String>> planData) {
  //   print(planData);
  //   for (int i = 0; i < planData.length; i++) {
  //     final reminder = planData[i];
  //     tz.TZDateTime? scheduledTime;
  //
  //     try {
  //       scheduledTime = tz.TZDateTime.parse(tz.local, reminder['time']!);
  //     } catch (e) {
  //       print('Error parsing time: ${reminder['time']}, error: $e');
  //       continue;
  //     }
  //
  //     // Ensure the scheduled time is in the future
  //     final now = tz.TZDateTime.now(tz.local);
  //     if (scheduledTime.isBefore(now)) {
  //       scheduledTime = scheduledTime.add(const Duration(days: 1));
  //       print('Adjusted scheduled time to: $scheduledTime');
  //     }
  //
  //     final notificationTitle = reminder['title'] ?? 'Drink Water Reminder';
  //     final notificationBody = reminder['body'] ?? 'It\'s time to drink water!';
  //
  //     final AndroidNotificationDetails androidPlatformChannelSpecifics =
  //         const AndroidNotificationDetails(
  //       'water_reminder_channel',
  //       'Water Reminders',
  //           importance: Importance.max,
  //           priority: Priority.high,
  //           actions: <AndroidNotificationAction>[
  //             AndroidNotificationAction(
  //               'DRINK_ACTION',
  //               'Drink',
  //               showsUserInterface: false,
  //               cancelNotification: false,
  //             ),
  //             AndroidNotificationAction(
  //               'SNOOZE_ACTION',
  //               'Snooze',
  //               showsUserInterface: false,
  //               cancelNotification: false,
  //             ),
  //           ],
  //           playSound: true,
  //           enableLights: true,
  //           enableVibration: true,
  //           fullScreenIntent: true,
  //           category: AndroidNotificationCategory.alarm,
  //     );
  //     final NotificationDetails platformChannelSpecifics =
  //         NotificationDetails(android: androidPlatformChannelSpecifics);
  //
  //     FlutterLocalNotificationsPlugin().zonedSchedule(
  //       i,
  //       notificationTitle,
  //       notificationBody,
  //       scheduledTime,
  //       platformChannelSpecifics,
  //       uiLocalNotificationDateInterpretation:
  //           UILocalNotificationDateInterpretation.absoluteTime,
  //       androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  //     );
  //   }
  // }
  void _scheduleNotifications(List<Map<String, String>> planData) {
    print(planData);
    for (int i = 0; i < planData.length; i++) {
      final reminder = planData[i];
      tz.TZDateTime? scheduledTime;

      try {
        // Parse the original time
        DateTime parsedTime = DateTime.parse(reminder['time']!);

        // Create schedule for tomorrow if today's time has passed
        DateTime now = DateTime.now().toUtc();
        if (now.isAfter(parsedTime)) {
          // Keep same hours and minutes, just move to tomorrow
          parsedTime = DateTime.utc(
            now.year,
            now.month,
            now.day + 1,
            parsedTime.hour,
            parsedTime.minute,
          );
        }

        // Convert to TZDateTime while preserving the exact time
        scheduledTime = tz.TZDateTime.utc(
          parsedTime.year,
          parsedTime.month,
          parsedTime.day,
          parsedTime.hour,
          parsedTime.minute,
        );

        final notificationTitle = reminder['title'] ?? 'Drink Water Reminder';
        final notificationBody = reminder['body'] ?? 'It\'s time to drink water!';

        final AndroidNotificationDetails androidPlatformChannelSpecifics =
        const AndroidNotificationDetails(
          'water_reminder_channel',
          'Water Reminders',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'DRINK_ACTION',
              'Drink',
              showsUserInterface: false,
              cancelNotification: false,
            ),
            AndroidNotificationAction(
              'SNOOZE_ACTION',
              'Snooze',
              showsUserInterface: false,
              cancelNotification: false,
            ),
          ],
          playSound: true,
          enableLights: true,
          enableVibration: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
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

        print('Scheduled notification for: ${scheduledTime.toString()}');

      } catch (e) {
        print('Error scheduling notification: ${reminder['time']}, error: $e');
        continue;
      }
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
