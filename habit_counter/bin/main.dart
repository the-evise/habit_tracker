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
    // 🔔 Show reminders
    final dueHabits = tracker.checkDueReminders();

    if (dueHabits.isNotEmpty) {
      stdout.writeln('\n$bold$yellow🔔 Reminders:$reset');
      for (final h in dueHabits) {
        stdout.writeln("Don't forget to do $cyan${h.name}$reset today.");
        if (h.streak > 1) {
          stdout.writeln(
            "$cyan🔥 You're on a ${h.streak}-day streak. Keep it going!$reset",
          );
        }
      }
    }

    // 🧾 Show habit list
    stdout.writeln('\n$bold== YOUR HABITS ==$reset');
    if (tracker.allHabits.isEmpty) {
      stdout.writeln("$yellow⚠️ No habits yet.$reset");
    } else {
      for (int i = 0; i < tracker.allHabits.length; i++) {
        final h = tracker.allHabits[i];
        final reminder = h.reminderTime != null
            ? "(Reminder: ${h.reminderTime!.hour.toString().padLeft(2, '0')}:${h.reminderTime!.minute.toString().padLeft(2, '0')})"
            : "";
        if (h.reminderTime != null) {
          stdout.writeln(
            '$i. $cyan${h.name}$reset (${h.difficulty.name}) '
            '$yellow🔔 $reminder $yellow$grey-$reset '
            '🔥 Streak: ${h.streak} day(s) $grey-$reset '
            '${h.isDoneToday ? '$green✅ Done Today$reset' : '$red❌ Not Done Yet$reset'}',
          );
        } else {
          stdout.writeln(
            '$i. $cyan${h.name}$reset (${h.difficulty.name}) $grey-$reset '
            '🔥 Streak: ${h.streak} day(s) $grey-$reset '
            '${h.isDoneToday ? '$green✅ Done Today$reset' : '$red❌ Not Done Yet$reset'}',
          );
        }
      }
    }

    // 📋 Menu options
    stdout.writeln("\nChoose:");
    stdout.writeln("1. Mark/unmark habit done");
    stdout.writeln("2. Add new habit");
    stdout.writeln("3. Edit/delete habits");
    stdout.writeln("4. Edit Reminders");
    stdout.writeln("5. Diary & Notes");
    stdout.writeln("6. Export Weekly Summary to File");
    stdout.writeln("7. Show total XP");
    stdout.writeln("8. Exit");

    final input = stdin.readLineSync();

    switch (input) {
      case '1':
        await _promptAndToggleHabit(tracker);
        break;

      case '2':
        await _addHabitFlow(tracker, askDoneAfter: true);
        break;

      case '3':
        await _editDeleteFlow(tracker);
        break;

      case '4':
        _reminderFlow(tracker);
        break;

      case '5':
        await _diaryMenu(tracker);

      case '6':
        await _exportWeeklySummaryResult(tracker);
        break;

      case '7':
        _printXpSummary(tracker);
        break;

      case '8':
        await tracker.saveToFile();
        break outer;

      default:
        stdout.writeln("$yellow⚠️ Invalid option.$reset");
    }
  }

  stdout.writeln("Goodbye. ^^");
}

/// --- Subflows and Utilities ---

