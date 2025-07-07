import 'dart:io';
import 'package:habit_counter/models/habit.dart';
import 'package:habit_counter/services/tracker.dart';

const reset = '\x1B[0m';
const bold = '\x1B[1m';

const red = '\x1B[31m';
const green = '\x1B[32m';
const yellow = '\x1B[33m';
const blue = '\x1B[34m';
const cyan = '\x1B[36m';
const grey = '\x1B[90m';

void main() async {
  final tracker = HabitTracker();
  await tracker.loadFromFile(); // load first

  stdout.writeln("--- Welcome to Habit Tracker ---");

  outer:
  while (true) {
    stdout.writeln('\n$bold== YOUR HABITS ==$reset');
    if (tracker.allHabits.isEmpty) {
      stdout.writeln("$yellow⚠️ No habits yet.$reset");
    } else {
      for (int i = 0; i < tracker.allHabits.length; i++) {
        final h = tracker.allHabits[i];
        stdout.writeln(
          '$i. $cyan${h.name}$reset (${h.difficulty.name}) $grey-$reset '
          '🔥 Streak: ${h.streak} day(s) $grey-$reset '
          '${h.isDoneToday ? '$green✅ Done Today$reset' : '$red❌ Not Done Yet$reset'}',
        );
      }
    }

    stdout.writeln("\nChoose:");
    stdout.writeln("1. Mark/unmark habit done");
    stdout.writeln("2. Add new habit");
    stdout.writeln("3. Show total XP");
    stdout.writeln("4. Exit");

    final input = stdin.readLineSync();

    switch (input) {
      case '1':
        if (tracker.allHabits.isEmpty) {
          stdout.writeln(
            "$yellow⚠️  No habits found. Let's add one now.$reset",
          );
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
              stdout.writeln("$red❌ Mark undone for today.$reset");
            } else {
              stdout.writeln("$yellow↪️ Keeping it as done.$reset");
            }
          } else {
            tracker.markHabitDone(index);
            await tracker.saveToFile();
            stdout.writeln("✅ $green Marked as done. $reset");
          }
        } else {
          stdout.writeln("$yellow⚠️  Invalid habit number.$reset");
        }
        break;

      case '2':
        await _addHabitFlow(tracker, askDoneAfter: true);
        break;

      case '3':
        stdout.writeln(
          '$bold🌟 Today XP Earned: $cyan${tracker.todayXp}$reset',
        );
        stdout.writeln(
          '$bold🌟 Total XP Earned: $cyan${tracker.lifetimeXp}$reset',
        );
        break;

      case '4':
        await tracker.saveToFile();
        break outer;

      default:
        stdout.writeln("$yellow⚠️ Invalid option.$reset");
    }
  }

  stdout.writeln("Goodbye. ^^");
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
