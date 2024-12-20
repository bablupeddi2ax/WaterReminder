import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' as drift;
import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'db/drift_db.dart' as drift;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool userDetailsExist = prefs.getString('userId') != null;

  final database = drift.AppDatabase();

  runApp(MaterialApp(
    title: "Water Reminder",
    initialRoute: userDetailsExist ? '/fetchUserDetails' : '/signUp',
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
class HomeScreen extends StatefulWidget {
  final drift.AppDatabase database;

  const HomeScreen({super.key, required this.database});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentDayWaterIntake = 0;
  int _dailyWaterIntakeGoal = 2000; // 2 liters
  List<String> _waterIntakePlan = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _dailyWaterIntakeGoal = userDoc.data()?['waterIntake'] ?? 2000;
          _waterIntakePlan = List<String>.from(userDoc.data()?['plan'] ?? []);
        });

        // Store in SharedPreferences
        prefs.setInt('waterIntake', _dailyWaterIntakeGoal);
        prefs.setStringList('plan', _waterIntakePlan);
      }
    }

    _currentDayWaterIntake = prefs.getInt('currentDayWaterIntake') ?? 0;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    double progress = _currentDayWaterIntake / _dailyWaterIntakeGoal;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Padding(
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
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 32),
            const Text('Water Intake Plan:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            if (_waterIntakePlan.isEmpty)
              const Text('No reminders set yet. Please complete the onboarding process.'),
            ..._waterIntakePlan.map((time) => ListTile(
              title: Text(time),
              onTap: () {
                final id = _waterIntakePlan.indexOf(time);
                Navigator.pushNamed(context, '/reminderDetails/$id');
              },
            )),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              child: const Text('Settings'),
            ),
          ],
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
      print("user is not null");
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        print("userdoc is not null");
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('userId', user.uid);
        prefs.setString('name', userDoc.data()?['name'] ?? '');
        prefs.setInt('age', userDoc.data()?['age'] ?? 0);
        prefs.setInt('weight', userDoc.data()?['weight'] ?? 0);
        prefs.setInt('waterIntake', userDoc.data()?['waterIntake'] ?? 2000);
        prefs.setString('startTime', userDoc.data()?['startTime'] ?? '');
        prefs.setString('endTime', userDoc.data()?['endTime'] ?? '');
        prefs.setStringList('plan', List<String>.from(userDoc.data()?['plan'] ?? []));

        // Store in local database
        final userId = await database.insertUser(drift.UsersCompanion(
          name: drift.Value(userDoc.data()?['name'] ?? ''),
          age: drift.Value(userDoc.data()?['age'] ?? 0),
          weight: drift.Value(userDoc.data()?['weight'] ?? 0),
          waterIntake: drift.Value(userDoc.data()?['waterIntake'] ?? 2000),
          startTime: drift.Value(userDoc.data()?['startTime'] ?? ''),
          endTime: drift.Value(userDoc.data()?['endTime'] ?? ''),
        ));
        print("local db done");

        // Fixed: Properly convert the plan data to RemindersCompanion list
        final List<dynamic> planData = userDoc.data()?['plan'] ?? [];
        final List<drift.RemindersCompanion> reminders = planData
            .map((time) => drift.RemindersCompanion(
          userId: drift.Value(userId),
          time: drift.Value(time.toString()),
        ))
            .toList();

        await database.updateRemindersByUserId(userId, reminders);
        print("local reminder updating done");

        // Cancel existing notifications
        final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
        await flutterLocalNotificationsPlugin.cancelAll();
        print("notification cancel done");

        // Schedule new notifications
        final List<String> plan = List<String>.from(userDoc.data()?['plan'] ?? []);
        _scheduleNotifications(plan, database);
        print("new notifications done");

        // Navigate to home screen
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Handle case where user document does not exist
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    }
  }

  void _scheduleNotifications(List<String> plan, drift.AppDatabase database) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    for (int i = 0; i < plan.length; i++) {
      final scheduledTime = tz.TZDateTime.parse(tz.local, plan[i]);
      final notificationTitle = 'Drink Water Reminder';
      final notificationBody = 'It\'s time to drink water!';

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

      await flutterLocalNotificationsPlugin.zonedSchedule(
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
    _fetchAndStoreUserDetails(context);
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
  late TextEditingController _timeController;

  @override
  void initState() {
    super.initState();
    _timeController = TextEditingController();
    _loadReminderDetails();
  }

  Future<void> _loadReminderDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> plan = prefs.getStringList('plan') ?? [];
    if (widget.id < plan.length) {
      _timeController.text = plan[widget.id];
    }
  }

  Future<void> _saveReminderDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> plan = prefs.getStringList('plan') ?? [];
    if (widget.id < plan.length) {
      plan[widget.id] = _timeController.text;
      prefs.setStringList('plan', plan);

      // Update Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'plan': plan,
        });

        // Update local database
        final reminders = plan.map((time) =>drift.RemindersCompanion(
          userId: drift.Value(widget.id),
          time: drift.Value(time),
        )).toList();

        await widget.database.updateRemindersByUserId(widget.id, reminders);
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Reminder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _timeController,
              readOnly: true,
              onTap: () async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(
                    DateTime.parse(_timeController.text),
                  ),
                );
                if (pickedTime != null) {
                  final formattedTime = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                  _timeController.text = formattedTime;
                }
              },
              decoration: const InputDecoration(labelText: 'Time'),
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
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91${_phoneNumberController.text}',
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        _storeUserDetails();
        Navigator.pushReplacementNamed(context, '/onboarding');
      },
      verificationFailed: (FirebaseAuthException e) {
        if (e.code == 'invalid-phone-number') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('The provided phone number is not valid.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isCodeSent = true;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        setState(() {
          _verificationId = verificationId;
        });
      },
    );
  }

  Future<void> _verifyCode(String smsCode) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      _storeUserDetails();
      Navigator.pushReplacementNamed(context, '/onboarding');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid verification code')),
      );
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
      appBar: AppBar(title: const Text('Sign Up')),
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
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91${_phoneNumberController.text}',
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        _storeUserDetails();
        Navigator.pushReplacementNamed(context, '/home');
      },
      verificationFailed: (FirebaseAuthException e) {
        if (e.code == 'invalid-phone-number') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('The provided phone number is not valid.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isCodeSent = true;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        setState(() {
          _verificationId = verificationId;
        });
      },
    );
  }

  Future<void> _verifyCode(String smsCode) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      _storeUserDetails();
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid verification code')),
      );
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
              child: const Text('Don\'t have an account? Sign Up'),
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
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();

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

      // Generate and store the water intake plan
      final plan = _generateWaterIntakePlan(
        int.parse(_waterIntakeController.text),
        _formatTimeOfDay(_startTime),
        _formatTimeOfDay(_endTime),
      );

      // Store in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text,
        'age': int.parse(_ageController.text),
        'weight': int.parse(_weightController.text),
        'waterIntake': int.parse(_waterIntakeController.text),
        'startTime': _formatTimeOfDay(_startTime),
        'endTime': _formatTimeOfDay(_endTime),
        'plan': plan.map((time) => time.toString()).toList(),
      });

      // Store in local database
      final userId = await widget.database.insertUser(drift.UsersCompanion(
        name: drift.Value(_nameController.text),
        age: drift.Value(int.parse(_ageController.text)),
        weight: drift.Value(int.parse(_weightController.text)),
        waterIntake: drift.Value(int.parse(_waterIntakeController.text)),
        startTime: drift.Value(_formatTimeOfDay(_startTime)),
        endTime: drift.Value(_formatTimeOfDay(_endTime)),
      ));

      final reminders = plan.map((time) => drift.RemindersCompanion(
        userId: drift.Value(userId),
        time: drift.Value(time.toString()),
      )).toList();

      await widget.database.updateRemindersByUserId(userId, reminders);

      // Store in SharedPreferences
      prefs.setStringList('plan', plan.map((time) => time.toString()).toList());

      // Cancel existing notifications
      await flutterLocalNotificationsPlugin.cancelAll();

      // Schedule new notifications
      _scheduleNotifications(plan);

      // Navigate to home screen
      Navigator.pushReplacementNamed(context, '/home');
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
    final now = tz.TZDateTime.now(_localTimeZone);

    for (int i = 0; i < 8; i++) {
      // Calculate target time for this reminder
      final reminderMinutes = startMinutes + (i * intervalMinutes).round();
      var targetHour = (reminderMinutes ~/ 60) % 24;
      final targetMinute = reminderMinutes % 60;

      // Create notification datetime
      var scheduledDate = tz.TZDateTime(
        _localTimeZone,
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

  void _scheduleNotifications(List<tz.TZDateTime> plan) {
    for (int i = 0; i < plan.length; i++) {
      final scheduledTime = plan[i];
      final notificationTitle = 'Drink Water Reminder';
      final notificationBody = 'It\'s time to drink water!';

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

      flutterLocalNotificationsPlugin.zonedSchedule(
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