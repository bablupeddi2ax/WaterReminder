import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:waterreminder/AppConstants.dart';
import 'package:waterreminder/services/database_service.dart';
import 'package:waterreminder/services/notification_service.dart';
import 'package:waterreminder/services/user_service.dart';
import 'package:waterreminder/ui/home.dart';
import 'package:waterreminder/ui/reminder_details.dart';
import 'package:waterreminder/ui/settings.dart';
import 'db/drift_db.dart' as drift;
import 'ui/onboarding.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
final StreamController<bool> _waterIntakeUpdateController = StreamController<bool>.broadcast();
Stream<bool> get waterIntakeUpdateStream => _waterIntakeUpdateController.stream;
void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    print("WidgetsFlutterBinding.ensureInitialized()");
  }
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await Firebase.initializeApp();
  if (kDebugMode) {
    print(Firebase.apps);
  }
  initializeNotifications();
  checkAndRequestPermissions();
  tz.initializeTimeZones();
  bool userDetailsExist = prefs.getString('name') != null;
  bool onboardingComplete = prefs.getBool('onboardingComplete') ?? false;
  //String? name = prefs.getString('name');
  await DatabaseService().initialize();
  final database = DatabaseService().database;
  String initialRoute;
  if (userDetailsExist) {
    if (onboardingComplete) {
      initialRoute = '/home';
    } else {
      initialRoute = '/welcome';
    }
  }
  else {
    initialRoute = '/welcome';
  }
  MyNotificationService().initialize();
  UserService().init(_waterIntakeUpdateController);
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
        '/home': (context) => HomeScreen(database: database,controller: _waterIntakeUpdateController),
        '/settings': (context) => SettingsScreen(database: database),
        '/reminderDetails': (context) => ReminderDetailsScreen(id: 0, database: database),
        '/welcome': (context) => WelcomeScreen(database: database),
        '/onBoarding': (context) => OnboardingScreen(database: database),
      },
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
        return null;
      },
    );
  }
}
Future<void> checkAndRequestPermissions() async {
  try {
    final androidPlugin = AndroidFlutterLocalNotificationsPlugin();
    await androidPlugin.requestNotificationsPermission();
    await androidPlugin.requestExactAlarmsPermission();
  } catch (e) {
    print('Error requesting permissions: $e');
  }
}
Future<void> updateWaterIntake(int amount) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final currentIntake = prefs.getInt('water_intake_$today') ?? 0;
    final newIntake = currentIntake + amount;
    await prefs.setInt('water_intake_$today', newIntake);
    print('Updated water intake in SharedPreferences: $newIntake ml');
    _waterIntakeUpdateController.add(true);
    print('Notified listeners of water intake update');
  } catch (e) {
    print('Error updating water intake: $e');
  }
}
Future<void> snoozeNotification(int id) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin.cancel(id);
  print('Cancelled notification with ID: $id');
  final scheduledTime = DateTime.now().add(const Duration(minutes: 15));
  final zonedScheduleTime = tz.TZDateTime.from(scheduledTime, tz.local);
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
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
  const NotificationDetails(android: androidPlatformChannelSpecifics);
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
      AppConstants.notificationPayloadReminderId: id.toString(),
      AppConstants.notificationPayloadReminderTime: zonedScheduleTime.toIso8601String(),
    }),
  );
  print('Scheduled snooze notification for: ${zonedScheduleTime.toString()}');
}
Future<void> initializeNotifications() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
    AppConstants.waterReminderChannelId,
    AppConstants.waterReminderChannelName,
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
    enableLights: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    sound: RawResourceAndroidNotificationSound('sound.mp3'),
    showBadge: true,
  ));
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      print("Notification response received");
      print("Action ID: ${response.actionId}");
      print("Payload: ${response.payload}");
      if (response.payload == null || response.payload!.isEmpty) {
        print("Error: Empty payload received");
        return;
      }
      try {
        final payload = json.decode(response.payload!) as Map<String, dynamic>;
        print("Decoded payload: $payload");
        switch (response.actionId) {
          case 'DRINK_ACTION':
            print("Processing drink action");
            // POTENTIAL ISSUE: Hard-coded water intake amount (250ml)
            print(response.notificationResponseType);
            print(response.payload);
            print("response null or not");
            print(response.payload==null);
            await UserService().updateDailyWaterIntake();

            if (response.payload != null) {
              try {
                final payload = json.decode(response.payload!) as Map<String, dynamic>;
                final reminderId = int.parse(payload['reminderId'].toString());
                print("reminderId$reminderId");
                print(payload.toString());
                //await MyNotificationService().initialize();
                print("after initialize");
                await MyNotificationService().getPlugin().cancel(reminderId);
                print("after cancel");
                print('Cancelled notification with ID: $reminderId');
              } catch (e) {
                print('Error cancelling notification: $e');
              }
            }
            break;
          case 'SNOOZE_ACTION':
            print("Processing snooze action");
            if (payload['reminderId'] != null) {
              final int reminderId = int.parse(payload['reminderId'].toString());
              await MyNotificationService().getPlugin().cancel(reminderId);
              print("payload not null");
              print("Cancelled notification with ID: $reminderId");

              await MyNotificationService().snoozeNotification(reminderId);
              print("after snooze");

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