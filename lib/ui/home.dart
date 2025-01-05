// import 'dart:async';
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:drift/drift.dart' as drift;
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:waterreminder/services/FirebaseService.dart';
// import 'package:waterreminder/ui/reminder_details.dart';
//
// import '../db/drift_db.dart' as drift;
// import '../main.dart';
//
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
//   int _dailyWaterIntakeGoal = 2000;
//   List<Map<String, dynamic>> _waterIntakePlan = [];
//   bool _isLoading = true;
//   late StreamSubscription<bool> _waterIntakeSubscription;
//   @override
//   void initState() {
//     super.initState();
//     _loadUserDetails();
//     _loadCurrentWaterIntake();
//     _waterIntakeSubscription = waterIntakeUpdateStream.listen((_) {
//       _loadCurrentWaterIntake();
//     });
//   }
//   @override
//   void dispose() {
//     _waterIntakeSubscription.cancel();
//     super.dispose();
//   }
//
//   Future<void> _loadUserDetails() async {
//     print('Loading user details...');
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     final user = FirebaseAuth.instance.currentUser;
//
//     if (user != null) {
//       await _loadCurrentWaterIntake();
//       bool isFetchRequired = false;
//       var checklist = await widget.database.getAllReminders();
//       isFetchRequired = checklist.isEmpty;
//       final userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(user.uid)
//           .get();
//       if (userDoc.exists ) {
//         print('Found user document in Firestore');
//         if (mounted) {
//           setState(() {
//             _dailyWaterIntakeGoal = userDoc.data()?['waterIntake'] ?? 2000;
//
//             final planData =
//             List<Map<String, dynamic>>.from(userDoc.data()?['plan'] ?? []);
//             _waterIntakePlan = planData.map((reminder) {
//               return {
//                 'id': reminder['id'],
//                 'time': reminder['time'],
//                 'title': reminder['title'],
//                 'body': reminder['body'],
//               };
//             }).toList();
//             _isLoading = false;
//           });
//           widget.database.reminders.deleteAll();
//           //save details of user and plan to local db
//           for (Map<String, dynamic> rem in _waterIntakePlan) {
//
//             widget.database.insertReminder(drift.RemindersCompanion(
//                 id: drift.Value(rem['id']),
//                 userId:  drift.Value(
//                     MyFirebaseService().auth.currentUser?.uid.toString() ?? ""),
//                 title:  drift.Value(rem['title']),
//                 time: drift.Value(rem['time']),
//                 body:  drift.Value(rem['body'])
//             ));
//           }
//
//           List<drift.Reminder> reminderListPrint = await widget.database.getAllReminders();
//           reminderListPrint.forEach((rem){
//             _waterIntakePlan.add(
//               {'id':rem.id,'title':rem.title,'time':rem.time,'body':rem.body,'userid':rem.userId}
//             );
//           });
//           print(reminderListPrint.length);
//           reminderListPrint.forEach((rem)=>print(rem));
//           // print(widget.database.reminders.all());
//           // print(widget.database.getAllReminders());
//         }
//       } else {
//         if (mounted) {
//           setState(() {
//             _isLoading = false;
//           });
//         }
//       }
//     } else {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
//   Future<void> _loadCurrentWaterIntake() async {
//     final prefs = await SharedPreferences.getInstance();
//     final today = DateTime.now().toIso8601String().split('T')[0];
//     final currentIntake = prefs.getInt('water_intake_$today') ?? 0;
//
//     if (mounted) {
//       setState(() {
//         _currentDayWaterIntake = currentIntake;
//       });
//     }
//
//
//   }
//   Future<void> _navigateToReminderDetails(int reminderId) async {
//     final result = await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => ReminderDetailsScreen(
//           id: reminderId,
//           database: widget.database,
//         ),
//       ),
//     );
//
//     // Refresh the list if changes were made (result is true)
//     if (result == true) {
//       await _loadUserDetails();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     double progress = _currentDayWaterIntake / _dailyWaterIntakeGoal;
//
//     if (_isLoading) {
//       return const Scaffold(
//         body: Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }
//
//     return Scaffold(
//       appBar:
//           AppBar(title: const Text('Home'), automaticallyImplyLeading: false),
//       body: RefreshIndicator(
//         onRefresh: _loadUserDetails,
//         child: SingleChildScrollView(
//           physics: const AlwaysScrollableScrollPhysics(),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text('Current Day Water Intake:',
//                     style: TextStyle(fontSize: 18)),
//                 const SizedBox(height: 8),
//                 Text(
//                     '${_currentDayWaterIntake} ml / ${_dailyWaterIntakeGoal} ml'),
//                 const SizedBox(height: 16),
//                 LinearProgressIndicator(
//                   value: progress,
//                   backgroundColor: Colors.grey[300],
//                   valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
//                 ),
//                 const SizedBox(height: 32),
//                 const Text('Water Intake Plan:',
//                     style: TextStyle(fontSize: 18)),
//                 const SizedBox(height: 8),
//                 if (_waterIntakePlan.isEmpty)
//                   const Text(
//                       'No reminders set yet. Please complete the onboarding process.')
//                 else
//                   ListView.builder(
//                     shrinkWrap: true,
//                     physics: const NeverScrollableScrollPhysics(),
//                     itemCount: _waterIntakePlan.length,
//                     itemBuilder: (context, index) {
//                       final reminder = _waterIntakePlan[index];
//                       final time = TimeOfDay.fromDateTime(
//                           DateTime.parse(reminder['time']));
//                       return ListTile(
//                         title:
//                             Text(reminder['title'] ?? 'Drink Water Reminder'),
//                         subtitle: Text(
//                             reminder['body'] ?? 'It\'s time to drink water!'),
//                         trailing: Text(time.format(context)),
//                         onTap: () {
//                           final reminderId = reminder['id'];
//                           if (reminderId != null) {
//                             _navigateToReminderDetails(reminderId);
//                           }
//                         },
//                       );
//                     },
//                   ),
//                 const SizedBox(height: 16),
//                 ElevatedButton(
//                   onPressed: () => Navigator.pushNamed(context, '/settings'),
//                   child: const Text('Settings'),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' as drift;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waterreminder/services/FirebaseService.dart';
import 'package:waterreminder/services/notification_service.dart';
import 'package:waterreminder/ui/reminder_details.dart';
import '../db/drift_db.dart' as drift;
import '../main.dart';

