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
      switch (response.actionId) {
        case ACTION_DRINK:
          print("Processing drink action");
          // trigger using waterIntakeController to update water intake

          UserService().updateDailyWaterIntake();
          break;
        case ACTION_SNOOZE:
          if(response.payload==null || response.payload!.isEmpty) {
            var p = json.decode(response.payload!);
            var reminderId = int.parse(p['reminderId'].toString());
            print("Notification snnozed with ID: $reminderId");
            print(reminderId);
            MyNotificationService().snoozeNotification(reminderId);

          }
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
  Future<void> snoozeNotification(int id) async {
    _flutterLocalNotificationsPlugin.cancel(id);
    final scheduledTime = DateTime.now().add(const Duration(minutes: 15));
    final zonedScheduleTime = tz.TZDateTime.from(scheduledTime, tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      CHANNEL_ID,
      CHANNEL_NAME,
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'DRINK_ACTION',
          'Drink',
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

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Drink Water Reminder (Snoozed)',
      'Please don\'t skip drinking water reminder',
      zonedScheduleTime,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: json.encode({
        'reminderId': id,
        'time': zonedScheduleTime.toIso8601String(),
      }),
    );
  }
}