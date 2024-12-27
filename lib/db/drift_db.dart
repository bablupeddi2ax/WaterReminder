import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as pjoin;
import 'package:path_provider/path_provider.dart';

part 'drift_db.g.dart';

class Users extends Table {
  Column<String> get id => text().nullable()();
  TextColumn get name => text().nullable()();
  IntColumn get age => integer().nullable()();
  IntColumn get weight => integer().nullable()();
  IntColumn get waterIntake => integer().nullable()();
  TextColumn get startTime => text().nullable()();
  TextColumn get endTime => text().nullable()();
}

class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  Column<String> get userId => text().references(Users, #id)();
  TextColumn get time => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text().nullable()();
}

@DriftDatabase(tables: [Users, Reminders])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(pjoin.join(dbFolder.path, 'water_reminder.db'));
      return NativeDatabase(file);
    });
  }

  @override
  int get schemaVersion => 2;

  Future<User?> getUserById(String id) =>
      (select(users)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<List<Reminder>> getRemindersByUserId(String userId) =>
      (select(reminders)..where((tbl) => tbl.userId.equals(userId))).get();

  Future<int> insertUser(UsersCompanion user) => into(users).insert(user);

  Future<int> insertReminder(RemindersCompanion reminder) =>
      into(reminders).insert(reminder);

  Future<void> updateRemindersByUserId(
      String userId, List<RemindersCompanion> newReminders) async {
    await (delete(reminders)..where((tbl) => tbl.userId.equals(userId))).go();
    await batch((batch) {
      for (var reminder in newReminders) {
        batch.insert(reminders, reminder);
      }
    });
  }

    Future<List<Reminder>> getAllReminders() {
      return select(reminders).get();
    }

  Future<Reminder?> getReminderById(int id) =>
      (select(reminders)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<void> updateReminderById(
      int id, RemindersCompanion updatedReminder) async {
    await (update(reminders)..where((tbl) => tbl.id.equals(id)))
        .write(updatedReminder);
  }
}
