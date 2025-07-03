import 'package:habit_counter/models/habit.dart';

class HabitTracker {
  List<Habit> habits = [];
  int totalDone = 0;
  int habitCounter = 0;
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

  List<Habit> getHabitsList() {
    return habits;
  }

  int get totalXP => habits
      .where((h) => h.done)
      .fold(0, (sum, h) => sum + (XPTable[h.difficulty] ?? 0));

  int get totalCompleted => habits.where((h) => h.done).length;

  List<Habit> get allHabits => List.unmodifiable(habits);
}
