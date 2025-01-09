import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import '../db/drift_db.dart' as driftgen;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:waterreminder/services/notification_service.dart';
// welcome screen
import 'package:flutter/material.dart';
import '../db/drift_db.dart' as driftgen;

class WelcomeScreen extends StatelessWidget {
  final driftgen.AppDatabase database;

  const WelcomeScreen({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Hi,\nI'm your Personal Hydration\nCompanion",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => OnboardingScreen(database: database)));
                },
                child: const Text('Let\'s Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
  class OnboardingScreen extends StatefulWidget {
    final driftgen.AppDatabase database;
    const OnboardingScreen({super.key, required this.database});
    @override
    State<OnboardingScreen> createState() => _OnboardingScreenState();
  }
  class _OnboardingScreenState extends State<OnboardingScreen> {
    final PageController _pageController = PageController();
    final TextEditingController _nameController = TextEditingController();
    DateTime _selectedDate = DateTime(2000);
    String _selectedGender = 'Male';
    TimeOfDay _wakeUpTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay _sleepTime = const TimeOfDay(hour: 22, minute: 0);
    int _selectedWeight = 70;
    int _selectedHeight = 170;
    int currPage = 0;
    late MyNotificationService myNotificationService;
    // to hide the keyboard
    FocusNode nameNode = FocusNode();
    @override
    void initState() {
      super.initState();
      tz.initializeTimeZones();
      myNotificationService = MyNotificationService();
      myNotificationService.initialize();
      _pageController.addListener(() {
        if (nameNode.hasFocus) {
          nameNode.unfocus();
        }
      });
    }
    @override
    void dispose() {
      nameNode.dispose();  // Add this
      _pageController.dispose();
      _nameController.dispose();
      super.dispose();
    }
    void _scheduleNotifications(List<Map<String, String?>> planData) async{
      // Schedule notifications
      // await flutterLocalNotificationsPlugin.cancelAll();
      await myNotificationService.getPlugin().cancelAll();
      myNotificationService.scheduleNotification(planData);

      myNotificationService.getPlugin().show(-1, 'test', 'body', const NotificationDetails(
        android: AndroidNotificationDetails(
          "WATER_REMINDER",
          "REMINDER_CHANNEL",
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
      ));
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
      print(plan.toList());
      print(plan);
      return plan;
    }


    Widget _buildNamePage() {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/namelottie.png', height: 200),
          const SizedBox(height: 20),
          TextField(
            focusNode: nameNode,
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Enter your name',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    }
    Widget bottomButtons(int currPage, void Function() onBackClicked, void Function() onNextClicked) {


      // Name page (page 1) - only next button
      if (currPage == 0) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () {
                if (nameNode.hasFocus) {
                  nameNode.unfocus();
                }
                onNextClicked();
              },
              child: const Text('Next'),
            ),
          ],
        );
      }

      // All other pages - both back and next buttons
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Card(
            shape: const CircleBorder(
              side: BorderSide(
                color: Color.fromRGBO(201, 201, 201, 1.0),
              ),
            ),
            color: const Color.fromRGBO(201, 201, 201, 1.0),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                size: 20,
              ),
              color: Colors.white,
              onPressed: onBackClicked,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameNode.hasFocus) {
                nameNode.unfocus();
              }
              onNextClicked();
            },
            child: Text(currPage == 5 ? 'Finish' : 'Next'),
          ),
        ],
      );
    }
    Widget _buildBirthdatePage() {
      return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/birthdaylottie.png', height: 200),
            const SizedBox(height: 20),
            const Text(
              'When were you born?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            CustomDatePicker(
              onDateSelected: (date) {
                setState(() => _selectedDate = date);
              },
              initialDate: _selectedDate,
            ),
          ],
        ),
      );
    }
    Widget _buildGenderPage() {
      final genders = ['Male', 'Female', 'Other'];
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/genderlottie.png', height: 200),
          const SizedBox(height: 20),
          const Text(
            'Select your gender',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 200,
            child: ListWheelScrollView(
              itemExtent: 50,
              perspective: 0.005,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                setState(() => _selectedGender = genders[index]);
              },
              children: genders.map((gender) => Center(
                child: Text(
                  gender,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: gender == _selectedGender ?
                    FontWeight.bold : FontWeight.normal,
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      );
    }
    Widget _buildTimePicker(String title,String img, TimeOfDay selectedTime, Function(TimeOfDay) onTimeSelected) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/$img.png', height: 200),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeWheel(
                  selectedTime.hour,
                  23,
                      (value) => onTimeSelected(TimeOfDay(hour: value, minute: selectedTime.minute)),
                  'Hour',
                ),
                const Text(':', style: TextStyle(fontSize: 30)),
                _buildTimeWheel(
                  selectedTime.minute,
                  59,
                      (value) => onTimeSelected(TimeOfDay(hour: selectedTime.hour, minute: value)),
                  'Minute',
                ),
              ],
            ),
          ),
        ],
      );
    }
    Widget _buildTimeWheel(int selectedValue, int maxValue, Function(int) onChanged, String label) {
      return SizedBox(
        width: 70,
        child: ListWheelScrollView(
          itemExtent: 40,
          perspective: 0.005,
          diameterRatio: 1.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChanged,
          children: List.generate(maxValue + 1, (index) => Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: index == selectedValue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          )),
        ),
      );
    }
    Widget _buildMeasurementPicker(String title,int selectedValue, int min, int max, Function(int) onChanged) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 120,
            child: ListWheelScrollView(
              itemExtent: 40,
              perspective: 0.005,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) => onChanged(min + index),
              children: List.generate(max - min + 1, (index) => Center(
                child: Text(
                  '${min + index}',
                  style: TextStyle(
                    fontSize: (min+index)==selectedValue?30:20,
                    color: (min+index)==selectedValue?Colors.blue:Colors.black,
                    fontWeight: (min + index) == selectedValue ?
                    FontWeight.bold : FontWeight.normal,
                  ),
                ),
              )),
            ),
          ),
        ],
      );
    }
    Widget _weightAndHeightBlock(){
      return Column(
        children: [
          Image.asset('assets/weightlottie.png', height: 120),
          const SizedBox(height: 20,),
          _buildMeasurementPicker(
            'What is your weight (kg)?',
            _selectedWeight,
            30,
            250,
                (value) => setState(() => _selectedWeight = value),
          ),
          const SizedBox(height: 10,),
          _buildMeasurementPicker(
            'What is your height (cm)?',
            _selectedHeight,
            100,
            250,
                (value) => setState(() => _selectedHeight = value),
          ),
        ],
      );
    }
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child:Column(
              children: [
                _buildProgressIndicator(currPage),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => currPage = index);
                      },
                      children: [
                        _buildNamePage(),
                        _buildBirthdatePage(),
                        _buildGenderPage(),
                        _buildTimePicker(
                          'When do you wake up?',
                          'wakeuplottie',
                          _wakeUpTime,
                              (time) => setState(() => _wakeUpTime = time),
                        ),
                        _buildTimePicker(
                          'When do you go to sleep?',
                          'sleeplottie',
                          _sleepTime,
                              (time) => setState(() => _sleepTime = time),
                        ),

                       _weightAndHeightBlock(),
                      ],
                    ),
                  ),
                ),
                bottomButtons(currPage,
                      () {
                        // handle the first page keyboard hiding manually
                    if (currPage>=1) {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                      () async {
                    if (currPage <=4) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      await  _storeUserDetails();
                      if(mounted) {
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
    String formatTimeOfDay(TimeOfDay time) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    Future<void> _storeUserDetails() async {
      final prefs = await SharedPreferences.getInstance();
      // Store user details
      prefs.setString('userId', "userId");
      prefs.setString('name', _nameController.text);
      prefs.setString('birthdate', _selectedDate.toIso8601String());
      prefs.setString('gender', _selectedGender);
      prefs.setString('wakeUpTime', '${_wakeUpTime.hour}:${_wakeUpTime.minute}');
      prefs.setString('sleepTime', '${_sleepTime.hour}:${_sleepTime.minute}');
      prefs.setInt('weight', _selectedWeight);
      prefs.setInt('height', _selectedHeight);
      // Generate water intake plan times
      final plan = _generateWaterIntakePlan(
        2000,
        formatTimeOfDay(_wakeUpTime),
        formatTimeOfDay(_sleepTime),
      );
      await widget.database.insertUser(driftgen.UsersCompanion(
        id: drift.Value("userId"),
        name: drift.Value(_nameController.text),
        age:drift.Value(DateTime.now().year - _selectedDate.year) ,
        weight: drift.Value(_selectedWeight),
        waterIntake: drift.Value(2000),
        startTime: drift.Value(formatTimeOfDay(_wakeUpTime)),
        endTime: drift.Value(formatTimeOfDay(_sleepTime)),
      ));
      // Store reminders in local database first to get IDs
      List<driftgen.Reminder> localReminders = [];
      for (var planTime in plan) {
        final reminderCompanion = driftgen.RemindersCompanion(
          userId: drift.Value("userId"),
          time: drift.Value(planTime.toUtc().toIso8601String()),
          title:  drift.Value('Hey ${_nameController.text}'),
          body: const drift.Value('It\'s time to drink water!'),
        );
        // Insert and get the auto-generated ID
        final reminderId =
        await widget.database.insertReminder(reminderCompanion);
        final reminder = await widget.database.getReminderById(reminderId);
        if (reminder != null) {
          localReminders.add(reminder);
        }
      }
      // Create two versions of planData: one for Firestore (can handle various types)
      // and one for SharedPreferences/notifications (needs strings)
      final stringPlanData = localReminders
          .map((driftgen.Reminder reminder) => {
        'id': reminder.id.toString(),
        'time': reminder.time,
        'title': reminder.title,
        'body': reminder.body,
      }).toList();
      // Store in SharedPreferences (needs strings)
      prefs.setStringList('plan',
          stringPlanData.map((reminder) => jsonEncode(reminder)).toList());
      // Cancel existing notifications
      // await flutterLocalNotificationsPlugin.cancelAll();
      await myNotificationService.getPlugin().cancelAll();
      // Schedule new notifications using the string version of planData
      _scheduleNotifications(stringPlanData);
      prefs.setBool('onboardingComplete', true);
      if(mounted) {
        // Navigate to home screen
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }
  class CustomDatePicker extends StatefulWidget {
    final Function(DateTime) onDateSelected;
    final DateTime? initialDate;

    const CustomDatePicker({
      super.key,
      required this.onDateSelected,
      this.initialDate,
    });

    @override
    State<CustomDatePicker> createState() => _CustomDatePickerState();
  }
  class _CustomDatePickerState extends State<CustomDatePicker> {
    late FixedExtentScrollController _yearController;
    late FixedExtentScrollController _monthController;
    late FixedExtentScrollController _dayController;

    late DateTime _selectedDate;
    final int _startYear = 1900;
    final int _endYear = DateTime.now().year;

    @override
    void initState() {
      super.initState();
      _selectedDate = widget.initialDate ?? DateTime.now();

      // Initialize controllers with current selection
      _yearController = FixedExtentScrollController(
        initialItem: _selectedDate.year - _startYear,
      );
      _monthController = FixedExtentScrollController(
        initialItem: _selectedDate.month - 1,
      );
      _dayController = FixedExtentScrollController(
        initialItem: _selectedDate.day - 1,
      );
    }

    @override
    void dispose() {
      _yearController.dispose();
      _monthController.dispose();
      _dayController.dispose();
      super.dispose();
    }

    int _getDaysInMonth(int year, int month) {
      return DateTime(year, month + 1, 0).day;
    }

    @override
    Widget build(BuildContext context) {
      return Container(
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // Year picker
            Expanded(
              flex: 2,
              child: _buildDateWheel(
                controller: _yearController,
                items: List.generate(
                  _endYear - _startYear + 1,
                      (index) => (_startYear + index).toString().padLeft(4, '0'),
                ),
                onChanged: (index) {
                  setState(() {
                    final newYear = _startYear + index;
                    final daysInMonth = _getDaysInMonth(
                      newYear,
                      _selectedDate.month,
                    );

                    if (_selectedDate.day > daysInMonth) {
                      _selectedDate = DateTime(
                        newYear,
                        _selectedDate.month,
                        daysInMonth,
                      );
                      _dayController.jumpToItem(daysInMonth - 1);
                    } else {
                      _selectedDate = DateTime(
                        newYear,
                        _selectedDate.month,
                        _selectedDate.day,
                      );
                    }
                    widget.onDateSelected(_selectedDate);
                  });
                },
              ),
            ),
            const Text(' / '),
            // Month picker
            Expanded(
              child: _buildDateWheel(
                controller: _monthController,
                items: List.generate(
                  12,
                      (index) => (index + 1).toString().padLeft(2, '0'),
                ),
                onChanged: (index) {
                  setState(() {
                    final newMonth = index + 1;
                    final daysInMonth = _getDaysInMonth(
                      _selectedDate.year,
                      newMonth,
                    );

                    if (_selectedDate.day > daysInMonth) {
                      _selectedDate = DateTime(
                        _selectedDate.year,
                        newMonth,
                        daysInMonth,
                      );
                      _dayController.jumpToItem(daysInMonth - 1);
                    } else {
                      _selectedDate = DateTime(
                        _selectedDate.year,
                        newMonth,
                        _selectedDate.day,
                      );
                    }
                    widget.onDateSelected(_selectedDate);
                  });
                },
              ),
            ),
            const Text(' / '),
            // Day picker
            Expanded(
              child: _buildDateWheel(
                controller: _dayController,
                items: List.generate(
                  _getDaysInMonth(_selectedDate.year, _selectedDate.month),
                      (index) => (index + 1).toString().padLeft(2, '0'),
                ),
                onChanged: (index) {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      index + 1,
                    );
                    widget.onDateSelected(_selectedDate);
                  });
                },
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildDateWheel({
      required FixedExtentScrollController controller,
      required List<String> items,
      required Function(int) onChanged,
    }) {
      return ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 40,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.01,
        diameterRatio: 1.5,
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: items.length,
          builder: (context, index) {
            return Center(
              child: Text(
                items[index],
                style: TextStyle(
                  fontSize: 20,
                  color: controller.selectedItem == index
                      ? Colors.blue
                      : Colors.grey[300],
                  fontWeight: controller.selectedItem == index
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            );
          },
        ),
      );
    }
  }
Widget _buildProgressIndicator(int currIndex) {
  // Don't show progress indicator on welcome page


  const int totalPages = 6; // Total number of pages after welcome

  return Container(
    alignment: Alignment.topLeft,
    child: Stack(
      alignment: Alignment.centerLeft,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: LinearProgressIndicator(
            value: (currIndex+1).toDouble() / totalPages,  // Calculate progress without welcome page
            valueColor: const AlwaysStoppedAnimation<Color>(Color.fromRGBO(61, 161, 255, 1.0)),
            backgroundColor: const Color.fromARGB(201, 201, 201, 201),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(totalPages, (index) {
            final isActive = index <= currIndex;
            return Card(
              color: isActive
                  ? const Color.fromRGBO(61, 161, 255, 1.0)
                  : const Color.fromARGB(201, 201, 201, 201),
              shape: CircleBorder(
                side: BorderSide(
                  color: isActive
                      ? Colors.grey[300]!
                      : const Color.fromARGB(201, 201, 201, 201),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          }),
        )
      ],
    ),
  );
}

