import 'dart:convert';
import 'dart:io';

import 'package:habit_counter/models/habit.dart';

class HabitTracker {
  final List<Habit> habits = [];
  final String storageFile = 'habits.json'; // relative path

  final Map<Difficulty, int> xpTable = {
    Difficulty.easy: 5,
    Difficulty.medium: 10,
    Difficulty.hard: 15,
  };

  /// Add a new habit
  void addHabit(Habit habit) {
    habits.add(habit);
  }

  void markHabitDone(int index) {
    final habit = habits[index];
    final today = DateTime.now();
    if (!habit.isDoneToday) {
      habit.completionLog.add(DateTime(today.year, today.month, today.day));
      habit.completionLog = habit.completionLog.map(_dateOnly).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
    }
  }

  void unmarkHabitDone(int index) {
    final habit = habits[index];
    final today = _dateOnly(DateTime.now());

    habit.completionLog.removeWhere((d) => _isSameDay(d, today));

    // Keep log clean and sorted
    habit.completionLog = habit.completionLog.map(_dateOnly).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
  }

  /// Get total XP based on habits completed today
  int get totalXP => habits
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
      final List<dynamic> data = jsonDecode(content);
      habits.clear();
      habits.addAll(data.map((json) => Habit.fromJson(json)));
      _pruneLogs(); // log cleanup, not daily reset anymore
    } catch (e) {
      stderr.writeln('⚠️ Failed to parse habits.json: $e');
      habits.clear();
    }
  }

  /// Persist habits to disk
  Future<void> saveToFile() async {
    final file = File(storageFile);
    final content = jsonEncode(habits.map((h) => h.toJson()).toList());
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

  /// Helpers (internal)
  DateTime _today() => _dateOnly(DateTime.now());

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