Future<void> _addHabitFlow(
  HabitTracker tracker, {
  bool askDoneAfter = false,
}) async {
  stdout.write("Name: ");
  final name = stdin.readLineSync() ?? '';
  stdout.write("Difficulty (easy, medium, hard): ");
  final diffInput = stdin.readLineSync() ?? 'easy';
  final difficulty = _parseDifficulty(diffInput);

  final newHabit = Habit(name, difficulty);
  tracker.addHabit(newHabit);

  // 🔔 Ask for reminder time
  stdout.writeln('Set a daily reminder time for this habit? (Y / N): ');
  final setReminder = stdin.readLineSync()?.trim().toLowerCase();
  if (setReminder == 'y' || setReminder == 'yes') {
    stdout.write('Enter hour (0-23): ');
    final hour = int.tryParse(stdin.readLineSync() ?? '');
    stdout.write('Enter minute (0-59): ');
    final minute = int.tryParse(stdin.readLineSync() ?? '');

    if (hour != null && minute != null) {
      final lastIndex = tracker.allHabits.length - 1;
      tracker.setReminderTime(lastIndex, hour, minute);
      stdout.writeln('$green⏰ Reminder set for $hour:$minute.$reset');
    } else {
      stdout.writeln(
        '$yellow⚠️  Invalid time input. Skipping reminder setup.$reset',
      );
    }
  }
  await tracker.saveToFile();
  stdout.writeln("😎 Habit added successfully.");

  // ✅ Optionally ask if done today
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

Future<void> _toggleHabitDone(HabitTracker tracker, int index) async {
  final habit = tracker.allHabits[index];
  // update habit status
  if (habit.isDoneToday) {
    tracker.unmarkHabitDone(index);
    stdout.writeln("$red❌ Mark undone for today.$reset");
  } else {
    tracker.markHabitDone(index);

    // note prompt
    stdout.write("📝 Want to add a note for this habit today? (Y / N): ");
    final noteInput = stdin.readLineSync()?.trim().toLowerCase();
    if (noteInput == 'y' || noteInput == 'yes') {
      stdout.write('Enter your note: ');
      final note = stdin.readLineSync()?.trim() ?? '';
      tracker.addNoteForHabitToday(habit.name, note);
    }
  }
  try {
    await tracker.saveToFile();
    // provide feedback after saving
    stdout.writeln("✅ $green Marked as done.$reset");
    stdout.writeln("✅ $green Note added.$reset");
  } catch (e) {
    print("Error on save to file: $e");
  }

  // 🧠 Feedback: XP updated
  _printXpSummary(tracker);
}

Future<void> _promptAndToggleHabit(HabitTracker tracker) async {
  if (tracker.allHabits.isEmpty) {
    stdout.writeln("$yellow⚠️ No habits found. Let's add one now.$reset");
    await _addHabitFlow(tracker, askDoneAfter: true);
    return;
  }

  stdout.write("Enter habit number to toggle today’s status: ");
  final index = int.tryParse(stdin.readLineSync() ?? '');

  if (index != null && index >= 0 && index < tracker.allHabits.length) {
    final habit = tracker.allHabits[index];

    if (habit.isDoneToday) {
      stdout.write("It's already done. Unmark it? (Y / N): ");
      final confirm = stdin.readLineSync()?.trim().toLowerCase();
      if (confirm == 'y' || confirm == 'yes') {
        await _toggleHabitDone(tracker, index);
      } else {
        stdout.writeln("$yellow↪️ Keeping it as done.$reset");
      }
    } else {
      await _toggleHabitDone(tracker, index);
    }
  } else {
    stdout.writeln("$yellow⚠️  Invalid habit number.$reset");
  }
}

Future<void> _reminderFlow(HabitTracker tracker) async {
  if (tracker.allHabits.isEmpty) {
    stdout.writeln('$yellow⚠️  No habits to manage.$reset');
    return;
  }
  stdout.write('Enter habit number to manage its reminder: ');
  final index = int.tryParse(stdin.readLineSync() ?? '');

  if (index == null || index < 0 || index >= tracker.allHabits.length) {
    stdout.writeln("$yellow⚠️  Invalid habit index.$reset");
    return;
  }

  final habit = tracker.allHabits[index];
  stdout.writeln("Selected: ${habit.name}");

  final current = habit.reminderTime;
  stdout.writeln("\n${bold}Managing reminder for: $cyan${habit.name}$reset");
  if (current != null) {
    stdout.writeln(
      "⏰ Current reminder set at ${current.hour}:${current.minute.toString().padLeft(2, '0')}",
    );
  } else {
    stdout.writeln("⏰ No reminder currently set.");
  }

  stdout.writeln("\nWhat do you want to do?");
  stdout.writeln("1. Set/Update reminder time");
  stdout.writeln("2. Remove reminder");
  stdout.writeln("3. Cancel");

  final choice = stdin.readLineSync();
  switch (choice) {
    case '1':
      stdout.write("Enter hour (0-23): ");
      final hour = int.tryParse(stdin.readLineSync() ?? '');
      stdout.write("Enter minute (0-59): ");
      final minute = int.tryParse(stdin.readLineSync() ?? '');

      if (hour != null && minute != null) {
        tracker.setReminderTime(index, hour, minute);
        stdout.writeln("$green✅ Reminder updated.$reset");
        await tracker.saveToFile();
      } else {
        stdout.writeln("$yellow⚠️  Invalid time.$reset");
      }
      break;

    case '2':
      tracker.removeReminderTime(index);
      stdout.writeln("🔕 Reminder removed.");
      await tracker.saveToFile();
      break;

    case '3':
      stdout.writeln("↪️ Cancelled.");
      break;

    default:
      stdout.writeln("$yellow⚠️  Invalid option.$reset");
  }
}

Future<void> _editDeleteFlow(HabitTracker tracker) async {
  if (tracker.allHabits.isEmpty) {
    stdout.writeln("$yellow⚠️  No habits to edit/delete.$reset");
    return;
  }

  stdout.write("Enter habit index to edit/delete: ");
  final index = int.tryParse(stdin.readLineSync() ?? '');
  if (index == null || index < 0 || index >= tracker.allHabits.length) {
    stdout.writeln("$yellow⚠️ Invalid index.$reset");
    return;
  }

  final habit = tracker.allHabits[index];
  stdout.writeln("Selected: ${habit.name}");

  stdout.writeln("\nWhat do you want to do?");
  stdout.writeln("1. Edit habit");
  stdout.writeln("2. Remove habit");
  stdout.writeln("3. Cancel");

  final choice = stdin.readLineSync();
  switch (choice) {
    case '1':
      stdout.write("New name (leave empty to keep current): ");
      final name = stdin.readLineSync();
      stdout.write("New difficulty (easy/medium/hard): ");
      final diffInput = stdin.readLineSync() ?? habit.difficulty.name;
      final difficulty = _parseDifficulty(diffInput);

      final newHabit = Habit(
        name == null || name.isEmpty ? habit.name : name,
        difficulty,
      );

      tracker.editHabit(index, newHabit);
      await tracker.saveToFile();
      stdout.writeln("✏️ Habit updated.");
      break;

    case '2':
      stdout.write(
        "$yellow⚠️ Are you sure you want to remove this habit? (Y/N): $reset",
      );
      final confirm = stdin.readLineSync()?.trim().toLowerCase();
      if (confirm == 'y' || confirm == 'yes') {
        tracker.removeHabit(index);
        await tracker.saveToFile();
        stdout.writeln("🗑️ Habit removed.");
      } else {
        stdout.writeln("❎ Cancelled.");
      }
      break;

    case '3':
      stdout.writeln("↪️ Cancelled.");
      break;

    default:
      stdout.writeln("$yellow⚠️  Invalid option.$reset");
  }
}

Future<void> _diaryMenu(HabitTracker tracker) async {
  while (true) {
    stdout.writeln('\n$bold💎 Diary Menu$reset');
    stdout.writeln("1. View today's notes");
    stdout.writeln("2. View notes by date");
    stdout.writeln("3. Edit today's note for a habit");
    stdout.writeln("4. Back to main menu");

    stdout.write("Choose an option: ");
    final choice = stdin.readLineSync();

    switch (choice) {
      case '1':
        _printNotesForDate(tracker, DateTime.now());
        break;

      case '2':
        final date = _promptForDate();
        if (date != null) _printNotesForDate(tracker, date);
        break;

      case '3':
        if (tracker.allHabits.isEmpty) {
          stdout.writeln("$yellow⚠️ No habits found.$reset");
          break;
        }
        stdout.write("Enter habit number to edit note: ");
        final index = int.tryParse(stdin.readLineSync() ?? '');
        if (index == null || index < 0 || index >= tracker.allHabits.length) {
          stdout.writeln("$yellow⚠️ Invalid index.$reset");
          break;
        }

        final habit = tracker.allHabits[index];
        if (!habit.isDoneToday) {
          stdout.writeln(
            "$red❌ You can only add/edit notes for habits you've completed today.$reset",
          );
          break;
        }
        stdout.write("Enter your new note for ${habit.name}: ");
        final newNote = stdin.readLineSync()?.trim() ?? '';
        tracker.addNoteForHabitToday(habit.name, newNote);

        try {
          await tracker.saveToFile();
          // provide feedback after saving
          stdout.writeln("$green✅ Note updated.$reset");
        } catch (e) {
          print("Error on save to file: $e");
        }

        break;

      case '4':
        return;

      default:
        stdout.writeln("$yellow⚠️ Invalid choice.$reset");
    }
  }
}

DateTime? _promptForDate() {
  stdout.write("Enter date (YYYY-MM-DD): ");
  final input = stdin.readLineSync();
  try {
    return DateTime.parse(input ?? '');
  } catch (_) {
    stdout.writeln("$yellow⚠️ Invalid date format.$reset");
    return null;
  }
}

void _printNotesForDate(HabitTracker tracker, DateTime date) {
  final notes = tracker.getNotesForDate(date);
  if (notes.isEmpty) {
    stdout.writeln(
      "$grey📭 No notes found for ${date.toIso8601String().split('T').first}.$reset",
    );
    return;
  }

  stdout.writeln(
    "$bold📅 Notes for ${date.toIso8601String().split('T').first}:$reset\n",
  );
  for (final entry in notes.entries) {
    stdout.writeln("$cyan• ${entry.key}:$reset ${entry.value}");
  }
}

void _printXpSummary(HabitTracker tracker) {
  stdout.writeln('$bold🌟 Today XP Earned: $cyan${tracker.todayXp}$reset');
  stdout.writeln('$bold🌟 Total XP Earned: $cyan${tracker.lifetimeXp}$reset');
}

Future<void> _exportWeeklySummaryResult(HabitTracker tracker) async {
  try {
    await tracker.exportWeeklySummaryToFile();
    stdout.writeln("📤 Weekly summary exported successfully.");
  } catch (e) {
    stderr.writeln(
      "There was an error trying to export the weekly summary: $e",
    );
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
