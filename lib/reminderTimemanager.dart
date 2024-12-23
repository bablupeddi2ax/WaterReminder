// Helper class to manage reminder times
import 'package:flutter/material.dart';

class ReminderTimeManager {
  static List<DateTime> generateReminderTimes({
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int numberOfReminders = 8,
  }) {
    // Convert TimeOfDay to minutes since midnight for easier calculations
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;

    // Adjust end time if it's before start time (crosses midnight)
    final adjustedEndMinutes = endMinutes <= startMinutes
        ? endMinutes + 24 * 60
        : endMinutes;

    // Calculate interval between reminders
    final totalMinutes = adjustedEndMinutes - startMinutes;
    final intervalMinutes = totalMinutes / (numberOfReminders - 1);

    List<DateTime> reminderTimes = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int i = 0; i < numberOfReminders; i++) {
      // Calculate minutes since midnight for this reminder
      final reminderMinutes = startMinutes + (intervalMinutes * i).round();

      // Convert back to hour and minute
      final hour = (reminderMinutes ~/ 60) % 24;
      final minute = reminderMinutes % 60;

      // Create DateTime for the reminder
      var reminderTime = today.add(Duration(hours: hour, minutes: minute));

      // If the time has passed for today, schedule for tomorrow
      if (reminderTime.isBefore(now)) {
        reminderTime = reminderTime.add(const Duration(days: 1));
      }

      reminderTimes.add(reminderTime);
    }

    return reminderTimes;
  }

  static String formatTimeForStorage(DateTime dateTime) {
    // Store in a timezone-independent format (local time as ISO string)
    return dateTime.toLocal().toIso8601String();
  }

  static DateTime parseStoredTime(String timeString) {
    // Parse stored time string back to DateTime
    return DateTime.parse(timeString).toLocal();
  }

  static bool isWithinActiveHours(DateTime time, TimeOfDay startTime, TimeOfDay endTime) {
    final timeOfDay = TimeOfDay.fromDateTime(time);
    final timeMinutes = timeOfDay.hour * 60 + timeOfDay.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;

    if (endMinutes > startMinutes) {
      return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
    } else {
      // Handles case where end time is on next day
      return timeMinutes >= startMinutes || timeMinutes <= endMinutes;
    }
  }
}