import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/drift_db.dart';

class SignUpScreen extends StatefulWidget {
  final AppDatabase database;

  const SignUpScreen({super.key, required this.database});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _phoneNumberController = TextEditingController();
  String? _verificationId;
  bool _isCodeSent = false;
  Future<bool> userAlreadyExists() async {
    try {
      // Check in Firestore instead of Realtime Database
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: '+91${_phoneNumberController.text}')
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }
  Future<void> _sendVerificationCode() async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${_phoneNumberController.text}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            _storeUserDetails();
            Navigator.pushReplacementNamed(context, '/onboarding');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            if (e.code == 'invalid-phone-number') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('The provided phone number is not valid.')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Verification failed: ${e.message}')),
              );
            }
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isCodeSent = true;
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending verification code: $e')),
        );
      }
    }
  }

  Future<void> _verifyCode(String smsCode) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        _storeUserDetails();
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid verification code')),
        );
      }
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
      appBar: AppBar(
          title: const Text('Sign Up'), automaticallyImplyLeading: false),
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
                    decoration:
                        const InputDecoration(labelText: 'Verification Code'),
                    onChanged: (value) async{
                      if (value.length == 6){
                        bool check = await userAlreadyExists();
                        if(!check) {
                          _verifyCode(value);
                        }else{
                          showBottomSheet(context: context, builder: (BuildContext context){
                            return Text("User Already Exits");
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/signIn'),
              child: const Text('Already have an account? Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
