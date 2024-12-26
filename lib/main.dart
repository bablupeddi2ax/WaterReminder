// Required imports for functionality
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:waterreminder/ui/fecth_user_details.dart';  // SUSPICIOUS: Typo in filename 'fecth' instead of 'fetch'
import 'package:waterreminder/ui/home.dart';
import 'package:waterreminder/ui/reminder_details.dart';
import 'package:waterreminder/ui/settings.dart';
import 'package:waterreminder/ui/signin.dart';
import 'package:waterreminder/ui/signup.dart';
import 'db/drift_db.dart' as drift;
import 'ui/onboarding.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Global stream controller for water intake updates
// POTENTIAL ISSUE: StreamController is never closed, could lead to memory leaks
final StreamController<bool> _waterIntakeUpdateController = StreamController<bool>.broadcast();
Stream<bool> get waterIntakeUpdateStream => _waterIntakeUpdateController.stream;

void main() async {
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    print("WidgetsFlutterBinding.ensureInitialized()");
  }
  await Firebase.initializeApp();
  if (kDebugMode) {
    print(Firebase.apps);
  }
  initializeNotifications();
  checkAndRequestPermissions();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  tz.initializeTimeZones();

  // Get user state
  bool userDetailsExist = prefs.getString('userId') != null;
  // SUSPICIOUS: Unused variable, might indicate missing functionality
  bool onboardingComplete = prefs.getBool('onboardingComplete') ?? false;
  String? name = prefs.getString('name');

  // Initialize database
  final database = drift.AppDatabase();

  // Determine initial route
  // POTENTIAL ISSUE: Logic might be simplified, current condition chain is complex
  String initialRoute = userDetailsExist
  // user details exist and user details like name is not null move to home
  //else if name is null move to fetchUserDetails to get user data
      ? (name!=null ? '/home' :'/fetchUserDetails')
  //if user details does not exist move to signup as in user was never signed in then show signup
      : '/signUp';

  // Main app initialization
  runApp(MyApp(database:database,initialRoute:initialRoute));
}
class MyApp extends StatelessWidget {
  final String initialRoute;
  final drift.AppDatabase database;

  const MyApp(  {super.key, required this.initialRoute,required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Water Reminder",
      initialRoute: initialRoute,
      routes: {
        '/home': (context) => HomeScreen(database: database),
        '/settings': (context) => SettingsScreen(database: database),
        // SUSPICIOUS: Hard-coded ID 0 might cause issues
        '/reminderDetails': (context) => ReminderDetailsScreen(id: 0, database: database),
        '/signUp': (context) => SignUpScreen(database: database),
        '/signIn': (context) => SignInScreen(database: database),
        '/onboarding': (context) => OnboardingScreen(database: database),
        '/fetchUserDetails': (context) => FetchUserDetailsScreen(database: database),
      },
      // Route generator for dynamic reminder details pages
      onGenerateRoute: (settings) {
        if (settings.name != null &&
            settings.name!.startsWith('/reminderDetails/')) {
          final id = int.tryParse(settings.name!.split('/').last);
          if (id != null) {
            return MaterialPageRoute(
              builder: (context) =>
                  ReminderDetailsScreen(id: id, database: database),
            );
          }
        }
        // POTENTIAL ISSUE: Default route might cause unexpected behavior
        return MaterialPageRoute(
            builder: (context) => HomeScreen(database: database));
      },
    );
  }
}

// Permission handling function
Future<void> checkAndRequestPermissions() async {
  try {
    final androidPlugin = AndroidFlutterLocalNotificationsPlugin();
    await androidPlugin.requestNotificationsPermission();
    await androidPlugin.requestExactAlarmsPermission();
  } catch (e) {
    // POTENTIAL ISSUE: Error is only printed, not handled properly
    print('Error requesting permissions: $e');
  }
}

// Function to update water intake in both local storage and Firestore
Future<void> updateWaterIntake(int amount) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Get and update local storage
    final currentIntake = prefs.getInt('water_intake_$today') ?? 0;
    final newIntake = currentIntake + amount;

    await prefs.setInt('water_intake_$today', newIntake);
    print('Updated water intake in SharedPreferences: $newIntake ml');

    // Update Firestore if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('water_intake')
          .doc(today)
          .set({
        'amount': newIntake,
        'date': today,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('Updated water intake in Firestore: $newIntake ml');
    }

    // Notify listeners
    _waterIntakeUpdateController.add(true);
    print('Notified listeners of water intake update');

  } catch (e) {
    // POTENTIAL ISSUE: Error handling could be more robust
    print('Error updating water intake: $e');
  }
}

// Function to handle notification snoozing
Future<void> snoozeNotification(int id) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Cancel existing notification
  await flutterLocalNotificationsPlugin.cancel(id);
  print('Cancelled notification with ID: $id');

  // Schedule new notification for 15 minutes later
  final scheduledTime = DateTime.now().add(const Duration(minutes: 15));
  final zonedScheduleTime = tz.TZDateTime.from(scheduledTime, tz.local);

  // Configure notification details
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
    playSound: true,
    enableLights: true,
    enableVibration: true,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
  );

  final NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);

  // Schedule notification
  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    'Drink Water Reminder',
    'It\'s time to drink water!',
    zonedScheduleTime,
    platformChannelSpecifics,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
    payload: json.encode({
      'reminderId': id.toString(),
      'time': zonedScheduleTime.toIso8601String(),
    }),
  );

  print('Scheduled snooze notification for: ${zonedScheduleTime.toString()}');
}

// Initialize notifications system
Future<void> initializeNotifications() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);
  // Configure notification channel
  // POTENTIAL ISSUE: sound.mp3 file existence not verified
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
    'water_reminder_channel',
    'Water Reminders',
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
    enableLights: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    sound: RawResourceAndroidNotificationSound('sound.mp3'),
    showBadge: true,
  ));

  // Initialize notification plugin with response handling
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      print("Notification response received");
      print("Action ID: ${response.actionId}");
      print("Payload: ${response.payload}");

      // Handle empty payload
      if (response.payload == null || response.payload!.isEmpty) {
        print("Error: Empty payload received");
        return;
      }

      try {
        final payload = json.decode(response.payload!) as Map<String, dynamic>;
        print("Decoded payload: $payload");

        // Handle different notification actions
        switch (response.actionId) {
          case 'DRINK_ACTION':
            print("Processing drink action");
            // POTENTIAL ISSUE: Hard-coded water intake amount (250ml)
            await updateWaterIntake(250);
            break;
          case 'SNOOZE_ACTION':
            print("Processing snooze action");
            if (payload['reminderId'] != null) {
              final int reminderId = int.parse(payload['reminderId'].toString());
              await snoozeNotification(reminderId);
            }
            break;
          default:
            print("No specific action ID matched");
            break;
        }
      } catch (e) {
        // POTENTIAL ISSUE: Error handling could be more robust
        print("Error processing notification response: $e");
      }
    },
  );
}