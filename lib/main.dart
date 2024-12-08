import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:waterreminder/NotificationService.dart';
import 'package:waterreminder/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseFirestore.instance.settings.persistenceEnabled;
    print('Firebase initialized successfully!');
    await NotificationService().init();
    try {
      final androidPlugin = AndroidFlutterLocalNotificationsPlugin();
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }catch(e){
      print(e.toString());
    }
    runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
        home: AuthGate()
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  User? currentUser;
  bool notificationClicked = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    checkUserAuthStatus();
    handleNotificationClick();
  }
  void checkUserAuthStatus(){
    setState(() {
      currentUser = FirebaseAuth.instance.currentUser;
    });
  }
  void handleNotificationClick(){
    Future.delayed(Duration.zero,(){
      setState(() {
        notificationClicked = true;
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    if(currentUser==null){
      return const AuthGate();
    }else{
      return const HomeScreen();
    }
  }
}


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Demo')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            final selectedTime = DateTime.now().add(const Duration(seconds: 10));
            NotificationService().scheduleDailyNotification(selectedTime);
          },
          child: const Text('Schedule Notification'),
        ),
      ),
    );
  }
}


class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SignInScreen(
            providers: [
              EmailAuthProvider(),
              GoogleProvider(clientId: '492006332296-3g4e630tgabaoo68ulrbdn6bsqatonmm.apps.googleusercontent.com')

            ],
            headerBuilder: (context,constraints,shrinkOffset){
              return Padding(padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('assets/img.png',),),
              );

            },
            subtitleBuilder: (context,action){
              return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: action==AuthAction.signIn?
                const Text('Please Sign in '):
                const Text("please sign up"),
              );
            },
            footerBuilder: (context,action){
              return const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Bys sining in u agree to our terms and conditions',
                  style: TextStyle(color: Colors.grey),),);
            },
          );
        }

        return const OnboardingScreen();
      },
    );
  }
}


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  PageController pc = PageController();
  int _currPage = 0;
  double? weight;
  int? age;
  int? dailyWaterIntake;

  void _nextPage() {
    if (_currPage < 2) {
      pc.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Validate inputs
      if (weight != null && age != null && dailyWaterIntake != null) {
        // Save user data
        saveUserData(weight!, age!, dailyWaterIntake!);

        // Navigate to the home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all the details')),
        );
      }
    }
  }

  Future<void> saveUserData(double weight, int age, int dailyIntake) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('weight', weight);
    await prefs.setInt('age', age);
    await prefs.setInt('dailyWaterIntake', dailyIntake);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: pc,
        onPageChanged: (index) => setState(() {
          _currPage = index;
        }),
        children: [
          welcomeScreen(),
          weightInputScreen(),
          dailyWaterIntakeScreen(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: _nextPage,
          child: Text(_currPage < 2 ? "Next" : "Finish"),
        ),
      ),
    );
  }

  Widget welcomeScreen() {
    return const Center(
      child: Text(
        "Welcome to the Water Reminder App!\nStay hydrated!",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget weightInputScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Enter your weight (kg):", style: TextStyle(fontSize: 16)),
          TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) => weight = double.tryParse(value),
          ),
          const SizedBox(height: 16),
          const Text("Enter your age:", style: TextStyle(fontSize: 16)),
          TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) => age = int.tryParse(value),
          ),
        ],
      ),
    );
  }

  Widget dailyWaterIntakeScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("How much water do you drink daily (in ml)?",
              style: TextStyle(fontSize: 16)),
          TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) => dailyWaterIntake = int.tryParse(value),
          ),
        ],
      ),
    );
  }
}

