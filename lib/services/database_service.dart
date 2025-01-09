import 'package:shared_preferences/shared_preferences.dart';
import '../db/drift_db.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  late SharedPreferences _prefs;
  late AppDatabase _database;
  bool _isInitialized = false;

  DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  Future<void> initialize() async {
    if (!_isInitialized) {
      _prefs = await SharedPreferences.getInstance();
      _database = AppDatabase();
      _isInitialized = true;
    }
  }

  bool get isInitialized => _isInitialized;
  SharedPreferences get prefs => _prefs;
  AppDatabase get database => _database;

  Future<void> saveUserDetails(String name, int age, int weight) async {
    await _prefs.setString('name', name);
    await _prefs.setInt('age', age);
    await _prefs.setInt('weight', weight);
  }
  String? getUserName()  {
    return  _prefs.getString('name');
  }
}