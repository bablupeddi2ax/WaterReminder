// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:drift/drift.dart' as drift;
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:waterreminder/services/notification_service.dart';
//
// import '../db/drift_db.dart';
//
// class ReminderDetailsScreen extends StatefulWidget {
//   final int id;
//   final AppDatabase database;
//   const ReminderDetailsScreen(
//       {super.key, required this.id, required this.database});
//
//   @override
//   State<ReminderDetailsScreen> createState() => _ReminderDetailsScreenState();
// }
//
// class _ReminderDetailsScreenState extends State<ReminderDetailsScreen> {
//   late TimeOfDay _selectedTime;
//   late TextEditingController _titleController;
//   late TextEditingController _bodyController;
//   bool _isLoading = true;
//   late MyNotificationService myNotificationService;
//
//   @override
//   void initState() {
//     super.initState();
//     myNotificationService = MyNotificationService();
//     myNotificationService.initialize();
//
//     _selectedTime = TimeOfDay.now();
//     _titleController = TextEditingController();
//     _bodyController = TextEditingController();
//     _loadReminderDetails();
//   }
//
//   Future<void> _loadReminderDetails() async {
//     try {
//       print(widget.id);
//       final reminder = await widget.database.getReminderById(widget.id);
//       print(reminder==null?"reminder is null":"reminder is not null ");
//       if (reminder != null) {
//         print("reminder in reminder_details screen ");
//         print(reminder);
//         final reminderTime = DateTime.parse(reminder.time ?? '');
//         setState(() {
//           _selectedTime =
//               TimeOfDay(hour: reminderTime.hour, minute: reminderTime.minute);
//           _titleController.text = reminder.title ?? 'Drink Water Reminder';
//           _bodyController.text = reminder.body ?? 'It\'s time to drink water!';
//           _isLoading = false;
//         });
//       } else {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       print('Error loading reminder details: $e');
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   Future<void> _saveReminderDetails() async {
//     try {
//       // Create DateTime without changing the date
//       final now = DateTime.now();
//       final reminderDateTime = DateTime(
//         now.year,
//         now.month,
//         now.day,
//         _selectedTime.hour,
//         _selectedTime.minute,
//       );
//
//       final formattedTime = reminderDateTime.toIso8601String();
//
//       // Update reminder in Drift database
//       final updatedReminderCompanion = RemindersCompanion(
//         time: drift.Value(formattedTime),
//         title: drift.Value(_titleController.text),
//         body: drift.Value(_bodyController.text),
//       );
//
//       await widget.database
//           .updateReminderById(widget.id, updatedReminderCompanion);
//
//       // Update Firestore
//      // final user = FirebaseAuth.instance.currentUser;
//      // if (user != null) {
//      //    final userDoc = await FirebaseFirestore.instance
//      //        .collection('users')
//      //        .doc(user.uid)
//      //        .get();
//      //    if (userDoc.exists) {
//      //      final plan =
//      //          List<Map<String, dynamic>>.from(userDoc.data()?['plan'] ?? []);
//      //      final updatedPlan = plan.map((reminder) {
//      //        if (reminder['id'] == widget.id) {
//      //          return {
//      //            'id': widget.id,
//      //            'time': formattedTime,
//      //            'title': _titleController.text,
//      //            'body': _bodyController.text,
//      //          };
//      //        }
//      //        return reminder;
//      //      }).toList();
//
//           // await FirebaseFirestore.instance
//           //     .collection('users')
//           //     .doc(user.uid)
//           //     .update({
//           //   'plan': updatedPlan,
//           // });
//         //}
//
//         // Reschedule notification
//         await _scheduleNotification(widget.id, formattedTime,
//             _titleController.text, _bodyController.text);
//
//         if (mounted) {
//           Navigator.pop(context, true); // Pass true to indicate update
//         }
//       }
//     catch (e) {
//       print('Error saving reminder details: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to save reminder: $e')),
//         );
//       }
//     }
//   }
//
//   Future<void> _scheduleNotification(
//       int id, String time, String title, String body) async {
//     await myNotificationService.getPlugin().cancel(id);
//     //await flutterLocalNotificationsPlugin.cancel(id);
//
//     final scheduledTime = DateTime.parse(time);
//     final now = DateTime.now();
//     var notificationTime = DateTime(
//         now.year, now.month, now.day, scheduledTime.hour, scheduledTime.minute);
//
//     if (notificationTime.isBefore(now)) {
//       notificationTime = notificationTime.add(const Duration(days: 1));
//     }
//
//     // const androidPlatformChannelSpecifics = AndroidNotificationDetails(
//     //   'your_channel_id',
//     //   'your_channel_name',
//     //   importance: Importance.max,
//     //   priority: Priority.high,
//     //   fullScreenIntent: true,
//     //   enableLights: true,
//     //   visibility: NotificationVisibility.public,
//     //   showWhen: true,
//     //   sound: RawResourceAndroidNotificationSound('sound'),
//     //   enableVibration: true,
//     //   actions: [
//     //     AndroidNotificationAction('0', 'Snooze'),
//     //     AndroidNotificationAction('1', 'Drank', cancelNotification: true),
//     //   ],
//     // );
//     // final platformChannelSpecifics =
//     //     const NotificationDetails(android: androidPlatformChannelSpecifics);
//     var notificationDetails = const NotificationDetails(
//       android: AndroidNotificationDetails(
//         MyNotificationService.CHANNEL_ID,
//         MyNotificationService.CHANNEL_NAME,
//         importance: Importance.max,
//         priority: Priority.high,
//         playSound: true,
//         sound: RawResourceAndroidNotificationSound('sound'),
//         color: Color(0xFF0000FF),
//         enableLights: true,
//         enableVibration: true,
//         fullScreenIntent: true,
//         autoCancel: false,
//         visibility: NotificationVisibility.public,
//         actions: [
//           AndroidNotificationAction(
//             'DRINK_ACTION',
//             'Drink',
//             showsUserInterface: true,
//             cancelNotification: false,
//           ),
//           AndroidNotificationAction(
//             'SNOOZE_ACTION',
//             'Snooze',
//             showsUserInterface: true,
//             cancelNotification: false,
//           ),
//         ],
//         category: AndroidNotificationCategory.alarm,
//       ),
//     );
//     await myNotificationService.getPlugin().zonedSchedule(
//       id,
//       title,
//       body,
//       tz.TZDateTime.from(notificationTime, tz.local),
//       notificationDetails,
//       androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//       uiLocalNotificationDateInterpretation:
//           UILocalNotificationDateInterpretation.absoluteTime,
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Rest of the build method remains the same
//     if (_isLoading) {
//       return const Scaffold(
//         body: Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }
//
//     return Scaffold(
//       appBar: AppBar(title: const Text('Edit Reminder')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             TextField(
//               controller: _titleController,
//               decoration: const InputDecoration(labelText: 'Title'),
//             ),
//             const SizedBox(height: 16),
//             TextField(
//               controller: _bodyController,
//               decoration: const InputDecoration(labelText: 'Body'),
//             ),
//             const SizedBox(height: 16),
//             ListTile(
//               title: const Text('Reminder Time'),
//               subtitle: Text(
//                 _selectedTime.format(context),
//                 style: Theme.of(context).textTheme.titleLarge,
//               ),
//               trailing: const Icon(Icons.access_time),
//               onTap: () async {
//                 final TimeOfDay? pickedTime = await showTimePicker(
//                   context: context,
//                   initialTime: _selectedTime,
//                 );
//                 if (pickedTime != null) {
//                   setState(() {
//                     _selectedTime = pickedTime;
//                   });
//                 }
//               },
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _saveReminderDetails,
//               child: const Text('Save Changes'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:waterreminder/services/notification_service.dart';

import '../db/drift_db.dart';

class ReminderDetailsScreen extends StatefulWidget {
  final int id;
  final AppDatabase database;
  const ReminderDetailsScreen(
      {super.key, required this.id, required this.database});

  @override
  State<ReminderDetailsScreen> createState() => _ReminderDetailsScreenState();
}

class _ReminderDetailsScreenState extends State<ReminderDetailsScreen> {
  late TimeOfDay _selectedTime;
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  bool _isLoading = true;
  late MyNotificationService myNotificationService;

  @override
  void initState() {
    super.initState();
    myNotificationService = MyNotificationService();
    myNotificationService.initialize();

    _selectedTime = TimeOfDay.now();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _loadReminderDetails();
  }

  Future<void> _loadReminderDetails() async {
    try {
      print(widget.id);
      final reminder = await widget.database.getReminderById(widget.id);
      print(reminder == null ? "reminder is null" : "reminder is not null");
      if (reminder != null) {
        print("reminder in reminder_details screen");
        print(reminder);
        final reminderTime = DateTime.parse(reminder.time ?? '');
        setState(() {
          _selectedTime =
              TimeOfDay(hour: reminderTime.hour, minute: reminderTime.minute);
          _titleController.text = reminder.title ?? 'Drink Water Reminder';
          _bodyController.text = reminder.body ?? 'It\'s time to drink water!';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading reminder details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveReminderDetails() async {
    try {
      // Create DateTime without changing the date
      final now = DateTime.now();
      final reminderDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final formattedTime = reminderDateTime.toIso8601String();

      // Update reminder in Drift database
      final updatedReminderCompanion = RemindersCompanion(
        time: drift.Value(formattedTime),
        title: drift.Value(_titleController.text),
        body: drift.Value(_bodyController.text),
      );

      await widget.database
          .updateReminderById(widget.id, updatedReminderCompanion);

      // Commented out Firestore-related code to make the app offline-first
      // final user = FirebaseAuth.instance.currentUser;
      // if (user != null) {
      //   final userDoc = await FirebaseFirestore.instance
      //       .collection('users')
      //       .doc(user.uid)
      //       .get();
      //   if (userDoc.exists) {
      //     final plan =
      //         List<Map<String, dynamic>>.from(userDoc.data()?['plan'] ?? []);
      //     final updatedPlan = plan.map((reminder) {
      //       if (reminder['id'] == widget.id) {
      //         return {
      //           'id': widget.id,
      //           'time': formattedTime,
      //           'title': _titleController.text,
      //           'body': _bodyController.text,
      //         };
      //       }
      //       return reminder;
      //     }).toList();

      //     await FirebaseFirestore.instance
      //         .collection('users')
      //         .doc(user.uid)
      //         .update({
      //       'plan': updatedPlan,
      //     });
      //   }
      // }

      // Reschedule notification
      await _scheduleNotification(widget.id, formattedTime,
          _titleController.text, _bodyController.text);

      if (mounted) {
        Navigator.pop(context, true); // Pass true to indicate update
      }
    } catch (e) {
      print('Error saving reminder details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save reminder: $e')),
        );
      }
    }
  }

  Future<void> _scheduleNotification(
      int id, String time, String title, String body) async {
    await myNotificationService.getPlugin().cancel(id);

    final scheduledTime = DateTime.parse(time);
    final now = DateTime.now();
    var notificationTime = DateTime(
        now.year, now.month, now.day, scheduledTime.hour, scheduledTime.minute);

    if (notificationTime.isBefore(now)) {
      notificationTime = notificationTime.add(const Duration(days: 1));
    }

    var notificationDetails = const NotificationDetails(
      android: AndroidNotificationDetails(
        MyNotificationService.CHANNEL_ID,
        MyNotificationService.CHANNEL_NAME,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('sound'),
        color: Color(0xFF0000FF),
        enableLights: true,
        enableVibration: true,
        fullScreenIntent: true,
        autoCancel: false,
        visibility: NotificationVisibility.public,
        actions: [
          AndroidNotificationAction(
            'DRINK_ACTION',
            'Drink',
            showsUserInterface: true,
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            'SNOOZE_ACTION',
            'Snooze',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
        category: AndroidNotificationCategory.alarm,
      ),
    );
    await myNotificationService.getPlugin().zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(notificationTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Reminder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(labelText: 'Body'),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Reminder Time'),
              subtitle: Text(
                _selectedTime.format(context),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (pickedTime != null) {
                  setState(() {
                    _selectedTime = pickedTime;
                  });
                }
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveReminderDetails,
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}