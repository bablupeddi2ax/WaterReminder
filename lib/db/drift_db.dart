import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as pjoin;
import 'package:path_provider/path_provider.dart';

part 'drift_db.g.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().nullable()();
  IntColumn get age => integer().nullable()();
  IntColumn get weight => integer().nullable()();
  IntColumn get waterIntake => integer().nullable()();
  TextColumn get startTime => text().nullable()();
  TextColumn get endTime => text().nullable()();
}

class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get time => text().nullable()();
}

@DriftDatabase(tables: [Users, Reminders])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<User?> getUserById(int id) => (select(users)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<List<Reminder>> getRemindersByUserId(int userId) => (select(reminders)..where((tbl) => tbl.userId.equals(userId))).get();

  Future<int> insertUser(UsersCompanion user) => into(users).insert(user);

  Future<int> insertReminder(RemindersCompanion reminder) => into(reminders).insert(reminder);

  Future<void> updateRemindersByUserId(int userId, List<RemindersCompanion> newReminders) async {
    await (delete(reminders)..where((tbl) => tbl.userId.equals(userId))).go();
    await batch((batch) {
      for (var reminder in newReminders) {
        batch.insert(reminders, reminder);
      }
    });
  }

}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(pjoin.join(dbFolder.path, 'app.db'));
    return NativeDatabase.createInBackground(file);
  });
}