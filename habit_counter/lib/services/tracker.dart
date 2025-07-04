import 'dart:convert';
import 'dart:io';

import 'package:habit_counter/models/habit.dart';

class HabitTracker {
  final List<Habit> habits = [];
  final String storageFile = 'habits.json'; // relative to root dir

  // int totalDone = 0;
  // int habitCounter = 0;

  // ignore: non_constant_identifier_names
  Map<Difficulty, int> XPTable = {
    Difficulty.easy: 5,
    Difficulty.medium: 10,
    Difficulty.hard: 15,
  };

  void addHabit(Habit habit) {
    habits.add(habit);
  }

  void markHabitDone(int index) {
    if (index >= 0 && index < habits.length) {
      habits[index].markDone();
    }
  }

  // List<Habit> getHabitsList() {
  //   return habits;
  // }

  int get totalXP => habits
      .where((h) => h.done)
      .fold(0, (sum, h) => sum + (XPTable[h.difficulty] ?? 0));

  int get totalCompleted => habits.where((h) => h.done).length;

  List<Habit> get allHabits => List.unmodifiable(habits);

  // --- File I/O ---
  Future<void> saveToFile() async {
    final file = File(storageFile);
    final content = jsonEncode(habits.map((h) => h.toJson()).toList());
    await file.writeAsString(content);
  }

  Future<void> loadFromFile() async {
    final file = File(storageFile);
    if (await file.exists()) {
      final content = await file.readAsString();
      final List<dynamic> data = jsonDecode(content);
      habits.clear();
      habits.addAll(data.map((json) => Habit.fromJson(json)).toList());
    }
  }
}
