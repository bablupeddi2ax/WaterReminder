import 'package:drift/drift.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waterreminder/db/drift_db.dart' as drift;
import 'package:waterreminder/services/FirebaseService.dart';
import 'package:waterreminder/services/database_service.dart';

class UserService{

  UserService._internal();
  static final UserService _instance = UserService._internal();
  factory UserService(){return  _instance;}
  late SharedPreferences _prefs;
  late final drift.AppDatabase _database ;
  bool _isInitialized =false;
  Future<void> init() async {
    if (!_isInitialized) {
      _prefs = await SharedPreferences.getInstance();
      _database = DatabaseService().database;
      _isInitialized = true;
    }
  }
  // handles everything related user
  Future<void> saveUserDetailsToSharePrefs(String name,String age, String weight)async{
    try {
      await _prefs.setString('name', name);
      await _prefs.setInt('age', int.parse(age));
      await _prefs.setInt('weight', int.parse(weight));
    }catch(e){
      print(e);
    }
  }

  Future<void> saveUserDetailsToLocalDB(String name,String age, String weight)async {
    final user = MyFirebaseService().auth.currentUser;
    if(user!=null){
      await _database.insertUser(drift.UsersCompanion( id: Value(user.uid),
        name: Value(name),
        age: Value(int.parse(age)),
        weight: Value(int.parse(weight)),));
    }
  }

  Future<void> saveUserDetailsToCloudFirestore(String name,String age, String weight)async{
      final user = MyFirebaseService().auth.currentUser;
      if(user!=null){
        await MyFirebaseService().fireStore.collection('users').doc(user.uid).set({
          'name':name,'age':int.parse(age),'weight':int.parse(weight)
        });
      }
  }
  //sa
  Future<void> saveUserDetailsToRealtimeDb({required String userId})async{
    final ref  = MyFirebaseService().realTimeDb.ref('users/$userId');
    await ref.set(true);
  }


  Future<void> updateUserDetailsInSharedPrefs({String? name=null,int? age = null,int? weight = null})async{
    try {
      if (name != null && name.isNotEmpty) await _prefs.setString('name', name);
      if (age != null && age < 5) await _prefs.setInt('age', age);
      if (weight != null && weight > 30) await _prefs.setInt('weight', weight);
    }catch(e){
      print(e);
    }
  }

  Future<void> updateDailyWaterIntake() async {
    if (!_isInitialized) await init();

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final key = 'water_intake_$today';
      print('inside udpate daly awater intake');
      int prev = _prefs.getInt(key) ?? 0;
      await _prefs.setInt(key, prev + 250);
      print(_prefs.getInt(key));
    } catch (e) {
      print("UpdateDailywaterintakeexception: ${e.toString()}");
    }
  }



}