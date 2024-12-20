import 'package:flutter/material.dart';

class ProgressIndicatorWidget extends StatelessWidget {
  final double currentIntake;
  final double dailyIntakeGoal;

  ProgressIndicatorWidget({required this.currentIntake, required this.dailyIntakeGoal});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: currentIntake / dailyIntakeGoal,
      backgroundColor: Colors.grey[300],
      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
    );
  }
}