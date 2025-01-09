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
// table added in version 3
// to keep track of water drank by user according to date and time
// this is used by the + button in the home screen when clicked it will add an entry to this table
// datetime is for easily grouping the recording according date and time helps in knowing how much water was drank at what time
class WaterIntakeHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  Column<String> get userId => text().references(Users, #id)(); // Keep this for consistency
  DateTimeColumn get drinkDateTime => dateTime()();
  IntColumn get quantity => integer()();
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

  // water intake history cruds
  // Future<int> recordWaterIntake(int quantity) {
  //   final entry = WaterIntakeHistoryCompanion.insert(
  //     userId: Value(defaultUserId),
  //     drinkDateTime: Value(DateTime.now()),
  //     quantity: Value(quantity),
  //   );
  //   return into(waterIntakeHistory).insert(entry);
  // }

  // Future<List<WaterIntakeHistoryData>> getWaterIntakesForDate(DateTime date) {
  //   final startOfDay = DateTime(date.year, date.month, date.day);
  //   final endOfDay = startOfDay.add(const Duration(days: 1));
  //
  //   return (select(waterIntakeHistory)
  //     ..where((tbl) =>
  //     tbl.userId.equals(defaultUserId) &
  //     tbl.drinkDateTime.isBetweenValues(startOfDay, endOfDay))
  //     ..orderBy([(t) => OrderingTerm.desc(t.drinkDateTime)]))
  //       .get();
  // }
  //
  // Future<int> getTotalIntakeForDate(DateTime date) async {
  //   final startOfDay = DateTime(date.year, date.month, date.day);
  //   final endOfDay = startOfDay.add(const Duration(days: 1));
  //
  //   final result = await (select(waterIntakeHistory)
  //     ..where((tbl) =>
  //     tbl.userId.equals(defaultUserId) &
  //     tbl.drinkDateTime.isBetweenValues(startOfDay, endOfDay)))
  //       .get();
  //
  //   return result.fold(0, (sum, entry) => sum + entry.quantity);
  // }
  //
  // Future<void> deleteWaterIntake(int id) =>
  //     (delete(waterIntakeHistory)..where((tbl) => tbl.id.equals(id))).go();
  //
  // // Get intakes for a date range (useful for weekly/monthly views)
  // Future<List<WaterIntakeHistoryData>> getWaterIntakesForDateRange(
  //     DateTime startDate, DateTime endDate) {
  //   return (select(waterIntakeHistory)
  //     ..where((tbl) =>
  //     tbl.userId.equals(defaultUserId) &
  //     tbl.drinkDateTime.isBetweenValues(startDate, endDate))
  //     ..orderBy([(t) => OrderingTerm.desc(t.drinkDateTime)]))
  //       .get();
  // }
}
