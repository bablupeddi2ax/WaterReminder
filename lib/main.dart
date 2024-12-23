import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:waterreminder/ui/fecth_user_details.dart';
import 'package:waterreminder/ui/home.dart';
import 'package:waterreminder/ui/reminder_details.dart';
import 'package:waterreminder/ui/settings.dart';
import 'package:waterreminder/ui/signin.dart';
import 'package:waterreminder/ui/signup.dart';
import 'db/drift_db.dart' as drift;
import 'ui/onboarding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  checkAndRequestPermissions();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  tz.initializeTimeZones();
  tz.setLocalLocation(
      tz.getLocation('Asia/Kolkata')); // Set the default location if needed
  bool userDetailsExist = prefs.getString('userId') != null;
  bool onboardingComplete = prefs.getBool('onboardingComplete') ?? false;

  final database = drift.AppDatabase();
  String initialRoute = userDetailsExist
      ? (onboardingComplete ? '/home' : '/onboarding')
      : '/signUp';

  runApp(MaterialApp(
    title: "Water Reminder",
    initialRoute: initialRoute,
    routes: {
      '/': (context) => HomeScreen(database: database),
      '/home': (context) => HomeScreen(database: database),
      '/settings': (context) => SettingsScreen(database: database),
      '/reminderDetails': (context) =>
          ReminderDetailsScreen(id: 0, database: database),
      '/signUp': (context) => SignUpScreen(database: database),
      '/signIn': (context) => SignInScreen(database: database),
      '/onboarding': (context) => OnboardingScreen(database: database),
      '/fetchUserDetails': (context) =>
          FetchUserDetailsScreen(database: database),
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
      return MaterialPageRoute(
          builder: (context) => HomeScreen(database: database));
    },
  ));
}

Future<void> checkAndRequestPermissions() async {
  try {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification,
      Permission.scheduleExactAlarm,
    ].request();

    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        // Handle each permission denial appropriately
      }
    });
  } catch (e) {
    print('Error requesting permissions: $e');
  }
}
//newer
