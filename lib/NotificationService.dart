

//older
// class HomeScreen extends StatefulWidget {
//   final drift.AppDatabase database;
//
//   const HomeScreen({super.key, required this.database});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   int _currentDayWaterIntake = 0;
//   int _dailyWaterIntakeGoal = 2000; // 2 liters
//   List<String> _waterIntakePlan = [];
//   bool _isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUserDetails();
//   }
//
//   Future<void> _loadUserDetails() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     final user = FirebaseAuth.instance.currentUser;
//
//     if (user != null) {
//       final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
//       if (userDoc.exists) {
//         setState(() {
//           _dailyWaterIntakeGoal = userDoc.data()?['waterIntake'] ?? 2000;
//           _waterIntakePlan = List<String>.from(userDoc.data()?['plan'] ?? []);
//         });
//
//         // Store in SharedPreferences
//         prefs.setInt('waterIntake', _dailyWaterIntakeGoal);
//         prefs.setStringList('plan', _waterIntakePlan);
//       }
//     }
//
//     _currentDayWaterIntake = prefs.getInt('currentDayWaterIntake') ?? 0;
//     setState(() {
//       _isLoading = false;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     double progress = _currentDayWaterIntake / _dailyWaterIntakeGoal;
//
//     if (_isLoading) {
//       return Scaffold(
//         body: Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }
//
//     return Scaffold(
//       appBar: AppBar(title: const Text('Home')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Current Day Water Intake:', style: TextStyle(fontSize: 18)),
//             const SizedBox(height: 8),
//             Text('${_currentDayWaterIntake} ml / ${_dailyWaterIntakeGoal} ml'),
//             const SizedBox(height: 16),
//             LinearProgressIndicator(
//               value: progress,
//               backgroundColor: Colors.grey[300],
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
//             ),
//             const SizedBox(height: 32),
//             const Text('Water Intake Plan:', style: TextStyle(fontSize: 18)),
//             const SizedBox(height: 8),
//             if (_waterIntakePlan.isEmpty)
//               const Text('No reminders set yet. Please complete the onboarding process.'),
//             ..._waterIntakePlan.map((time) => ListTile(
//               title: Text(time),
//               onTap: () {
//                 final id = _waterIntakePlan.indexOf(time);
//                 Navigator.pushNamed(context, '/reminderDetails/$id');
//               },
//             )),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () => Navigator.pushNamed(context, '/settings'),
//               child: const Text('Settings'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

//older
// class ReminderDetailsScreen extends StatefulWidget {
//   final int id;
//   final drift.AppDatabase database;
//
//   const ReminderDetailsScreen({super.key, required this.id, required this.database});
//
//   @override
//   State<ReminderDetailsScreen> createState() => _ReminderDetailsScreenState();
// }
//
// class _ReminderDetailsScreenState extends State<ReminderDetailsScreen> {
//   late TextEditingController _timeController;
//
//   @override
//   void initState() {
//     super.initState();
//     _timeController = TextEditingController();
//     _loadReminderDetails();
//   }
//
//   Future<void> _loadReminderDetails() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String> plan = prefs.getStringList('plan') ?? [];
//     if (widget.id < plan.length) {
//       _timeController.text = plan[widget.id];
//     }
//   }
//
//   Future<void> _saveReminderDetails() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String> plan = prefs.getStringList('plan') ?? [];
//     if (widget.id < plan.length) {
//       plan[widget.id] = _timeController.text;
//       prefs.setStringList('plan', plan);
//
//       // Update Firestore
//       final user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
//           'plan': plan,
//         });
//
//         // Update local database
//         final reminders = plan.map((time) =>drift.RemindersCompanion(
//           userId: drift.Value(widget.id),
//           time: drift.Value(time),
//         )).toList();
//
//         await widget.database.updateRemindersByUserId(widget.id, reminders);
//       }
//
//       Navigator.pop(context);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Edit Reminder')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             TextField(
//               controller: _timeController,
//               readOnly: true,
//               onTap: () async {
//                 final TimeOfDay? pickedTime = await showTimePicker(
//                   context: context,
//                   initialTime: TimeOfDay.fromDateTime(
//                     DateTime.parse(_timeController.text),
//                   ),
//                 );
//                 if (pickedTime != null) {
//                   final formattedTime = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
//                   _timeController.text = formattedTime;
//                 }
//               },
//               decoration: const InputDecoration(labelText: 'Time'),
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


