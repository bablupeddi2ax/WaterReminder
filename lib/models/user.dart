class User {
  final int id;
  final String? name;
  final int? age;
  final int? weight;
  final int? waterIntake;
  final String? startTime;
  final String? endTime;

  User({
    required this.id,
    this.name,
    this.age,
    this.weight,
    this.waterIntake,
    this.startTime,
    this.endTime,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String?,
      age: json['age'] as int?,
      weight: json['weight'] as int?,
      waterIntake: json['waterIntake'] as int?,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'weight': weight,
      'waterIntake': waterIntake,
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}
class Reminder {
  final int id;
  final int userId;
  final String? time;

  Reminder({
    required this.id,
    required this.userId,
    this.time,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as int,
      userId: json['userId'] as int,
      time: json['time'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'time': time,
    };
  }
}