import 'dart:io';
import 'package:habit_counter/models/habit.dart';
import 'package:habit_counter/tracker.dart';

void main() async {
  final tracker = HabitTracker();
  await tracker.loadFromFile();

  while (true) {
    stdout.writeln("\n=== Your Habits ===");
    for (int i = 0; i < tracker.allHabits.length; i++) {
      final h = tracker.allHabits[i];
      stdout.writeln(
        "$i. ${h.name} (${h.difficulty.name}) - "
        "🔥 Streak: ${h.streak} day(s) - "
        "${h.done ? '✅ Done Today' : '❌ Not Done'}",
      );
    }

    stdout.writeln("\nChoose:");
    stdout.writeln("1. Mark habit done");
    stdout.writeln("2. Add new habit");
    stdout.writeln("3. Exit");

    final input = stdin.readLineSync();
    if (input == '1') {
      stdout.write("Enter habit number to mark done: ");
      final index = int.tryParse(stdin.readLineSync() ?? '');
      if (index != null) {
        tracker.markHabitDone(index);
        await tracker.saveToFile();
        stdout.writeln("Marked as done.");
      }
    } else if (input == '2') {
      stdout.write("Name: ");
      final name = stdin.readLineSync() ?? '';
      stdout.write("Difficulty (Easy, Medium, Hard): ");
      final diffInput = stdin.readLineSync() ?? 'Easy';
      final difficulty = _parseDifficulty(diffInput);
      tracker.addHabit(Habit(name, difficulty));
      await tracker.saveToFile();
    } else if (input == '3') {
      await tracker.saveToFile();
      break;
    }
  }

  stdout.writeln("Goodbye.");
}

Difficulty _parseDifficulty(String input) {
  switch (input.toLowerCase()) {
    case 'medium':
      return Difficulty.Medium;
    case 'hard':
      return Difficulty.Hard;
    default:
      return Difficulty.Easy;
  }
}
