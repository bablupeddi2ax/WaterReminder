import 'dart:convert';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:waterreminder/services/user_service.dart';

class MyNotificationService {
  static const CHANNEL_ID = "WATER_REMINDER";
  static const CHANNEL_NAME = "REMINDER_CHANNEL";
  static const ACTION_DRINK = "DRINK_ACTION";
  static const ACTION_SNOOZE = "SNOOZE_ACTION";

  MyNotificationService._internal();
  static final MyNotificationService _instance = MyNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  factory MyNotificationService() {
    return _instance;
  }

  FlutterLocalNotificationsPlugin getPlugin(){
    return _flutterLocalNotificationsPlugin;
  }
  Future<void> initialize() async {
    initializeTimeZones();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: true,
      ),
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      const AndroidNotificationChannel(
        CHANNEL_ID,
        CHANNEL_NAME,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('sound'),
        enableVibration: true,
        enableLights: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      // Handle notification tap based on action
      switch (response.actionId) {
        case ACTION_DRINK:
        // Handle drink action
          UserService().updateDailyWaterIntake();
          break;
        case ACTION_SNOOZE:
        // Handle snooze action

          break;
      }
    }
  }
  Future<void> checkPendingNotifications() async {
    final List<PendingNotificationRequest> pendingNotifications =
    await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    print('Pending notifications: ${pendingNotifications.length}');
    for (var notification in pendingNotifications) {
      print('ID: ${notification.id}, Title: ${notification.title}');
    }
  }
  Future<void> scheduleNotification(List<Map<String, dynamic>> planData) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        CHANNEL_ID,
        CHANNEL_NAME,
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

    // Cancel existing notifications once, not in loop
    await _flutterLocalNotificationsPlugin.cancelAll();

    for (final plan in planData) {
      try {
        final time = tz.TZDateTime.parse(tz.local, plan['time'] as String);

        await _flutterLocalNotificationsPlugin.zonedSchedule(
          int.parse(plan['id']),
          plan['title'] as String,
          plan['body'] as String,
          time,
          notificationDetails,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: json.encode({
            'reminderId': plan['id'],
            'time': time.toIso8601String(),
          }),
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        print('Failed to schedule notification: $e');
        // Add proper error handling here
      }
    }
  }
  Future<void> snoozeNotification() async{
    // jusr schedule a temporary noification with the same configuration it can als
  }
}