class HomeScreen extends StatefulWidget {
  final drift.AppDatabase database;
  const HomeScreen({super.key, required this.database});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late MyNotificationService myNotificationService;

  int _currentDayWaterIntake = 0;
  int _dailyWaterIntakeGoal = 2000;
  List<Map<String, dynamic>> _waterIntakePlan = [];
  bool _isLoading = true;
  late StreamSubscription<bool> _waterIntakeSubscription;
  // late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
  myNotificationService = MyNotificationService();
    _checkInternetConnection();
    _loadCurrentWaterIntake();
    _waterIntakeSubscription = waterIntakeUpdateStream.listen((_) {
      _loadCurrentWaterIntake();
    });
  }

  @override
  void dispose() {
    _waterIntakeSubscription.cancel();
    // _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkInternetConnection() async {
    try {
      await _loadFromLocalDatabase((bool isSuccessful) {
        if (!isSuccessful) {
          _loadUserDetails();
        }
      });
    } catch (e) {
      print('Error checking internet connection: $e');
      _loadUserDetails();
    }
  }


  Future<void> _loadUserDetails() async {
    print('Loading user details...');
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      bool isFetchRequired = false;
      var checklist = await widget.database.getAllReminders();
      isFetchRequired = checklist.isEmpty;

      if (isFetchRequired) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          print('Found user document in Firestore');
          if (mounted) {
            setState(() {
              _dailyWaterIntakeGoal = userDoc.data()?['waterIntake'] ?? 2000;

              final planData =
              List<Map<String, dynamic>>.from(userDoc.data()?['plan'] ?? []);
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

            widget.database.reminders.deleteAll();
            for (Map<String, dynamic> rem in _waterIntakePlan) {
              widget.database.insertReminder(drift.RemindersCompanion(
                  id: drift.Value(rem['id']),
                  userId: drift.Value(MyFirebaseService().auth.currentUser?.uid.toString() ?? ""),
                  title: drift.Value(rem['title']),
                  time: drift.Value(rem['time']),
                  body: drift.Value(rem['body'])));
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        _loadFromLocalDatabase((b)=>{if(!b)print("failed")});
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFromLocalDatabase( Function(bool res) onComplete) async {
    print('Loading from local database...');
    var checklist = await widget.database.getAllReminders();
    if (mounted) {
      setState(() {
        _waterIntakePlan = checklist.map((rem) {
          return {
            'id': rem.id,
            'title': rem.title,
            'time': rem.time,
            'body': rem.body,
            'userid': rem.userId
          };
        }).toList();
        _isLoading = false;
      });
    }
    await myNotificationService.checkPendingNotifications();
    if(checklist==null || checklist.isEmpty){
      onComplete(false);
    }else{
      onComplete(true);
  }
  }

  Future<void> _loadCurrentWaterIntake() async {
    final _prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final key = 'water_intake_$today';
    print('inside udpate daly awater intake');
    int prev = _prefs.getInt(key) ?? 0;
      setState(() {
        _currentDayWaterIntake = prev;
      });

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

    if (result == true && mounted) {
      setState(() {
        _isLoading = true;
      });
      await _loadFromLocalDatabase((success){
        if(mounted){
          setState(() {
            _isLoading = false;
          });
        }
      });
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
      appBar: AppBar(
        title: const Text('Home'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Day Water Intake:',
                    style: TextStyle(fontSize: 18)),
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
                  const Text(
                      'No reminders set yet. Please complete the onboarding process.')
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _waterIntakePlan.length,
                    itemBuilder: (context, index) {
                      final reminder = _waterIntakePlan[index];
                      final time = TimeOfDay.fromDateTime(
                          DateTime.parse(reminder['time']));
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