import 'dart:io';
import 'package:habit_counter/models/habit.dart';
import 'package:habit_counter/services/tracker.dart';

void main() async {
  final tracker = HabitTracker();
  await tracker.loadFromFile();

  stdout.writeln("--- Welcome to Habit Tracker ---");

  outer:
  while (true) {
    stdout.writeln('\n== YOUR HABITS ==');
    if (tracker.allHabits.isEmpty) {
      stdout.writeln("⚠️ No habits yet.");
    } else {
      for (int i = 0; i < tracker.allHabits.length; i++) {
        final h = tracker.allHabits[i];
        stdout.writeln(
          '$i. ${h.name} (${h.difficulty.name}) - '
          '🔥 Streak: ${h.streak} day(s) - '
          '${h.isDoneToday ? '✅ Done Today' : '❌ Not Done Yet'}',
        );
      }
    }

    stdout.writeln("\nChoose:");
    stdout.writeln("1. Mark/unmark habit done");
    stdout.writeln("2. Add new habit");
    stdout.writeln("3. Exit");

    final input = stdin.readLineSync();

    switch (input) {
      case '1':
        if (tracker.allHabits.isEmpty) {
          stdout.writeln("⚠️ No habits found. Let's add one now.");
          await _addHabitFlow(tracker, askDoneAfter: true);
          break;
        }

        stdout.write("Enter habit number to toggle today’s status: ");
        final index = int.tryParse(stdin.readLineSync() ?? '');

        if (index != null && index >= 0 && index < tracker.allHabits.length) {
          final habit = tracker.allHabits[index];

          if (habit.isDoneToday) {
            stdout.write("It's already done. Unmark it? (Y / N): ");
            final confirm = stdin.readLineSync()?.trim().toLowerCase();
            if (confirm == 'y' || confirm == 'yes') {
              tracker.unmarkHabitDone(index);
              await tracker.saveToFile();
              stdout.writeln("❌ Mark undone for today.");
            } else {
              stdout.writeln("↪️ Keeping it as done.");
            }
          } else {
            tracker.markHabitDone(index);
            await tracker.saveToFile();
            stdout.writeln("✅ Marked as done.");
          }
        } else {
          stdout.writeln("⚠️ Invalid habit number.");
        }
        break;

      case '2':
        await _addHabitFlow(tracker, askDoneAfter: true);
        break;

      case '3':
        await tracker.saveToFile();
        break outer;

      default:
        stdout.writeln("⚠️ Invalid option.");
    }
  }

  stdout.writeln("Goodbye.");
}

Future<void> _addHabitFlow(
  HabitTracker tracker, {
  bool askDoneAfter = false,
}) async {
  stdout.write("Name: ");
  final name = stdin.readLineSync() ?? '';
  stdout.write("Difficulty (easy, medium, hard): ");
  final diffInput = stdin.readLineSync() ?? 'easy';
  final difficulty = _parseDifficulty(diffInput);

  tracker.addHabit(Habit(name, difficulty));
  await tracker.saveToFile();

  stdout.writeln("😎 Habit added successfully.");

  if (askDoneAfter) {
    stdout.write("Have you done this habit today? (Y / N): ");
    final response = stdin.readLineSync()?.trim().toLowerCase();
    if (response == 'y' || response == 'yes') {
      final lastIndex = tracker.allHabits.length - 1;
      tracker.markHabitDone(lastIndex);
      await tracker.saveToFile();
      stdout.writeln("✅ Marked as done.");
    } else {
      stdout.writeln("❌ Not marked.");
    }
  }
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
