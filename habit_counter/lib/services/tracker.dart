import 'dart:convert';
import 'dart:io';

import 'package:habit_counter/models/habit.dart';
import 'package:habit_counter/services/reminder_time.dart';

class HabitTracker {
  HabitTracker();
  final List<Habit> habits = [];
  final String storageFile = 'habits.json'; // relative path

  int lifetimeXp = 0;

  final Map<Difficulty, int> xpTable = {
    Difficulty.easy: 5,
    Difficulty.medium: 10,
    Difficulty.hard: 15,
  };

  void addHabit(Habit habit) {
    habits.add(habit);
  }

  void removeHabit(int index) {
    if (index >= 0 && index < habits.length) {
      habits.removeAt(index);
    }
  }

  void editHabit(int index, Habit newHabit) {
    if (index >= 0 && index < habits.length) {
      final oldHabit = habits[index];
      newHabit.lastCompleted = oldHabit.lastCompleted;
      newHabit.completionLog = oldHabit.completionLog;
      newHabit.reminderTime = oldHabit.reminderTime;

      habits[index] = newHabit;
    }
  }

  void markHabitDone(int index) {
    final habit = habits[index];

    if (!habit.isDoneToday) {
      habit.completionLog.add(_dateOnly(_today()));

      // Ensure log only has last 7 unique days
      habit.completionLog = habit.completionLog.map(_dateOnly).toSet().toList()
        ..sort((a, b) => b.compareTo(a));

      // Update lifetime XP
      lifetimeXp += xpTable[habit.difficulty] ?? 0;
    }
  }

  void unmarkHabitDone(int index) {
    final habit = habits[index];
    final today = _dateOnly(DateTime.now());

    habit.completionLog.removeWhere((d) => _isSameDay(d, today));

    // Keep log clean and sorted
    habit.completionLog = habit.completionLog.map(_dateOnly).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    // Update lifetime XP
    lifetimeXp -= xpTable[habit.difficulty] ?? 0;
  }

  /// Get total XP based on habits completed today
  int get todayXp => habits
      .where((h) => h.isDoneToday)
      .fold(0, (sum, h) => sum + (xpTable[h.difficulty] ?? 0));

  /// Get number of habits completed today
  int get totalCompleted => habits.where((h) => h.isDoneToday).length;

  /// Safe unmodifiable list of all habits
  List<Habit> get allHabits => List.unmodifiable(habits);

  /// Load habits from disk and normalize logs
  Future<void> loadFromFile() async {
    final file = File(storageFile);
    if (!await file.exists()) return;

    final content = await file.readAsString();
    if (content.trim().isEmpty) return;

    try {
      final Map<String, dynamic> data = jsonDecode(content);

      habits.clear();
      habits.addAll(
        (data['habits'] as List<dynamic>).map((json) => Habit.fromJson(json)),
      );

      lifetimeXp = data['lifetimeXp'] ?? 0;

      _pruneLogs(); // log cleanup, not daily reset anymore
    } catch (e) {
      stderr.writeln('⚠️ Failed to parse habits.json: $e');
      habits.clear();
    }
  }

  Map<String, dynamic> toJson() => {
    'habits': habits.map((h) => h.toJson()).toList(),
    'lifetimeXp': lifetimeXp,
  };

  factory HabitTracker.fromJson(Map<String, dynamic> json) {
    final tracker = HabitTracker();
    final loadedHabits = (json['habits'] as List<dynamic>)
        .map((h) => Habit.fromJson(h))
        .toList();

    tracker.habits.addAll(loadedHabits);
    tracker.lifetimeXp = json['lifetimeXp'] ?? 0;

    return tracker;
  }

  /// Persist habits to disk
  Future<void> saveToFile() async {
    final file = File(storageFile);
    final content = jsonEncode(toJson());
    await file.writeAsString(content);
  }

  /// Remove duplicates, trim to 7-day history, sort by recency
  void _pruneLogs() {
    for (final habit in habits) {
      habit.completionLog =
          habit.completionLog
              .whereType<DateTime>()
              .map(_dateOnly)
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a));

      if (habit.completionLog.length > 7) {
        habit.completionLog = habit.completionLog.sublist(0, 7);
      }

      if (habit.completionLog.isNotEmpty) {
        habit.lastCompleted = habit.completionLog.first;
      }
    }
  }

  // reminder logic
  void setReminderTime(int index, int hour, int minute) {
    if (index >= 0 && index < habits.length) {
      habits[index].reminderTime = ReminderTime(hour, minute);
    }
  }

  void removeReminderTime(int index) {
    if (index >= 0 && index < habits.length) {
      habits[index].reminderTime = null;
    }
  }

  bool shouldRemind(Habit habit) {
    final now = DateTime.now();
    final time = habit.reminderTime;

    if (time == null || habit.isDoneToday) return false;
    return now.hour < time.hour ||
        (now.hour == time.hour && now.minute <= time.minute);
  }

  List<Habit> checkDueReminders() {
    return habits.where(shouldRemind).toList();
  }

  /// Helpers (internal)
  DateTime _today() => _dateOnly(DateTime.now());

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