//older
// class FetchUserDetailsScreen extends StatelessWidget {
//   final drift.AppDatabase database;
//
//   const FetchUserDetailsScreen({super.key, required this.database});
//
//   Future<void> _fetchAndStoreUserDetails(BuildContext context) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       print("user is not null");
//       final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
//
//       if (userDoc.exists) {
//         print("userdoc is not null");
//         final prefs = await SharedPreferences.getInstance();
//         prefs.setString('userId', user.uid);
//         prefs.setString('name', userDoc.data()?['name'] ?? '');
//         prefs.setInt('age', userDoc.data()?['age'] ?? 0);
//         prefs.setInt('weight', userDoc.data()?['weight'] ?? 0);
//         prefs.setInt('waterIntake', userDoc.data()?['waterIntake'] ?? 2000);
//         prefs.setString('startTime', userDoc.data()?['startTime'] ?? '');
//         prefs.setString('endTime', userDoc.data()?['endTime'] ?? '');
//         prefs.setStringList('plan', List<String>.from(userDoc.data()?['plan'] ?? []));
//
//         // Store in local database
//         final userId = await database.insertUser(drift.UsersCompanion(
//           name: drift.Value(userDoc.data()?['name'] ?? ''),
//           age: drift.Value(userDoc.data()?['age'] ?? 0),
//           weight: drift.Value(userDoc.data()?['weight'] ?? 0),
//           waterIntake: drift.Value(userDoc.data()?['waterIntake'] ?? 2000),
//           startTime: drift.Value(userDoc.data()?['startTime'] ?? ''),
//           endTime: drift.Value(userDoc.data()?['endTime'] ?? ''),
//         ));
//         print("local db done");
//
//         // Fixed: Properly convert the plan data to RemindersCompanion list
//         final List<dynamic> planData = userDoc.data()?['plan'] ?? [];
//         final List<drift.RemindersCompanion> reminders = planData
//             .map((time) => drift.RemindersCompanion(
//           userId: drift.Value(userId),
//           time: drift.Value(time.toString()),
//         ))
//             .toList();
//
//         await database.updateRemindersByUserId(userId, reminders);
//         print("local reminder updating done");
//
//         // Cancel existing notifications
//         final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//         await flutterLocalNotificationsPlugin.cancelAll();
//         print("notification cancel done");
//
//         // Schedule new notifications
//         final List<String> plan = List<String>.from(userDoc.data()?['plan'] ?? []);
//         _scheduleNotifications(plan, database);
//         print("new notifications done");
//
//         // Navigate to home screen
//         Navigator.pushReplacementNamed(context, '/home');
//       } else {
//         // Handle case where user document does not exist
//         Navigator.pushReplacementNamed(context, '/onboarding');
//       }
//     }
//   }
//
//   void _scheduleNotifications(List<String> plan, drift.AppDatabase database) async {
//     final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//     const AndroidInitializationSettings initializationSettingsAndroid =
//     AndroidInitializationSettings('@mipmap/ic_launcher');
//     const InitializationSettings initializationSettings = InitializationSettings(
//       android: initializationSettingsAndroid,
//     );
//     await flutterLocalNotificationsPlugin.initialize(initializationSettings);
//
//     for (int i = 0; i < plan.length; i++) {
//       final scheduledTime = tz.TZDateTime.parse(tz.local, plan[i]);
//       final notificationTitle = 'Drink Water Reminder';
//       final notificationBody = 'It\'s time to drink water!';
//
//       final AndroidNotificationDetails androidPlatformChannelSpecifics =
//       const AndroidNotificationDetails(
//         'your_channel_id',
//         'your_channel_name',
//         importance: Importance.max,
//         priority: Priority.high,
//         showWhen: true,
//       );
//       final NotificationDetails platformChannelSpecifics =
//       NotificationDetails(android: androidPlatformChannelSpecifics);
//
//       await flutterLocalNotificationsPlugin.zonedSchedule(
//         i,
//         notificationTitle,
//         notificationBody,
//         scheduledTime,
//         platformChannelSpecifics,
//         uiLocalNotificationDateInterpretation:
//         UILocalNotificationDateInterpretation.absoluteTime,
//         androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     _fetchAndStoreUserDetails(context);
//     return const Scaffold(
//       body: Center(
//         child: CircularProgressIndicator(),
//       ),
//     );
//   }
// }


//
// class Users extends Table {
//   IntColumn get id => integer().autoIncrement()();
//   TextColumn get name => text().nullable()();
//   IntColumn get age => integer().nullable()();
//   IntColumn get weight => integer().nullable()();
//   IntColumn get waterIntake => integer().nullable()();
//   TextColumn get startTime => text().nullable()();
//   TextColumn get endTime => text().nullable()();
// }
//
// class Reminders extends Table {
//   IntColumn get id => integer().autoIncrement()();
//   IntColumn get userId => integer().references(Users, #id)();
//   TextColumn get time => text().nullable()();
// }
//
// @DriftDatabase(tables: [Users, Reminders])
// class AppDatabase extends _$AppDatabase {
//   AppDatabase() : super(_openConnection());
//
//   @override
//   int get schemaVersion => 1;
//
//   Future<User?> getUserById(int id) => (select(users)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
//
//   Future<List<Reminder>> getRemindersByUserId(int userId) => (select(reminders)..where((tbl) => tbl.userId.equals(userId))).get();
//
//   Future<int> insertUser(UsersCompanion user) => into(users).insert(user);
//
//   Future<int> insertReminder(RemindersCompanion reminder) => into(reminders).insert(reminder);
//
//   Future<void> updateRemindersByUserId(int userId, List<RemindersCompanion> newReminders) async {
//     await (delete(reminders)..where((tbl) => tbl.userId.equals(userId))).go();
//     await batch((batch) {
//       for (var reminder in newReminders) {
//         batch.insert(reminders, reminder);
//       }
//     });
//   }
//
// }
//
// LazyDatabase _openConnection() {
//   return LazyDatabase(() async {
//     final dbFolder = await getApplicationDocumentsDirectory();
//     final file = File(pjoin.join(dbFolder.path, 'app.db'));
//     return NativeDatabase.createInBackground(file);
//   });
// }