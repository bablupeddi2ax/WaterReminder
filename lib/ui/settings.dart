import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' as drift;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/drift_db.dart';

class SettingsScreen extends StatefulWidget {
  final AppDatabase database;

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
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // _nameController.text = prefs.getString('name') ?? '';
    // _ageController.text = prefs.getInt('age')?.toString() ?? '';
    // _weightController.text = prefs.getInt('weight')?.toString() ?? '';
    // try {
      final user = FirebaseAuth.instance.currentUser;
      // if (user != null) {
      //   // Try Firestore first
      //   final userDoc = await FirebaseFirestore.instance
      //       .collection('users')
      //       .doc(user.uid)
      //       .get();

        // if (userDoc.exists) {
        //   final userData = userDoc.data()!;
        //   setState(() {
        //     _nameController.text = userData['name'] ?? '';
        //     _ageController.text = userData['age']?.toString() ?? '';
        //     _weightController.text = userData['weight']?.toString() ?? '';
        //   });
        // } else {
          // Fall back to SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          setState(() {
            _nameController.text = prefs.getString('name') ?? '';
            _ageController.text = prefs.getInt('age')?.toString() ?? '';
            _weightController.text = prefs.getInt('weight')?.toString() ?? '';
          });
        // }
      // }
    // } catch (e) {
    //   print('Error loading user details: $e');
    // }
  }

  Future<void> _saveUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('name', _nameController.text);
    prefs.setInt('age', int.tryParse(_ageController.text) ?? 0);
    prefs.setInt('weight', int.tryParse(_weightController.text) ?? 0);
    // Update Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _nameController.text,
        'age': int.tryParse(_ageController.text) ?? 0,
        'weight': int.tryParse(_weightController.text) ?? 0,
      });

      // Update local database
      final userId = await widget.database.insertUser(UsersCompanion(
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
