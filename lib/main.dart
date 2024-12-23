import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' as drift;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:waterreminder/reminderTimemanager.dart';
import 'db/drift_db.dart' as drift;


import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' as drift;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:waterreminder/reminderTimemanager.dart';
import 'db/drift_db.dart' as drift;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' as drift;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:waterreminder/reminderTimemanager.dart';
import 'db/drift_db.dart' as drift;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  checkAndRequestPermissions();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); // Set the default location if needed
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
      '/reminderDetails': (context) => ReminderDetailsScreen(id: 0, database: database),
      '/signUp': (context) => SignUpScreen(database: database),
      '/signIn': (context) => SignInScreen(database: database),
      '/onboarding': (context) => OnboardingScreen(database: database),
      '/fetchUserDetails': (context) => FetchUserDetailsScreen(database: database),
    },
    onGenerateRoute: (settings) {
      if (settings.name != null && settings.name!.startsWith('/reminderDetails/')) {
        final id = int.tryParse(settings.name!.split('/').last);
        if (id != null) {
          return MaterialPageRoute(
            builder: (context) => ReminderDetailsScreen(id: id, database: database),
          );
        }
      }
      return MaterialPageRoute(builder: (context) => HomeScreen(database: database));
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
class HomeScreen extends StatefulWidget {
  final drift.AppDatabase database;

  const HomeScreen({super.key, required this.database});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentDayWaterIntake = 0;
  int _dailyWaterIntakeGoal = 2000;
  List<Map<String, dynamic>> _waterIntakePlan = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    print('Loading user details...');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        print('Found user document in Firestore');
        if (mounted) {
          setState(() {
            _dailyWaterIntakeGoal = userDoc.data()?['waterIntake'] ?? 2000;

            final planData = List<Map<String, dynamic>>.from(userDoc.data()?['plan'] ?? []);
            _waterIntakePlan = planData.map((reminder) {
              return {
                'id': reminder['id'],
                'time': reminder['time'],
                'title': reminder['title'],
                'body': reminder['body'],
              };
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToReminderDetails(int reminderId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReminderDetailsScreen(
          id: reminderId,
          database: widget.database,
        ),
      ),
    );

    // Refresh the list if changes were made (result is true)
    if (result == true) {
      await _loadUserDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = _currentDayWaterIntake / _dailyWaterIntakeGoal;

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Home'), automaticallyImplyLeading: false),
      body: RefreshIndicator(
        onRefresh: _loadUserDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Day Water Intake:', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text('${_currentDayWaterIntake} ml / ${_dailyWaterIntakeGoal} ml'),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 32),
                const Text('Water Intake Plan:', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                if (_waterIntakePlan.isEmpty)
                  const Text('No reminders set yet. Please complete the onboarding process.')
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _waterIntakePlan.length,
                    itemBuilder: (context, index) {
                      final reminder = _waterIntakePlan[index];
                      final time = TimeOfDay.fromDateTime(DateTime.parse(reminder['time']));
                      return ListTile(
                        title: Text(reminder['title'] ?? 'Drink Water Reminder'),
                        subtitle: Text(reminder['body'] ?? 'It\'s time to drink water!'),
                        trailing: Text(time.format(context)),
                        onTap: () {
                          final reminderId = reminder['id'];
                          if (reminderId != null) {
                            _navigateToReminderDetails(reminderId);
                          }
                        },
                      );
                    },
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  child: const Text('Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class FetchUserDetailsScreen extends StatelessWidget {
  final drift.AppDatabase database;

  const FetchUserDetailsScreen({super.key, required this.database});

  Future<void> _fetchAndStoreUserDetails(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();

      try {
        // Try to get user from Firestore first
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          // Store all user details in SharedPreferences
          await prefs.setString('userId', user.uid);
          await prefs.setBool('onboardingComplete', true);  // Add this flag

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

class SettingsScreen extends StatefulWidget {
  final drift.AppDatabase database;

  const SettingsScreen({super.key, required this.database});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _weightController = TextEditingController();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('name') ?? '';
    _ageController.text = prefs.getInt('age')?.toString() ?? '';
    _weightController.text = prefs.getInt('weight')?.toString() ?? '';
  }

  Future<void> _saveUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('name', _nameController.text);
    prefs.setInt('age', int.tryParse(_ageController.text) ?? 0);
    prefs.setInt('weight', int.tryParse(_weightController.text) ?? 0);

    // Update Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': _nameController.text,
        'age': int.tryParse(_ageController.text) ?? 0,
        'weight': int.tryParse(_weightController.text) ?? 0,
      });

      // Update local database
      final userId = await widget.database.insertUser(drift.UsersCompanion(
        name: drift.Value(_nameController.text),
        age: drift.Value(int.tryParse(_ageController.text) ?? 0),
        weight: drift.Value(int.tryParse(_weightController.text) ?? 0),
      ));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
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
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveUserDetails,
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
class ReminderDetailsScreen extends StatefulWidget {
  final int id;
  final drift.AppDatabase database;

  const ReminderDetailsScreen({super.key, required this.id, required this.database});

  @override
  State<ReminderDetailsScreen> createState() => _ReminderDetailsScreenState();
}

class _ReminderDetailsScreenState extends State<ReminderDetailsScreen> {
  late TimeOfDay _selectedTime;
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedTime = TimeOfDay.now();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _loadReminderDetails();
  }

  Future<void> _loadReminderDetails() async {
    try {
      final reminder = await widget.database.getReminderById(widget.id);

      if (reminder != null) {
        final reminderTime = DateTime.parse(reminder.time ?? '');
        setState(() {
          _selectedTime = TimeOfDay(hour: reminderTime.hour, minute: reminderTime.minute);
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
      final updatedReminderCompanion = drift.RemindersCompanion(
        time: drift.Value(formattedTime),
        title: drift.Value(_titleController.text),
        body: drift.Value(_bodyController.text),
      );

      await widget.database.updateReminderById(widget.id, updatedReminderCompanion);

      // Update Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final plan = List<Map<String, dynamic>>.from(userDoc.data()?['plan'] ?? []);
          final updatedPlan = plan.map((reminder) {
            if (reminder['id'] == widget.id) {
              return {
                'id': widget.id,
                'time': formattedTime,
                'title': _titleController.text,
                'body': _bodyController.text,
              };
            }
            return reminder;
          }).toList();

          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'plan': updatedPlan,
          });
        }

        // Reschedule notification
        await _scheduleNotification(widget.id, formattedTime, _titleController.text, _bodyController.text);

        if (mounted) {
          Navigator.pop(context, true); // Pass true to indicate update
        }
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

  Future<void> _scheduleNotification(int id, String time, String title, String body) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.cancel(id);

    final scheduledTime = DateTime.parse(time);
    final now = DateTime.now();
    var notificationTime = DateTime(now.year, now.month, now.day, scheduledTime.hour, scheduledTime.minute);

    if (notificationTime.isBefore(now)) {
      notificationTime = notificationTime.add(const Duration(days: 1));
    }

    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      enableLights: true,
      visibility: NotificationVisibility.public,

      showWhen: true,
      sound: RawResourceAndroidNotificationSound('sound'),
      enableVibration: true,
      actions: [
        AndroidNotificationAction('0', 'Snooze'),
        AndroidNotificationAction('1', 'Drank', cancelNotification: true),
      ],
    );
    final platformChannelSpecifics = const NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(notificationTime, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,

    );
  }

  @override
  Widget build(BuildContext context) {
    // Rest of the build method remains the same
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
class SignUpScreen extends StatefulWidget {
  final drift.AppDatabase database;

  const SignUpScreen({super.key, required this.database});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _phoneNumberController = TextEditingController();
  String? _verificationId;
  bool _isCodeSent = false;

  Future<void> _sendVerificationCode() async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${_phoneNumberController.text}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            _storeUserDetails();
            Navigator.pushReplacementNamed(context, '/onboarding');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            if (e.code == 'invalid-phone-number') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('The provided phone number is not valid.')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Verification failed: ${e.message}')),
              );
            }
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isCodeSent = true;
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending verification code: $e')),
        );
      }
    }
  }

  Future<void> _verifyCode(String smsCode) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        _storeUserDetails();
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid verification code')),
        );
      }
    }
  }

  Future<void> _storeUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('userId', user.uid);
      prefs.setString('phoneNumber', user.phoneNumber ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _phoneNumberController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isCodeSent ? null : _sendVerificationCode,
              child: const Text('Send Verification Code'),
            ),
            if (_isCodeSent)
              Column(
                children: [
                  const SizedBox(height: 20),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Verification Code'),
                    onChanged: (value) {
                      if (value.length == 6) {
                        _verifyCode(value);
                      }
                    },
                  ),
                ],
              ),
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/signIn'),
              child: const Text('Already have an account? Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}

class SignInScreen extends StatefulWidget {
  final drift.AppDatabase database;

  const SignInScreen({super.key, required this.database});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _phoneNumberController = TextEditingController();
  String? _verificationId;
  bool _isCodeSent = false;

  Future<void> _sendVerificationCode() async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${_phoneNumberController.text}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            _storeUserDetails();
            Navigator.pushReplacementNamed(context, '/home');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            if (e.code == 'invalid-phone-number') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('The provided phone number is not valid.')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Verification failed: ${e.message}')),
              );
            }
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isCodeSent = true;
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending verification code: $e')),
        );
      }
    }
  }

  Future<void> _verifyCode(String smsCode) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        _storeUserDetails();
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid verification code')),
        );
      }
    }
  }

  Future<void> _storeUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('userId', user.uid);
      prefs.setString('phoneNumber', user.phoneNumber ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _phoneNumberController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isCodeSent ? null : _sendVerificationCode,
              child: const Text('Send Verification Code'),
            ),
            if (_isCodeSent)
              Column(
                children: [
                  const SizedBox(height: 20),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Verification Code'),
                    onChanged: (value) {
                      if (value.length == 6) {
                        _verifyCode(value);
                      }
                    },
                  ),
                ],
              ),
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/signUp'),
              child: const Text("Don't have an account? Sign Up"),
            ),
          ],
        ),
      ),
    );
  }
}
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
  TimeOfDay _startTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 22, minute: 0);

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  late tz.Location _localTimeZone;

  @override
  void initState() {
    super.initState();
    auth = FirebaseAuth.instance;
    _initializeNotifications();
    tz.initializeTimeZones();
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
    const InitializationSettings initializationSettings = InitializationSettings(
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
      prefs.setInt('age', int.parse(_ageController.text));
      prefs.setInt('weight', int.parse(_weightController.text));
      prefs.setInt('waterIntake', int.parse(_waterIntakeController.text));
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
        final reminderId = await widget.database.insertReminder(reminderCompanion);
        final reminder = await widget.database.getReminderById(reminderId);
        if (reminder != null) {
          localReminders.add(reminder);
        }
      }

      // Create two versions of planData: one for Firestore (can handle various types)
      // and one for SharedPreferences/notifications (needs strings)
      final firestorePlanData = localReminders.map((drift.Reminder reminder) => {
        'id': reminder.id,
        'time': reminder.time,
        'title': reminder.title,
        'body': reminder.body,
      }).toList();

      final stringPlanData = localReminders.map((drift.Reminder reminder) => {
        'id': reminder.id.toString(),
        'time': reminder.time,
        'title': reminder.title,
        'body': reminder.body,
      }).toList();

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
      prefs.setStringList('plan', stringPlanData.map((reminder) => jsonEncode(reminder)).toList());

      // Cancel existing notifications
      await flutterLocalNotificationsPlugin.cancelAll();

      // Schedule new notifications using the string version of planData
      _scheduleNotifications(stringPlanData);
      prefs.setBool('onboardingComplete', true);  // A
      // Navigate to home screen
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
  void _scheduleNotifications(List<Map<String, String?>> planData) {
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

      final notificationTitle = reminder['title']!;
      final notificationBody = reminder['body']!;

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
              decoration: const InputDecoration(labelText: 'Daily Water Intake (ml)'),
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