  import 'dart:convert';

  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:drift/drift.dart' as drift;
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_local_notifications/flutter_local_notifications.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:timezone/data/latest_all.dart' as tz;
  import 'package:timezone/timezone.dart' as tz;
import 'package:waterreminder/services/notification_service.dart';
  import '../db/drift_db.dart' as drift;

  class OnboardingScreen extends StatefulWidget {
    final drift.AppDatabase database;

    const OnboardingScreen({super.key, required this.database});

    @override
    State<OnboardingScreen> createState() => _OnboardingScreenState();
  }

  class _OnboardingScreenState extends State<OnboardingScreen> {
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _ageController = TextEditingController();
    final TextEditingController _weightController = TextEditingController();
    final TextEditingController _waterIntakeController = TextEditingController();
    late FirebaseAuth auth;
    TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);

    late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
    late tz.Location _localTimeZone;

    @override
    void initState() {
      super.initState();
      tz.initializeTimeZones();
      _localTimeZone = tz.local;
      auth = FirebaseAuth.instance;
      _initializeNotifications();

      _localTimeZone = tz.local;

      // Initialize text controllers with default values
      _nameController.text = ''; // Name can be empty
      _ageController.text = '0'; // Default age
      _weightController.text = '0'; // Default weight
      _waterIntakeController.text = '2000'; // Default water intake
    }

    void _initializeNotifications() {
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );
      flutterLocalNotificationsPlugin.initialize(initializationSettings);
    }

    Future<void> _selectStartTime() async {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _startTime,
      );
      if (pickedTime != null && pickedTime != _startTime) {
        setState(() {
          _startTime = pickedTime;
        });
      }
    }

    Future<void> _selectEndTime() async {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _endTime,
      );
      if (pickedTime != null && pickedTime != _endTime) {
        setState(() {
          _endTime = pickedTime;
        });
      }
    }

    String _formatTimeOfDay(TimeOfDay time) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    Future<void> _storeUserDetails() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('userId', user.uid);
        prefs.setString('name', _nameController.text);
        prefs.setInt('age', int.tryParse(_ageController.text)??10);
        prefs.setInt('weight', int.tryParse(_weightController.text)??10);
        prefs.setInt('waterIntake', int.tryParse(_waterIntakeController.text)??2000);
        prefs.setString('startTime', _formatTimeOfDay(_startTime));
        prefs.setString('endTime', _formatTimeOfDay(_endTime));

        // Generate water intake plan times
        final plan = _generateWaterIntakePlan(
          int.parse(_waterIntakeController.text),
          _formatTimeOfDay(_startTime),
          _formatTimeOfDay(_endTime),
        );

        // First store user in local database
        await widget.database.insertUser(drift.UsersCompanion(
          id: drift.Value(user.uid),
          name: drift.Value(_nameController.text),
          age: drift.Value(int.parse(_ageController.text)),
          weight: drift.Value(int.parse(_weightController.text)),
          waterIntake: drift.Value(int.parse(_waterIntakeController.text)),
          startTime: drift.Value(_formatTimeOfDay(_startTime)),
          endTime: drift.Value(_formatTimeOfDay(_endTime)),
        ));

        // Store reminders in local database first to get IDs
        List<drift.Reminder> localReminders = [];
        for (var planTime in plan) {
          final reminderCompanion = drift.RemindersCompanion(
            userId: drift.Value(user.uid),
            time: drift.Value(planTime.toUtc().toIso8601String()),
            title: const drift.Value('Drink Water Reminder'),
            body: const drift.Value('It\'s time to drink water!'),
          );

          // Insert and get the auto-generated ID
          final reminderId =
              await widget.database.insertReminder(reminderCompanion);
          final reminder = await widget.database.getReminderById(reminderId);
          if (reminder != null) {
            localReminders.add(reminder);
          }
        }

        // Create two versions of planData: one for Firestore (can handle various types)
        // and one for SharedPreferences/notifications (needs strings)
        final firestorePlanData = localReminders
            .map((drift.Reminder reminder) => {
                  'id': reminder.id,
                  'time': reminder.time,
                  'title': reminder.title,
                  'body': reminder.body,
                })
            .toList();

        final stringPlanData = localReminders
            .map((drift.Reminder reminder) => {
                  'id': reminder.id.toString(),
                  'time': reminder.time,
                  'title': reminder.title,
                  'body': reminder.body,
                })
            .toList();

        // Store in Firestore with real IDs (can handle non-string types)
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _nameController.text,
          'age': int.parse(_ageController.text),
          'weight': int.parse(_weightController.text),
          'waterIntake': int.parse(_waterIntakeController.text),
          'startTime': _formatTimeOfDay(_startTime),
          'endTime': _formatTimeOfDay(_endTime),
          'plan': firestorePlanData,
        });

        // Store in SharedPreferences (needs strings)
        prefs.setStringList('plan',
            stringPlanData.map((reminder) => jsonEncode(reminder)).toList());

        // Cancel existing notifications
        await flutterLocalNotificationsPlugin.cancelAll();

        // Schedule new notifications using the string version of planData
        _scheduleNotifications(stringPlanData);
        prefs.setBool('onboardingComplete', true);

        // Navigate to home screen
        Navigator.pushReplacementNamed(context, '/home');
      }
    }

    void _scheduleNotifications(List<Map<String, String?>> planData) async{
     var myNotificationService = MyNotificationService();
     myNotificationService.initialize();
     myNotificationService.scheduleNotification(planData);

     myNotificationService.getPlugin().show(-1, 'test', 'body', const NotificationDetails(
       android: AndroidNotificationDetails(
         "WATER_REMINDER",
         "REMINDER_CHANNEL",
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
     ));
    }

    List<tz.TZDateTime> _generateWaterIntakePlan(
        int totalWaterIntake, String startTime, String endTime) {
      // Parse start and end times
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');

      final startHour = int.parse(startParts[0]);
      final startMinute = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);

      // Calculate time span in minutes
      final startMinutes = startHour * 60 + startMinute;
      final endMinutes = endHour * 60 + endMinute;
      final totalMinutes = endMinutes > startMinutes
          ? endMinutes - startMinutes
          : (24 * 60) - startMinutes + endMinutes;

      // Calculate interval between reminders (8 reminders per day)
      final intervalMinutes = totalMinutes / 8;

      List<tz.TZDateTime> plan = [];
      final now = tz.TZDateTime.now(tz.local);

      for (int i = 0; i < 8; i++) {
        // Calculate target time for this reminder
        final reminderMinutes = startMinutes + (i * intervalMinutes).round();
        var targetHour = (reminderMinutes ~/ 60) % 24;
        final targetMinute = reminderMinutes % 60;

        // Create notification datetime
        var scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          targetHour,
          targetMinute,
        );

        // If the time has already passed today, schedule for tomorrow
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        plan.add(scheduledDate);
      }
      print(plan.toList());
      print(plan);
      return plan;
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(title: const Text('Onboarding')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _waterIntakeController,
                decoration:
                    const InputDecoration(labelText: 'Daily Water Intake (ml)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(_formatTimeOfDay(_startTime)),
                trailing: const Icon(Icons.access_time),
                onTap: _selectStartTime,
              ),
              ListTile(
                title: const Text('End Time'),
                subtitle: Text(_formatTimeOfDay(_endTime)),
                trailing: const Icon(Icons.access_time),
                onTap: _selectEndTime,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _storeUserDetails,
                child: const Text('Complete Onboarding'),
              ),
            ],
          ),
        ),
      );
    }
  }
