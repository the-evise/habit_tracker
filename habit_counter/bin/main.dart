import 'dart:io';
import 'package:habit_counter/models/habit.dart';
import 'package:habit_counter/services/tracker.dart';

void main() async {
  final tracker = HabitTracker();

  // Load existing habits if available
  await tracker.loadFromFile();

  stdout.writeln("--- Welcome to Habit Tracker ---");

  if (tracker.allHabits.isNotEmpty) {
    stdout.writeln("You have existing habits:");
    for (int i = 0; i < tracker.allHabits.length; i++) {
      final h = tracker.allHabits[i];
      final status = h.done ? "✅" : "❌";
      stdout.writeln("[$i] ${h.name} (${h.difficulty.name}) - $status");
    }

    stdout.writeln("\nMark habits done today (comma-seperated indices):");
    final input = stdin.readLineSync() ?? '';
    final indexes = input
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();

    for (var i in indexes) {
      tracker.markHabitDone(i);
    }
  } else {
    stdout.writeln("No habits found. Let's add some!");

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
  }

  // Summary
  stdout.writeln("\n--- Summary ---");
  for (final habit in tracker.allHabits) {
    final status = habit.done ? "✅ Done" : "❌ Not Done";
    stdout.writeln("${habit.name} - ${habit.difficulty.name} - $status");
  }

  stdout.writeln("\nTotal Completed: ${tracker.totalCompleted}");
  stdout.writeln("Total XP Earned: ${tracker.totalXP}");

  // Save updated state
  await tracker.saveToFile();
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
