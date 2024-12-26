import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
class MyFirebaseService{
  MyFirebaseService._privateConstructor();

   static final MyFirebaseService _instance = MyFirebaseService._privateConstructor();

   factory MyFirebaseService(){
     return _instance;
   }

   final _fireStoreInstance = FirebaseFirestore.instance;
   final _realTimeDbInstance = FirebaseDatabase.instance;
   final _auth = FirebaseAuth.instance;

   FirebaseFirestore get fireStore => _fireStoreInstance;
   FirebaseDatabase get realTimeDb => _realTimeDbInstance;
   FirebaseAuth get auth=>_auth;

   Future<void> saveDataToRealTimeDatabase(String path,String phoneNumber) async{
     //path can be 'users' {useful for storing phoneNumbers and can be used to find out if a user already exists with phoneNumber}
     await _realTimeDbInstance.ref('users/$phoneNumber').set(true);
   }

   Future<bool> userAlreadyExists(String phoneNumber)async{
     DataSnapshot snapshot  = await _realTimeDbInstance.ref('users/$phoneNumber').get();
     return snapshot.exists;
   }
}





