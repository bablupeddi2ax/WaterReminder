import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waterreminder/services/database_service.dart';
import 'package:waterreminder/services/notification_service.dart';
import 'package:waterreminder/ui/reminder_details.dart';
import '../db/drift_db.dart' as drift;
import '../main.dart';
import 'dart:math' as math;
class HomeScreen extends StatefulWidget {
  final drift.AppDatabase database;
  final StreamController<bool> controller;
  const HomeScreen({super.key, required this.database, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late MyNotificationService myNotificationService;
  late DatabaseService databaseService;
  int _currentDayWaterIntake = 0;
  final int _dailyWaterIntakeGoal = 2000;
  List<Map<String, dynamic>> _waterIntakePlan = [];
  bool _isLoading = true;
  late StreamSubscription<bool> _waterIntakeSubscription;
  late String userName;
  var currentIndex = 0;

  // late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
  myNotificationService = MyNotificationService();
  databaseService = DatabaseService();
  userName = databaseService.getUserName() ?? "";
    _checkInternetConnection();
    _loadCurrentWaterIntake();
    _waterIntakeSubscription = waterIntakeUpdateStream.listen((_) {
      print("water intake stream posted update");
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
      await _loadFromLocalDatabase((bool isSuccessful) {
        _isLoading = false;
      });
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

  // Future<void> _loadCurrentWaterIntake() async {
  //   final _prefs = await SharedPreferences.getInstance();
  //   final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  //   final key = 'water_intake_$today';
  //   print('inside udpate daly awater intake');
  //   int prev = _prefs.getInt(key) ?? 0;
  //     setState(() {
  //       _currentDayWaterIntake = prev;
  //     });
  //
  // }
  Future<void> _loadCurrentWaterIntake() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];  // Keep consistent with notification service
      final key = 'water_intake_$today';
      final currentIntake = prefs.getInt(key) ?? 0;
      userName = databaseService.getUserName() ?? "";
      if (mounted) {  // Important check
        setState(() {
          _currentDayWaterIntake = currentIntake;
          print('Water intake updated to: $currentIntake');  // Debug log
        });
      }
    } catch (e) {
      print('Error updating water intake: $e');
    }
  }

  Widget _buildHomeContent() {
    double progress = _currentDayWaterIntake / _dailyWaterIntakeGoal;
    // Move your existing home screen content here
    return RefreshIndicator(
      onRefresh:  () async {
        setState(() {
          _isLoading = true;
        });
        await _loadCurrentWaterIntake();
        await _loadFromLocalDatabase((success){
          if(mounted){
            setState(() {
              _isLoading = false;
            });
          }
        });
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              WaterProgressIndicator(
                progress: progress,
                total: _dailyWaterIntakeGoal.toDouble(),
                current: _currentDayWaterIntake.toDouble(),
                onAddIntakeClick: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final today = DateTime.now().toIso8601String().split('T')[0];  // Keep consistent with notification service
                  final key = 'water_intake_$today';
                  final currentIntake = prefs.getInt(key) ?? 0;

                  // Increment intake by 100 ml
                  final newIntake = currentIntake ;
                  // await prefs.setInt(key, newIntake);
                  // _waterIntakeSubscription.add(true);
                  widget.controller.add(true);
                  // Update UI
                  setState(() {
                    _currentDayWaterIntake = newIntake;
                  });
                },
              ),
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
    );
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
      _loadCurrentWaterIntake();
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

    Widget currentScreen;
    switch (currentIndex) {
      case 0:
        currentScreen = _buildHomeContent();
        break;
      case 1:
        currentScreen = const HistoryScreen();
        break;
      case 2:
        currentScreen = const ProfileScreen();
        break;
      default:
        currentScreen = _buildHomeContent();
    }
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      bottomNavigationBar: CustomBottomNavBar(
          currentIndex: currentIndex,
          onTap: (index) {
            setState(() {
              currentIndex = index;
            });
          },
      ),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
      toolbarHeight: 70,
        // show hi $userName
        title:  Text(currentIndex == 0
        //hi emoji code
            ? 'Hi $userName \u{1F44B} '
            : currentIndex == 1
            ? 'History'
            : 'Profile'
            ,textAlign: TextAlign.justify
          ,
        ),
        automaticallyImplyLeading: false,
      ),
      body: currentScreen,
    );
  }
}

