import 'dart:io';
import 'package:habit_counter/models/habit.dart';
import 'package:habit_counter/services/tracker.dart';

void main() {
  final tracker = HabitTracker();

  stdout.writeln("How many habits do you want to track?");
  final count = int.tryParse(stdin.readLineSync() ?? '') ?? 0;

  for (int i = 0; i < count; i++) {
    stdout.writeln("Enter name for habit ${i + 1}:");
    final name = stdin.readLineSync() ?? 'Unnamed';

    stdout.writeln("Select difficulty (easy, medium, hard):");
    final diffInput = stdin.readLineSync() ?? 'easy';
    final difficulty = _parseDifficulty(diffInput);

    tracker.addHabit(Habit(name, difficulty));
  }

  stdout.writeln(
    "\nMark completed habits by entering their number (comma-separated):",
  );
  for (int i = 0; i < tracker.allHabits.length; i++) {
    final habit = tracker.allHabits[i];
    stdout.writeln("[$i] ${habit.name} (${habit.difficulty.name})");
  }

  final completedInput = stdin.readLineSync() ?? '';
  final doneIndexes = completedInput
      .split(',')
      .map((e) => int.tryParse(e.trim()))
      .whereType<int>()
      .toList();

  for (final index in doneIndexes) {
    tracker.markHabitDone(index);
  }

  // Print Summary
  stdout.writeln("\n--- Summary ---");
  for (final habit in tracker.allHabits) {
    final status = habit.done ? "✅ Done" : "❌ Not Done";
    stdout.writeln("${habit.name} - ${habit.difficulty.name} - $status");
  }

  stdout.writeln("\nTotal Completed: ${tracker.totalCompleted}");
  stdout.writeln("Total XP Earned: ${tracker.totalXP}");
}

Difficulty _parseDifficulty(String input) {
  switch (input.toLowerCase()) {
    case 'medium':
      return Difficulty.medium;
    case 'hard':
      return Difficulty.hard;
    default:
      return Difficulty.easy;
  }
}
