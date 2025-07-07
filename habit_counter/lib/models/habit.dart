import 'dart:convert';

import 'package:habit_counter/services/reminder_time.dart';

enum Difficulty { easy, medium, hard }

class Habit {
  final String name;
  final Difficulty difficulty;
  List<DateTime> completionLog;
  DateTime lastCompleted;
  ReminderTime? reminderTime;

  Habit(
    this.name,
    this.difficulty, {
    List<DateTime>? log,
    DateTime? lastCompleted,
  }) : completionLog = log ?? [],
       lastCompleted = lastCompleted ?? DateTime.now();

  /// --- Computed Properties ---

  int get streak {
    if (completionLog.isEmpty) return 0;

    final today = _today();
    int currentStreak = 0;

    for (int i = 0; i < completionLog.length; i++) {
      final day = today.subtract(Duration(days: i));
      if (completionLog.any((d) => _isSameDay(d, day))) {
        currentStreak += 1;
      } else {
        break;
      }
    }

    return currentStreak;
  }

  // to add validation later and auto logic trigger when updated
  ReminderTime? get getReminderTime => reminderTime;

  bool get isDoneToday {
    final today = _dateOnly(_today());
    return completionLog.any((d) => _isSameDay(_dateOnly(d), today));
  }

  /// --- JSON Serialization ---
  Map<String, dynamic> toJson() => {
    'name': name,
    'difficulty': difficulty.name,
    'lastCompleted': lastCompleted.toIso8601String(),
    'completionLog': completionLog.map((d) => d.toIso8601String()).toList(),
    'reminderTime': reminderTime?.toJson(),
  };

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
        json['name'],
        _parseDifficulty(json['difficulty']),
        log:
            (json['completionLog'] as List<dynamic>?)
                ?.map((d) => DateTime.parse(d).toLocal())
                .toList() ??
            [],
        lastCompleted: json['lastCompleted'] != null
            ? DateTime.parse(json['lastCompleted']).toLocal()
            : null,
      )
      ..reminderTime = json['reminderTime'] != null
          ? ReminderTime.fromJson(json['reminderTime'])
          : null;
  }

  /// --- Helpers ---

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime _dateOnly(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }
}

/// --- Difficulty String Parser ---

Difficulty _parseDifficulty(String str) {
  switch (str.toLowerCase()) {
    case 'medium':
      return Difficulty.medium;
    case 'hard':
      return Difficulty.hard;
    default:
      return Difficulty.easy;
  }
}