// custom progress indicator


class WaterProgressIndicator extends StatelessWidget {
  final double progress; // Value between 0 and 1
  final double total;
  final double current;
  final Future<Null> Function() onAddIntakeClick;
  //waterintakeupdatestreamcontroler

  const WaterProgressIndicator({
    super.key,
    required this.progress,
    required this.total,
    required this.current, required  this.onAddIntakeClick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.grey[100]!
                  , width: 3),
            ),
          ),

          // Progress Arc
          CustomPaint(
            size: const Size(250, 250),
            painter: ProgressArcPainter(
              progress: progress*2,
              progressColor: Colors.blue,
              strokeWidth: 4,
            ),
          ),

          // Moving water drop at the end of progress
          Transform.rotate(
            angle: math.pi * (2*progress-1),
            child: Transform.translate(
              offset: const Offset(0,140), // Adjust based on your circle radius
              child: Transform.rotate(angle: (-math.pi/2 * (progress) )- math.pi/2,child: Icon(
                Icons.water_drop,
                color: Colors.blue,
                size: 22,
              ),
            ),
          ),
          ),
          // Center water drop icon
          const Icon(
            Icons.water_drop,
            color: Colors.blue,
            size: 40,
          ),

          // Text display
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 120),

              Text(
                '${current.toInt()}/${total.toInt()} ml',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              ElevatedButton(
                  onPressed: ()async{
                    SharedPreferences _prefs = await SharedPreferences.getInstance();
                    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                    final key = 'water_intake_$today';
                    print('inside update daily water intake');
                    int prev = _prefs.getInt(key) ?? 0;
                    await _prefs.setInt(key, prev+250);
                    onAddIntakeClick();
                    print(progress);
                    print( (2 * math.pi * progress - (math.pi / 4)));
                  },
                  child: Icon(Icons.add)
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProgressArcPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final double strokeWidth;

  ProgressArcPainter({
    required this.progress,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    // Calculate start angle (-90 degrees in radians for starting from top)
    const startAngle = -math.pi / 2;

    // Calculate sweep angle based on progress (multiply by 2π for full circle)
    final sweepAngle =   math.pi * progress;

    // Create paint object for the progress arc
    final paint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw the progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}



// custom bottom nav
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home, 'Home'),
              _buildNavItem(1, Icons.history, 'History'),
              _buildNavItem(2, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.blue : Colors.grey,
            size: 24,
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blue : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
//

// Future<void> _loadUserDetails() async {
//   print('Loading user details...');
//   final user = FirebaseAuth.instance.currentUser;
//
//   if (user != null) {
//     bool isFetchRequired = false;
//     var checklist = await widget.database.getAllReminders();
//     isFetchRequired = checklist.isEmpty;
//
//     if (isFetchRequired) {
//       final userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(user.uid)
//           .get();
//
//       if (userDoc.exists) {
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
//
//           widget.database.reminders.deleteAll();
//           for (Map<String, dynamic> rem in _waterIntakePlan) {
//             widget.database.insertReminder(drift.RemindersCompanion(
//                 id: drift.Value(rem['id']),
//                 userId: drift.Value(MyFirebaseService().auth.currentUser?.uid.toString() ?? ""),
//                 title: drift.Value(rem['title']),
//                 time: drift.Value(rem['time']),
//                 body: drift.Value(rem['body'])));
//           }
//         }
//       } else {
//         if (mounted) {
//           setState(() {
//             _isLoading = false;
//           });
//         }
//       }
//     } else {
//       _loadFromLocalDatabase((b)=>{if(!b)print("failed")});
//     }
//   } else {
//     if (mounted) {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
// }


// history and profile screens
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);
  Widget _buildHistoryList(List<MapEntry<String, int>> entries) {
    return ListView.builder(

      shrinkWrap: true, // Make ListView take only the space it needs
      physics: const NeverScrollableScrollPhysics(), // Disable scrolling on the ListView
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final date = DateTime.parse(entry.key);
        final formattedDate = DateFormat('MMM dd, yyyy').format(date);

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: ListTile(
            leading: const Icon(Icons.water_drop, color: Colors.blue),
            title: Text(formattedDate),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.value} ml',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  entry.value >= 2000 ? 'Goal Achieved!' : 'Goal: 2000 ml',
                  style: TextStyle(
                    fontSize: 12,
                    color: entry.value >= 2000 ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildWeeklyProgress(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final prefs = snapshot.data!;
        final today = DateTime.now();
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

        final List<Widget> dayWidgets = [];
        final List<String> days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

        for (int i = 0; i < 7; i++) {
          final date = startOfWeek.add(Duration(days: i));
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final key = 'water_intake_$dateStr';
          final intake = prefs.getInt(key) ?? 0;
          final isComplete = intake >= 2000;
          final isToday = dateStr == DateFormat('yyyy-MM-dd').format(today);

          dayWidgets.add(
            Expanded(
              child: Column(
                children: [
                  Text(
                    days[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? Colors.blue : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isComplete ? Colors.green : Colors.grey,
                        width: 2,
                      ),
                      color: isComplete ? Colors.green.withOpacity(0.1) : Colors.transparent,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      isComplete ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: isComplete ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This Week\'s Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: dayWidgets,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final prefs = snapshot.data!;
        final entries = prefs.getKeys()
            .where((key) => key.startsWith('water_intake_'))
            .map((key) {
          final date = key.substring('water_intake_'.length);
          final intake = prefs.getInt(key) ?? 0;
          return MapEntry(date, intake);
        }).toList()
          ..sort((a, b) => b.key.compareTo(a.key));

        return SingleChildScrollView(
          child: Column(
            children: [
              const WaterIntakeGraph(),
              _buildWeeklyProgress(context),
              entries.isEmpty
                  ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'No history available yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
                  : _buildHistoryList(entries),
            ],
          ),
        );
      },
    );
  }
}

// Create Profile Screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _weightController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('name') ?? '';

      // Fix birthdate key and parsing
      String birthdate = prefs.getString('birthdate') ?? '';
      int age = 0;
      try {
        if (birthdate.isNotEmpty) {
          final DateTime birth = DateTime.parse(birthdate);
          age = DateTime.now().year - birth.year;
        }
      } catch(e) {
        print('Error calculating age: $e');
      }
      _ageController.text = age.toString();

      // Fix weight loading
      final weight = prefs.getInt('weight');
      _weightController.text = weight != null ? weight.toString() : '';
    });
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _nameController.text);

    // Fix birthdate saving
    int yob = 0;
    try {
      yob = DateTime.now().year - int.parse(_ageController.text);
    } catch(e) {
      print('Error calculating year of birth: $e');
    }

    // Fix empty key and use consistent key name
    await prefs.setString('birthdate', DateTime(yob, 1, 1).toIso8601String());

    // Fix weight saving
    final weight = int.tryParse(_weightController.text);
    if (weight != null) {
      await prefs.setInt('weight', weight);
    }

    setState(() {
      _isEditing = false;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 50),
          ),
          const SizedBox(height: 20),
          _buildTextField('Name', _nameController, Icons.person),
          _buildTextField('Age', _ageController, Icons.calendar_today),
          _buildTextField('Weight (kg)', _weightController, Icons.monitor_weight),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_isEditing) {
                _saveUserData();
              }
              setState(() {
                _isEditing = !_isEditing;
              });
            },
            child: Text(_isEditing ? 'Save' : 'Edit Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        enabled: _isEditing,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
//
// class WaterIntakeGraphPainter extends CustomPainter {
//   final List<Map<String, dynamic>> weekData;
//
//   WaterIntakeGraphPainter(this.weekData);
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     if (weekData.isEmpty) return;
//
//     final paint = Paint()
//       ..color = Colors.blue
//       ..strokeWidth = 2
//       ..style = PaintingStyle.stroke;
//
//     final fillPaint = Paint()
//       ..shader = LinearGradient(
//         begin: Alignment.topCenter,
//         end: Alignment.bottomCenter,
//         colors: [
//           Colors.blue.withOpacity(0.3),
//           Colors.blue.withOpacity(0.1),
//           Colors.blue.withOpacity(0.0),
//         ],
//       ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
//
//     final path = Path();
//     final fillPath = Path();
//
//     // Find max intake for scaling
//     final maxIntake = weekData.map((d) => d['intake'] as int).reduce(max).toDouble();
//     final safeMaxIntake = maxIntake > 0 ? maxIntake : 2000.0; // Prevent division by zero
//
//     // Create points for the line
//     final points = <Offset>[];
//     for (var i = 0; i < weekData.length; i++) {
//       final x = i * (size.width / (weekData.length - 1));
//       final normalizedY = (weekData[i]['intake'] as int) / safeMaxIntake;
//       final y = size.height - (normalizedY * size.height * 0.8);
//       if (x.isFinite && y.isFinite) {  // Only add valid points
//         points.add(Offset(x, y));
//       }
//     }
//
//     if (points.isEmpty) return;  // Don't draw if no valid points
//
//     // Draw smooth curve through points
//     path.moveTo(points[0].dx, points[0].dy);
//     fillPath.moveTo(points[0].dx, size.height);
//     fillPath.lineTo(points[0].dx, points[0].dy);
//
//     for (var i = 0; i < points.length - 1; i++) {
//       final current = points[i];
//       final next = points[i + 1];
//
//       if (current.dx.isFinite && current.dy.isFinite &&
//           next.dx.isFinite && next.dy.isFinite) {
//         final controlPoint1 = Offset(
//           current.dx + (next.dx - current.dx) / 2,
//           current.dy,
//         );
//         final controlPoint2 = Offset(
//           current.dx + (next.dx - current.dx) / 2,
//           next.dy,
//         );
//
//         path.cubicTo(
//           controlPoint1.dx, controlPoint1.dy,
//           controlPoint2.dx, controlPoint2.dy,
//           next.dx, next.dy,
//         );
//         fillPath.cubicTo(
//           controlPoint1.dx, controlPoint1.dy,
//           controlPoint2.dx, controlPoint2.dy,
//           next.dx, next.dy,
//         );
//       }
//     }
//
//     // Complete fill path
//     fillPath.lineTo(points.last.dx, size.height);
//     fillPath.close();
//
//     // Draw fill and line
//     canvas.drawPath(fillPath, fillPaint);
//     canvas.drawPath(path, paint);
//
//     // Draw today's indicator
//     final today = DateTime.now();
//     final todayIndex = weekData.indexWhere((data) =>
//     DateFormat('yyyy-MM-dd').format(data['date'] as DateTime) ==
//         DateFormat('yyyy-MM-dd').format(today));
//
//     if (todayIndex != -1 && todayIndex < points.length) {
//       final point = points[todayIndex];
//       if (point.dx.isFinite && point.dy.isFinite) {
//         final indicatorPaint = Paint()
//           ..color = Colors.blue
//           ..style = PaintingStyle.fill;
//
//         canvas.drawCircle(point, 4, indicatorPaint);
//       }
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }
//
// class WaterIntakeGraph extends StatelessWidget {
//   const WaterIntakeGraph({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<SharedPreferences>(
//       future: SharedPreferences.getInstance(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const SizedBox(
//             height: 200,
//             child: Center(child: CircularProgressIndicator()),
//           );
//         }
//
//         final prefs = snapshot.data!;
//         final today = DateTime.now();
//         // Start from Monday of the current week
//         final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
//
//         final weekData = List.generate(7, (index) {
//           final date = startOfWeek.add(Duration(days: index));
//           final dateStr = DateFormat('yyyy-MM-dd').format(date);
//           final key = 'water_intake_$dateStr';
//           return {
//             'date': date,
//             'intake': prefs.getInt(key) ?? 0,
//           };
//         });
//
//         return Card(
//           margin: const EdgeInsets.all(16),
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text(
//                       'Your Activity',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     // drop down instead of text
//                     // it should show two options
//                     // weekly , monthly
//                     // in weekly it should show weekly data
//                     // in monthly it should show monthly data
//                     DropdownButton(
//                         items: [
//                       DropdownMenuItem(child: Text('Weekly'), value: 0),
//                       DropdownMenuItem(child: Text('Monthly'), value: 1),
//                     ], onChanged: (i)=>
//                       {
//                       if(i == 0){
//                         // weekly
//                         // fetch and show weekly data in the graph
//                         // show days
//                       }
//                       else
//                         {
//                           // monthly
//                           // fetch and show monthly data in the graph
//                           // show months like jan feb mar apr may jun jul aug sep oct nov dec
//
//                         }
//                     }),
//                     TextButton.icon(
//                       onPressed: () {},
//                       icon: const Text('Weekly'),
//                       label: const Icon(Icons.arrow_drop_down),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//                 SizedBox(
//                   height: 200,
//                   child: CustomPaint(
//                     size: Size.infinite,
//                     painter: WaterIntakeGraphPainter(weekData),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: weekData.map((data) {
//                     final day = DateFormat('E').format(data['date'] as DateTime);
//                     final isToday = DateFormat('yyyy-MM-dd').format(data['date'] as DateTime) ==
//                         DateFormat('yyyy-MM-dd').format(today);
//                     return Text(
//                       day,
//                       style: TextStyle(
//                         color: isToday ? Colors.blue : Colors.grey,
//                         fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
//                       ),
//                     );
//                   }).toList(),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }


enum DisplayMode {
  weekly,
  monthly
}

class WaterIntakeGraphPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final DisplayMode mode;

  WaterIntakeGraphPainter(this.data, this.mode);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.blue.withOpacity(0.3),
          Colors.blue.withOpacity(0.1),
          Colors.blue.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    // Find max intake for scaling
    final maxIntake = data.map((d) => d['intake'] as int).reduce(math.max).toDouble();
    final safeMaxIntake = maxIntake > 0 ? maxIntake : 2000.0;

    // Create points for the line
    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = i * (size.width / (data.length - 1));
      final normalizedY = (data[i]['intake'] as int) / safeMaxIntake;
      final y = size.height - (normalizedY * size.height * 0.8);
      if (x.isFinite && y.isFinite) {
        points.add(Offset(x, y));
      }
    }

    if (points.isEmpty) return;

    // Draw the graph
    _drawGraph(canvas, points, path, fillPath, paint, fillPaint, size);

    // Draw current indicator (today for weekly, current month for monthly)
    _drawCurrentIndicator(canvas, points);
  }

  void _drawGraph(Canvas canvas, List<Offset> points, Path path, Path fillPath,
      Paint paint, Paint fillPaint, Size size) {
    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current.dx.isFinite && current.dy.isFinite &&
          next.dx.isFinite && next.dy.isFinite) {
        final controlPoint1 = Offset(
          current.dx + (next.dx - current.dx) / 2,
          current.dy,
        );
        final controlPoint2 = Offset(
          current.dx + (next.dx - current.dx) / 2,
          next.dy,
        );

        path.cubicTo(
          controlPoint1.dx, controlPoint1.dy,
          controlPoint2.dx, controlPoint2.dy,
          next.dx, next.dy,
        );
        fillPath.cubicTo(
          controlPoint1.dx, controlPoint1.dy,
          controlPoint2.dx, controlPoint2.dy,
          next.dx, next.dy,
        );
      }
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  void _drawCurrentIndicator(Canvas canvas, List<Offset> points) {
    final today = DateTime.now();
    int currentIndex;

    if (mode == DisplayMode.weekly) {
      currentIndex = data.indexWhere((data) =>
      DateFormat('yyyy-MM-dd').format(data['date'] as DateTime) ==
          DateFormat('yyyy-MM-dd').format(today));
    } else {
      currentIndex = data.indexWhere((data) =>
      DateFormat('yyyy-MM').format(data['date'] as DateTime) ==
          DateFormat('yyyy-MM').format(today));
    }

    if (currentIndex != -1 && currentIndex < points.length) {
      final point = points[currentIndex];
      if (point.dx.isFinite && point.dy.isFinite) {
        final indicatorPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill;

        canvas.drawCircle(point, 4, indicatorPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WaterIntakeGraph extends StatefulWidget {
  const WaterIntakeGraph({Key? key}) : super(key: key);

  @override
  State<WaterIntakeGraph> createState() => _WaterIntakeGraphState();
}

class _WaterIntakeGraphState extends State<WaterIntakeGraph> {
  DisplayMode _displayMode = DisplayMode.weekly;

  List<Map<String, dynamic>> _getWeeklyData(SharedPreferences prefs) {
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    return List.generate(7, (index) {
      final date = startOfWeek.add(Duration(days: index));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final key = 'water_intake_$dateStr';
      return {
        'date': date,
        'intake': prefs.getInt(key) ?? 0,
      };
    });
  }

  List<Map<String, dynamic>> _getMonthlyData(SharedPreferences prefs) {
    final today = DateTime.now();
    final startOfYear = DateTime(today.year, 1, 1);

    return List.generate(12, (index) {
      final month = DateTime(today.year, index + 1);
      int monthlyTotal = 0;
      int daysInMonth = DateTime(today.year, index + 2, 0).day;

      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(today.year, index + 1, day);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final key = 'water_intake_$dateStr';
        monthlyTotal += prefs.getInt(key) ?? 0;
      }

      return {
        'date': month,
        'intake': monthlyTotal,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final prefs = snapshot.data!;
        final data = _displayMode == DisplayMode.weekly
            ? _getWeeklyData(prefs)
            : _getMonthlyData(prefs);

        return Card(
          elevation: 2,
          shadowColor: Colors.grey[200],
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    DropdownButton<DisplayMode>(
                      borderRadius: BorderRadius.circular(10),
                      elevation: 30,

                      style: TextStyle(color: Colors.black38),
                      dropdownColor: Colors.white,
                      value: _displayMode,
                      items: const [
                        DropdownMenuItem(
                          value: DisplayMode.weekly,
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: DisplayMode.monthly,
                          child: Text('Monthly'),
                        ),
                      ],
                      onChanged: (DisplayMode? newMode) {
                        if (newMode != null) {
                          setState(() {
                            _displayMode = newMode;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: WaterIntakeGraphPainter(data, _displayMode),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: data.map((item) {
                    final date = item['date'] as DateTime;
                    final label = _displayMode == DisplayMode.weekly
                        ? DateFormat('E').format(date)
                        : DateFormat('MMM').format(date);
                    final isCurrentPeriod = _displayMode == DisplayMode.weekly
                        ? DateFormat('yyyy-MM-dd').format(date) ==
                        DateFormat('yyyy-MM-dd').format(DateTime.now())
                        : DateFormat('yyyy-MM').format(date) ==
                        DateFormat('yyyy-MM').format(DateTime.now());

                    return Text(
                      label,
                      style: TextStyle(
                        color: isCurrentPeriod ? Colors.blue : Colors.grey,
                        fontWeight: isCurrentPeriod ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}