import 'dart:io';
import 'package:habit_counter/models/habit.dart';
import 'package:habit_counter/services/tracker.dart';

void main() async {
  final tracker = HabitTracker();

  // Load existing habits if available
  await tracker.loadFromFile();

  stdout.writeln("Welcome to Habit Tracker");

  if (tracker.allHabits.isNotEmpty) {
    stdout.writeln("You have existing habits:");
    for (int i = 0; i < tracker.allHabits.length; i++) {
      final h = tracker.allHabits[i];
      final status = h.done ? "✅" : "❌";
      stdout.writeln("[$i] ${h.name} (${h.difficulty.name}) - $status");
    }

    stdout.writeln("\nMark habits done today (comma-separated indices):");
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
      stdout.writeln("Habit ${i + 1} name:");
      final name = stdin.readLineSync() ?? 'Unnamed';

      stdout.writeln("Difficulty (Easy, Medium, Hard):");
      final input = stdin.readLineSync() ?? 'Easy';
      final diff = _parseDifficulty(input);

      tracker.addHabit(Habit(name, diff));
    }
  }

  // Summary
  stdout.writeln("\n--- Summary ---");
  for (final habit in tracker.allHabits) {
    final status = habit.done ? "✅ Done" : "❌ Not Done";
    stdout.writeln("${habit.name} - ${habit.difficulty.name} - $status");
  }

  stdout.writeln("\nTotal XP: ${tracker.totalXP}");
  stdout.writeln("Completed Habits: ${tracker.totalCompleted}");

  // Save updated state
  await tracker.saveToFile();
}
